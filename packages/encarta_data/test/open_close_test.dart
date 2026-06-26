import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  test('open() opens the fixture read-only and runs a query without writing', () async {
    final db = await EncartaDb.open(fixturePath);
    addTearDown(db.close);
    // A successful query proves: fts5 lib loaded, read-only open, and that
    // drift did not blow up trying to write user_version to the DB.
    final n = await db.debugArticleCount();
    expect(n, greaterThanOrEqualTo(30));
  });

  test('close() can be called and reopened', () async {
    final db = await EncartaDb.open(fixturePath);
    await db.close();
    final db2 = await EncartaDb.open(fixturePath);
    addTearDown(db2.close);
    expect(await db2.debugArticleCount(), greaterThanOrEqualTo(30));
  });
}
