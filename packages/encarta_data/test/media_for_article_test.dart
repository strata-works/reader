import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('mediaForArticle returns resolved assets for a media-rich article', () async {
    // The fixture deliberately includes the 3 most media-rich articles.
    final refid = await db.mostMediaRefid();
    final media = await db.mediaForArticle(refid);
    expect(media, isNotEmpty);
    final first = media.first;
    expect(first.assetPath, isNotEmpty); // relative to <dataDir>/assets/
    expect(first.ext, startsWith('.'));
    expect(first.role, isNotEmpty);
  });

  test('mediaForArticle returns empty for an article with no media', () async {
    expect(await db.mediaForArticle(-1), isEmpty);
  });
}
