import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

// `hide Article` prevents a name clash with the Article data class below:
// database.g.dart (part of database.dart) also exports an Article table class.
import 'database.dart' hide Article;
import 'models.dart';

bool _fts5LoaderInstalled = false;

/// Point the `sqlite3` package at an fts5-capable libsqlite3.
///
/// macOS system sqlite3 ships WITHOUT fts5 (`no such module: fts5`); the
/// Homebrew build does. We override the global open hook once. If no such
/// library is found we leave the default in place — non-fts queries still
/// work, and [EncartaDb.search] will surface a clear "no such module" error.
void _loadFts5Sqlite() {
  if (_fts5LoaderInstalled) return;
  for (final p in const [
    '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
    '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
  ]) {
    if (File(p).existsSync()) {
      open.overrideForAll(() => DynamicLibrary.open(p));
      break;
    }
  }
  _fts5LoaderInstalled = true;
}

/// Swallows the `PRAGMA user_version = N` write drift would otherwise issue
/// when it sees `user_version == 0` on first open. The corpus is read-only,
/// so that write must never reach the file. All reads pass through untouched.
class _ReadOnlyInterceptor extends QueryInterceptor {
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    final s = statement.trimLeft().toLowerCase();
    if (s.startsWith('pragma user_version =')) {
      return Future<void>.value();
    }
    return super.runCustom(executor, statement, args);
  }
}

/// Read-only typed access to the recovered Encarta 2009 corpus.
class EncartaDb {
  EncartaDb._(this._db);

  final EncartaDatabase _db;

  /// Opens [dbPath] READ-ONLY. Loads an fts5-capable sqlite3 first.
  ///
  /// `enableMigrations: false` makes drift use [NoVersionDelegate], so it
  /// never calls `database.userVersion = N` on the read-only file.
  /// The [_ReadOnlyInterceptor] provides an additional safety net that
  /// swallows any `PRAGMA user_version =` SQL that might still slip through.
  static Future<EncartaDb> open(String dbPath) async {
    _loadFts5Sqlite();
    final raw = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    final executor = NativeDatabase.opened(raw, enableMigrations: false)
        .interceptWith(_ReadOnlyInterceptor());
    return EncartaDb._(EncartaDatabase(executor));
  }

  Future<void> close() => _db.close();

  /// Test-only: row count, used to prove the connection is live.
  Future<int> debugArticleCount() async {
    final row = await _db.customSelect('SELECT count(*) AS n FROM article').getSingle();
    return row.read<int>('n');
  }

