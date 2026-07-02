import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('outboundXrefs returns only targets that exist as articles', () async {
    // Find a refid that actually has an in-fixture xref (fixture keeps only
    // xrefs whose target is also present), else assert the empty-safe path.
    final src = await db.anyXrefSourceRefid();
    if (src == null) {
      expect(await db.outboundXrefs(-1), isEmpty);
      return;
    }
    final targets = await db.outboundXrefs(src);
    expect(targets, isNotEmpty);
    for (final t in targets) {
      expect(t.title, isNotEmpty); // came from a JOIN to article -> resolvable
      expect(await db.getArticle(t.targetRefid), isNotNull);
    }
  });
}
