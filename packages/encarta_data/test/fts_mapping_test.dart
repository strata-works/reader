import 'dart:io';

import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';
const realDbPath =
    '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';

void main() {
  test('fixture: every fts rowid maps to an article.refid', () async {
    final db = await EncartaDb.open(fixturePath);
    addTearDown(db.close);
    expect(await db.verifyFtsRowidMapping(), isTrue);
  });

  test('REAL DB: fts rowid == article.refid (skipped if corpus absent)', () async {
    if (!File(realDbPath).existsSync()) {
      markTestSkipped('real corpus not present');
      return;
    }
    final db = await EncartaDb.open(realDbPath);
    addTearDown(db.close);
    expect(await db.verifyFtsRowidMapping(), isTrue,
        reason: 'fts rowid is NOT article.refid — enable the mapping fallback');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
