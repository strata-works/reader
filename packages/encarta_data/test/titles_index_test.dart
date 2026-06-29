import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('titlesIndex returns titled refs sorted by title', () async {
    final all = await db.titlesIndex(limit: 100);
    expect(all, isNotEmpty);
    for (var i = 1; i < all.length; i++) {
      expect(all[i].title.compareTo(all[i - 1].title), greaterThanOrEqualTo(0));
    }
  });

  test('titlesIndex filters case-insensitively by prefix', () async {
    final all = await db.titlesIndex(limit: 200);
    final letter = all.first.title[0].toUpperCase();
    final filtered = await db.titlesIndex(prefix: letter, limit: 200);
    expect(filtered, isNotEmpty);
    for (final t in filtered) {
      expect(t.title.toUpperCase(), startsWith(letter));
    }
  });

  test('titlesIndex paginates with limit/offset', () async {
    final page1 = await db.titlesIndex(limit: 3, offset: 0);
    final page2 = await db.titlesIndex(limit: 3, offset: 3);
    final overlap = page1.map((t) => t.refid).toSet()
      ..retainAll(page2.map((t) => t.refid).toSet());
    expect(overlap, isEmpty);
  });
}
