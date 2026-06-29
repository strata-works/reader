import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
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
  @visibleForTesting
  Future<int> debugArticleCount() async {
    final row = await _db.customSelect('SELECT count(*) AS n FROM article').getSingle();
    return row.read<int>('n');
  }

  /// Loads one article by id, or null if absent. Missing titles map to ''.
  Future<Article?> getArticle(int refid) async {
    final row = await _db.getArticleByRefid(refid).getSingleOrNull();
    if (row == null) return null;
    return Article(
      refid: row.refid,
      title: row.title ?? '',
      source: row.source ?? '',
      xmlBytes: row.xml ?? Uint8List(0),
    );
  }

  /// A random titled article, or null if the corpus has none.
  ///
  /// Picks a random point in the refid (INTEGER PRIMARY KEY = rowid) range via
  /// SQLite's `random()`, then takes the next titled article via an index range
  /// scan — O(log n) instead of a full-table `ORDER BY random()`. Falls back to
  /// the first titled article when the random point lands past the last titled
  /// refid. Delegates to [getArticle] so xml BLOB mapping stays in one place.
  Future<Article?> randomArticle() async {
    final data = (await _db.randomArticleInRange().getSingleOrNull()) ??
        (await _db.randomArticleFallback().getSingleOrNull());
    if (data == null) return null;
    return getArticle(data.refid);
  }

  /// Test seam: the smallest titled refid in the corpus.
  Future<int> firstTitledRefid() async {
    return _db.firstTitledRefid().getSingle();
  }

  /// Full-text search, bm25-ranked (most relevant first), paginated.
  ///
  /// Returns a list of [SearchHit]s ordered by ascending bm25 rank (more
  /// negative = more relevant, so ascending puts the best match first).
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
    // customSelect: FTS5 MATCH + bm25 on the virtual article_fts table; keeping
    // the SQL here makes the _fts5Query() escaping contract explicit at the call site.
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
    final rows = await _db.mediaForArticle(refid).get();
    return [
      for (final r in rows)
        MediaItem(
          mediaRefid: r.mediaRefid,
          role: r.role,
          group: r.mgroup ?? '',
          title: r.title,
          caption: r.caption,
          credit: r.credit,
          assetPath: r.assetPath ?? '',
          ext: r.ext ?? '',
          kind: r.kind ?? '',
        ),
    ];
  }

  /// Test seam: the most media-rich article id in the corpus.
  Future<int> mostMediaRefid() async {
    return _db.mostMediaRefid().getSingle();
  }

  /// Looks up a single asset by its baggage_id (the `inlinebmp type=27` id),
  /// or null if absent. `path` is relative to `<dataDir>/assets/`.
  Future<AssetRow?> assetByBaggageId(String baggageId) async {
    final row = await _db.assetByBaggageId(baggageId).getSingleOrNull();
    if (row == null) return null;
    return AssetRow(
      baggageId: row.baggageId,
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
  Future<List<XrefTarget>> outboundXrefs(int refid) async {
    final rows = await _db.outboundXrefs(refid).get();
    return [
      for (final r in rows)
        XrefTarget(
          targetRefid: r.targetRefid,
          title: r.title ?? '',
        ),
    ];
  }

  /// Test seam: any refid with at least one resolvable outbound xref, or null.
  Future<int?> anyXrefSourceRefid() async {
    return _db.anyXrefSourceRefid().getSingleOrNull();
  }

  /// A–Z browse over article titles. `prefix` is matched case-insensitively;
  /// null/empty returns the full alphabetical list (paginated).
  /// Excludes empty-string titles and sorts case-insensitively (COLLATE NOCASE).
  Future<List<TitleRef>> titlesIndex({
    String? prefix,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _db.titlesIndex(prefix ?? '', limit, offset).get();
    return [
      for (final r in rows)
        TitleRef(refid: r.refid, title: r.title ?? ''),
    ];
  }

  /// Home-portal featured articles. Probes `media."group"='home'` first; if
  /// that yields no navigable articles (the verified current state), falls
  /// back to the most media-rich articles. Every result is a real article.
  Future<List<TitleRef>> featured({int limit = 12}) async {
    final home = await _db.featuredHomeArticles(limit).get();
    if (home.isNotEmpty) {
      return [for (final r in home) TitleRef(refid: r.refid, title: r.title ?? '')];
    }
    final fallback = await _db.featuredByMediaCount(limit).get();
    return [for (final r in fallback) TitleRef(refid: r.refid, title: r.title ?? '')];
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
      final seed = await _db.ftsSeedArticle(offset).getSingleOrNull();
      if (seed == null) break;

      final refid = seed.refid;
      final xml = utf8.decode(seed.xml ?? Uint8List(0), allowMalformed: true);

      final token = _extractFtsToken(xml);
      if (token == null) continue;

      final rowids = (await _db.ftsMatchToken(token).get()).toSet();
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
