import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('getArticle returns the row for a known refid', () async {
    final refid = await db.firstTitledRefid();
    final article = await db.getArticle(refid);
    expect(article, isNotNull);
    expect(article!.refid, refid);
    expect(article.xmlBytes, isNotEmpty);
  });

  test('getArticle returns null for an absent refid', () async {
    expect(await db.getArticle(-1), isNull);
  });
}
