import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

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

  /// Verifies the contentless-FTS invariant: `article_fts.rowid == article.refid`.
  ///
  /// Returns true when no fts rowid is orphaned. If this ever returns false,
  /// the corpus ETL did not align rowids with refids; the fallback is to stop
  /// trusting the rowid and instead resolve each hit through a refid-mapping
  /// table emitted by the ETL (quarry), or to rebuild the FTS index with an
  /// explicit `INSERT INTO article_fts(rowid, body)` keyed by refid (as the
  /// fixture builder already does). Until then `search()` must not be trusted.
  Future<bool> verifyFtsRowidMapping() async {
    final unmapped = await _db.ftsRowidUnmapped().getSingle();
    return unmapped == 0;
  }
}
