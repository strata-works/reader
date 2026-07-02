import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('assetByBaggageId returns the row for a known baggage_id', () async {
    final known = await db.anyBaggageId(); // a real asset row in the fixture
    expect(known, isNotNull);
    final row = await db.assetByBaggageId(known!);
    expect(row, isNotNull);
    expect(row!.baggageId, known);
    expect(row.path, isNotEmpty); // relative to <dataDir>/assets/
    expect(row.ext, startsWith('.'));
    expect(row.kind, isNotEmpty);
  });

  test('assetByBaggageId returns null for an unknown baggage_id', () async {
    expect(await db.assetByBaggageId('no-such-baggage-id'), isNull);
  });
}
