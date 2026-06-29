import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('featured returns navigable article TitleRefs (via fallback)', () async {
    final feats = await db.featured(limit: 5);
    expect(feats, isNotEmpty);
    expect(feats.length, lessThanOrEqualTo(5));
    for (final f in feats) {
      expect(f.title, isNotEmpty);
      // Every featured ref MUST resolve to a real article (no orphan tiles).
      expect(await db.getArticle(f.refid), isNotNull);
    }
  });
}
