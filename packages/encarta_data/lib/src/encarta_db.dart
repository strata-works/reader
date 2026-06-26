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
  /// Query escaping: the query is passed as a bound parameter so it is safe
  /// from injection. Empty / whitespace-only queries return `[]` immediately
  /// without hitting SQLite.
  Future<List<SearchHit>> search(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final rows = await _db.customSelect(
      'SELECT f.rowid AS refid, a.title AS title, '
      'CAST(bm25(article_fts) AS REAL) AS rank '
      'FROM article_fts f '
      'JOIN article a ON a.refid = f.rowid '
      'WHERE article_fts MATCH ? '
      'ORDER BY rank '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable<String>(trimmed),
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
