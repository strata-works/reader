import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('randomArticle returns a titled, loadable article', () async {
    final a = await db.randomArticle();
    expect(a, isNotNull);
    expect(a!.title, isNotEmpty);
    expect(a.xmlBytes, isNotEmpty);
    expect(await db.getArticle(a.refid), isNotNull);
  });

  test('randomArticle eventually varies (sampled 25x)', () async {
    final seen = <int>{};
    for (var i = 0; i < 25; i++) {
      seen.add((await db.randomArticle())!.refid);
    }
    expect(seen.length, greaterThan(1)); // not pinned to one row
  });
}
