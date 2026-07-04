import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('mindmazeCastle() returns the full decoded castle', () async {
    final castle = await db.mindmazeCastle();
    expect(castle.rooms, hasLength(11));
    expect(castle.doors, hasLength(20));
    expect(castle.characters, hasLength(11));
  });

  test('exactly one goal room, and atrium is present as the start', () async {
    final castle = await db.mindmazeCastle();
    expect(castle.rooms.where((r) => r.isGoal), hasLength(1));
    expect(castle.rooms.singleWhere((r) => r.isGoal).id, 'throne');
    expect(castle.rooms.map((r) => r.id), contains('atrium'));
  });

  test('a room carries its backdrop + resident character', () async {
    final castle = await db.mindmazeCastle();
    final atrium = castle.rooms.singleWhere((r) => r.id == 'atrium');
    expect(atrium.backdropId, isNotEmpty);
    expect(atrium.characterId, 'jester');
    expect(atrium.area, 0);
  });

  test('doors reference real rooms and a valid direction', () async {
    final castle = await db.mindmazeCastle();
    final ids = castle.rooms.map((r) => r.id).toSet();
    const dirs = {'left', 'right', 'tower', 'north', 'south'};
    for (final d in castle.doors) {
      expect(ids, contains(d.roomId));
      expect(ids, contains(d.targetRoomId));
      expect(dirs, contains(d.direction));
    }
  });

  test('character banter_json parses to a non-empty line list', () async {
    final castle = await db.mindmazeCastle();
    final jester = castle.characters.singleWhere((c) => c.id == 'jester');
    expect(jester.spriteSet, 'jester');
    expect(jester.greeting, isNotEmpty);
    expect(jester.banter, isNotEmpty);
    expect(jester.banter.first, isA<String>());
  });
}
