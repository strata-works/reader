import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  test('fixture exists, has articles, and fts rowid == article.refid', () {
    // The fixture must be opened with an fts5-capable sqlite3.
    for (final p in const [
      '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
      '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
    ]) {
      if (File(p).existsSync()) {
        open.overrideForAll(() => DynamicLibrary.open(p));
        break;
      }
    }
    expect(File(fixturePath).existsSync(), isTrue,
        reason: 'run: dart run tool/build_fixture.dart');
    final db = sqlite3.open(fixturePath, mode: OpenMode.readOnly);
    addTearDown(db.dispose);

    final articleN = db.select('SELECT count(*) AS n FROM article').first['n'] as int;
    expect(articleN, greaterThanOrEqualTo(30));

    // Every fts rowid maps to a real article.refid (the invariant under test).
    final unmapped = db.select(
      'SELECT count(*) AS n FROM article_fts f '
      'WHERE NOT EXISTS (SELECT 1 FROM article a WHERE a.refid = f.rowid)',
    ).first['n'] as int;
    expect(unmapped, 0);

    // home-group media is present so featured()'s probe has something to read.
    final home = db.select(
      "SELECT count(*) AS n FROM media WHERE \"group\" = 'home'",
    ).first['n'] as int;
    expect(home, greaterThan(0));
  });
}