  /// Loads one article by id, or null if absent. Missing titles map to ''.
  ///
  /// Uses customSelect rather than the drift-generated accessor because
  /// drift's static analyser cannot resolve the corpus table schema and
  /// generates String? for all columns (see task brief note).
  Future<Article?> getArticle(int refid) async {
    final rows = await _db.customSelect(
      'SELECT refid, title, source, xml FROM article WHERE refid = ?',
      variables: [Variable<int>(refid)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    final xmlRaw = row.data['xml'];
    final xml = xmlRaw is Uint8List
        ? xmlRaw
        : (xmlRaw is List<int> ? Uint8List.fromList(xmlRaw) : Uint8List(0));
    return Article(
      refid: row.read<int>('refid'),
      title: row.read<String?>('title') ?? '',
      source: row.read<String?>('source') ?? '',
      xmlBytes: xml,
    );
  }

  /// A random titled article, or null if the corpus has none.
  ///
  /// Picks a random point in the refid (INTEGER PRIMARY KEY = rowid) range via
  /// SQLite's `random()`, then takes the next titled article via an index range
  /// scan — O(log n) instead of a full-table `ORDER BY random()`. Falls back to
  /// the first titled article when the random point lands past the last titled
  /// refid. Delegates to [getArticle] so xml BLOB mapping stays in one place.
  ///
  /// Uses customSelect (not the drift-generated randomArticleInRange accessor)
  /// because drift's codegen mis-types the INTEGER refid column as String?.
  Future<Article?> randomArticle() async {
    var row = await _db.customSelect(
      'SELECT refid FROM article'
      ' WHERE refid >= ('
      '   SELECT min(refid) + abs(random()) % (max(refid) - min(refid) + 1)'
      '   FROM article'
      ' ) AND title IS NOT NULL ORDER BY refid LIMIT 1',
    ).getSingleOrNull();
    row ??= await _db.customSelect(
      'SELECT refid FROM article WHERE title IS NOT NULL ORDER BY refid LIMIT 1',
    ).getSingleOrNull();
    if (row == null) return null;
    return getArticle(row.read<int>('refid'));
  }

  /// Test seam: the smallest titled refid in the corpus.
  Future<int> firstTitledRefid() async {
    final row = await _db.customSelect(
      'SELECT refid FROM article WHERE title IS NOT NULL ORDER BY refid LIMIT 1',
    ).getSingle();
    return row.read<int>('refid');
  }

  /// Full-text search, bm25-ranked (most relevant first), paginated.
  ///
  /// Returns a list of [SearchHit]s ordered by ascending bm25 rank (more
  /// negative = more relevant, so ascending puts the best match first).
  ///
  /// Uses [customSelect] directly because drift's static analyser cannot type
  /// queries against the virtual `article_fts` table — this is the established
  /// pattern in this package (the `.drift` stub generates wrong types).
  ///
  /// Query escaping: [_fts5Query] converts the raw user string into a safe
  /// FTS5 MATCH expression (each whitespace token quoted as a string literal).
  /// Empty / whitespace-only queries return `[]` immediately without hitting
  /// SQLite.
  Future<List<SearchHit>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final ftsQuery = _fts5Query(query);
    if (ftsQuery == null) return [];
    final rows = await _db.customSelect(
      'SELECT f.rowid AS refid, a.title AS title, '
      'CAST(bm25(article_fts) AS REAL) AS rank '
      'FROM article_fts f '
      'JOIN article a ON a.refid = f.rowid '
      'WHERE article_fts MATCH ? '
      'ORDER BY rank '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable<String>(ftsQuery),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
    ).get();
    return [
      for (final r in rows)
        SearchHit(
          refid: r.read<int>('refid'),
          title: r.read<String?>('title') ?? '',
          rank: r.read<double>('rank'),
        ),
    ];
  }

  /// All media slots for an article via article_media → media_file → asset.
  /// `assetPath` is relative to `<dataDir>/assets/`.
  Future<List<MediaItem>> mediaForArticle(int refid) async {
    final rows = await _db.customSelect(
      'SELECT '
      '  m.refid    AS mediaRefid, '
      '  mf.role    AS role, '
      '  m."group"  AS mgroup, '
      '  m.title    AS title, '
      '  m.caption  AS caption, '
      '  m.credit   AS credit, '
      '  a.path     AS assetPath, '
      '  a.ext      AS ext, '
      '  a.kind     AS kind '
      'FROM article_media am '
      'JOIN media m       ON m.refid = am.media_refid '
      'JOIN media_file mf ON mf.media_refid = am.media_refid '
      'JOIN asset a       ON a.baggage_id = mf.baggage_id '
      'WHERE am.article_refid = ? '
      'ORDER BY mf.role',
      variables: [Variable<int>(refid)],
    ).get();
    return [
      for (final r in rows)
        MediaItem(
          mediaRefid: r.read<int>('mediaRefid'),
          role: r.read<String?>('role') ?? '',
          group: r.read<String?>('mgroup') ?? '',
          title: r.read<String?>('title'),
          caption: r.read<String?>('caption'),
          credit: r.read<String?>('credit'),
          assetPath: r.read<String?>('assetPath') ?? '',
          ext: r.read<String?>('ext') ?? '',
          kind: r.read<String?>('kind') ?? '',
        ),
    ];
  }

  /// Test seam: the most media-rich article id in the corpus.
  Future<int> mostMediaRefid() async {
    final row = await _db.customSelect(
      'SELECT a.refid AS refid FROM article_media am '
      'JOIN article a ON a.refid = am.article_refid '
      'GROUP BY a.refid ORDER BY count(*) DESC LIMIT 1',
    ).getSingle();
    return row.read<int>('refid');
  }

  /// Looks up a single asset by its baggage_id (the `inlinebmp type=27` id),
  /// or null if absent. `path` is relative to `<dataDir>/assets/`.
  Future<AssetRow?> assetByBaggageId(String baggageId) async {
    final row = await _db.assetByBaggageId(baggageId).getSingleOrNull();
    if (row == null) return null;
    return AssetRow(
      baggageId: row.baggageId ?? '',
      hash: row.hash ?? '',
      kind: row.kind ?? '',
      ext: row.ext ?? '',
      path: row.path ?? '',
    );
  }

  /// Test seam: any baggage_id present in the asset table, or null.
  Future<String?> anyBaggageId() async {
    return _db.anyBaggageId().getSingleOrNull();
  }

  /// Outbound cross-references for an article. Targets absent from the corpus
  /// are dropped by the JOIN, so callers never get dead links.
  ///
  /// Uses customSelect rather than the drift-generated accessor because drift
  /// cannot resolve the corpus schema at build time: it generates `String` for
  /// both `refid` and `target_refid` (integer columns), making the accessor
  /// unusable without unsafe casts.
  Future<List<XrefTarget>> outboundXrefs(int refid) async {
    final rows = await _db.customSelect(
      'SELECT x.target_refid AS targetRefid, a.title AS title '
      'FROM xref x '
      'JOIN article a ON a.refid = x.target_refid '
      'WHERE x.refid = ? AND a.title IS NOT NULL '
      'ORDER BY a.title',
      variables: [Variable<int>(refid)],
    ).get();
    return [
      for (final r in rows)
        XrefTarget(
          targetRefid: r.read<int>('targetRefid'),
          title: r.read<String?>('title') ?? '',
        ),
    ];
  }

  /// Test seam: any refid with at least one resolvable outbound xref, or null.
  ///
  /// Uses customSelect for the same reason as [outboundXrefs]: the generated
  /// accessor returns String? for an integer column.
  Future<int?> anyXrefSourceRefid() async {
    final row = await _db.customSelect(
      'SELECT x.refid AS refid FROM xref x '
      'JOIN article a ON a.refid = x.target_refid '
      'LIMIT 1',
    ).getSingleOrNull();
    return row?.read<int>('refid');
  }

  /// A–Z browse over article titles. `prefix` is matched case-insensitively;
  /// null/empty returns the full alphabetical list (paginated).
  ///
  /// Uses customSelect rather than the drift-generated accessor because drift
  /// cannot resolve the corpus schema at build time: it generates `String?` for
  /// `refid` (an integer column), making `TitlesIndexResult.refid` unusable
  /// without an unsafe parse — the same limitation documented on [outboundXrefs].
  Future<List<TitleRef>> titlesIndex({
    String? prefix,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _db.customSelect(
      'SELECT refid, title FROM article '
      'WHERE title IS NOT NULL AND title LIKE ? || \'%\' '
      'ORDER BY title '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable<String>(prefix ?? ''),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
    ).get();
    return [
      for (final r in rows)
        TitleRef(refid: r.read<int>('refid'), title: r.read<String?>('title') ?? ''),
    ];
  }

  /// Home-portal featured articles. Probes `media."group"='home'` first; if
  /// that yields no navigable articles (the verified current state), falls
  /// back to the most media-rich articles. Every result is a real article.
  Future<List<TitleRef>> featured({int limit = 12}) async {
    final home = await _db.customSelect(
      'SELECT a.refid AS refid, a.title AS title '
      'FROM media m '
      'JOIN article_media am ON am.media_refid = m.refid '
      'JOIN article a ON a.refid = am.article_refid '
      'WHERE m."group" = \'home\' AND a.title IS NOT NULL '
      'GROUP BY a.refid '
      'ORDER BY m.refid '
      'LIMIT ?',
      variables: [Variable<int>(limit)],
    ).get();
    final rows = home.isNotEmpty
        ? home
        : await _db.customSelect(
            'SELECT a.refid AS refid, a.title AS title '
            'FROM article_media am '
            'JOIN article a ON a.refid = am.article_refid '
            'WHERE a.title IS NOT NULL '
            'GROUP BY a.refid '
            'ORDER BY count(*) DESC '
            'LIMIT ?',
            variables: [Variable<int>(limit)],
          ).get();
    return [
      for (final r in rows) TitleRef(refid: r.read<int>('refid'), title: r.read<String?>('title') ?? ''),
    ];
  }

  /// Verifies the contentless-FTS invariant: `article_fts.rowid == article.refid`.
  ///
  /// Returns true only when BOTH checks pass:
  ///
  /// (a) Orphan check — no FTS row has a rowid that is absent from
  ///     `article.refid`. A non-zero count means the ETL drifted.
  ///
  /// (b) Positive round-trip — picks a known article deterministically
  ///     (first article with `length(xml) > 200`, ordered by refid), extracts
  ///     a distinctive token from its body text (xml with tags stripped),
  ///     runs an FTS5 MATCH for that token, and asserts the article's refid
  ///     appears among the returned rowids. This proves that a real search
  ///     round-trips to the correct article.
  ///
  /// Falls back to the next few articles if the chosen one yields no usable
  /// token. Deterministic — no randomness.
  Future<bool> verifyFtsRowidMapping() async {
    // Part (a): orphan check.
    final unmapped = await _db.ftsRowidUnmapped().getSingle();
    if (unmapped != 0) return false;

    // Part (b): positive round-trip check.
    const maxTries = 5;
    for (var offset = 0; offset < maxTries; offset++) {
      final rows = await _db.customSelect(
        'SELECT refid, xml FROM article '
        'WHERE length(xml) > 200 ORDER BY refid LIMIT 1 OFFSET ?',
        variables: [Variable<int>(offset)],
      ).get();
      if (rows.isEmpty) break;

      final refid = rows.first.read<int>('refid');
      // xml is stored as BLOB; handle both Uint8List and String returns.
      final xmlRaw = rows.first.data['xml'];
      final xml = xmlRaw is List<int>
          ? utf8.decode(xmlRaw, allowMalformed: true)
          : '${xmlRaw ?? ''}';

      final token = _extractFtsToken(xml);
      if (token == null) continue;

      final ftsRows = await _db.customSelect(
        'SELECT rowid FROM article_fts WHERE article_fts MATCH ?',
        variables: [Variable<String>(token)],
      ).get();

      final rowids = ftsRows.map((r) => r.read<int>('rowid')).toSet();
      if (rowids.contains(refid)) return true;
    }

    return false;
  }
}

/// Converts a free-text user query into a safe FTS5 MATCH expression.
///
/// Each whitespace-delimited token is wrapped in double quotes (with any
/// internal `"` doubled to `""`), making it an fts5 string literal. This
/// prevents fts5 from interpreting operator characters that appear in ordinary
/// user input (e.g. `-`, `*`, `^`, `:`, `(`, `)`, `"`).
///
/// Returns `null` when the query contains no non-empty tokens (empty or
/// whitespace-only input), in which case the caller should return `[]` without
/// running a MATCH.
///
/// Examples:
/// - `'rock-forming'` → `'"rock-forming"'`
/// - `'say "hi"'`     → `'"say" "hi"'`
/// - `'co2 flux'`     → `'"co2" "flux"'`
/// - `''`             → `null`
String? _fts5Query(String query) {
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => '"${t.replaceAll('"', '""')}"')
      .toList();
  if (tokens.isEmpty) return null;
  return tokens.join(' ');
}

/// Strips XML tags from [xml] (mirroring the ETL that built the FTS index)
/// and returns the first lowercase alphabetic word of length >= 5 from the
/// sorted word list, or null if no such word exists.
///
/// Sorting makes the selection deterministic across platforms and Dart versions.
String? _extractFtsToken(String xml) {
  final text = xml.replaceAll(RegExp(r'<[^>]*>'), ' ');
  final words = RegExp(r'[a-zA-Z]{5,}')
      .allMatches(text)
      .map((m) => m.group(0)!.toLowerCase())
      .toSet()
      .toList()
    ..sort();
  return words.isEmpty ? null : words.first;
}
