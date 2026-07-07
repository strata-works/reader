import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

const _char = Character(
  id: 'jester', spriteSetId: 'jester',
  greeting: 'hi', approve: ['nice'], rebuff: ['no'],
);

MazeGraph _twoRoomMaze() => MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'b',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.right, targetRoomId: 'b')]),
        'b': const Room(id: 'b', area: 1, backdropId: 'bookshlf', character: _char, doors: []),
      },
    );

void main() {
  test('room() returns the room, throws for an unknown id', () {
    final m = _twoRoomMaze();
    expect(m.room('a').area, 0);
    expect(() => m.room('nope'), throwsArgumentError);
  });

  test('doorTarget resolves a door and returns null for a missing door/room', () {
    final m = _twoRoomMaze();
    expect(m.doorTarget('a', Direction.right)!.id, 'b');
    expect(m.doorTarget('a', Direction.left), isNull);   // no such door
    expect(m.doorTarget('nope', Direction.right), isNull); // no such room
  });

  test('Character.banter defaults to empty and round-trips', () {
    const a = Character(
        id: 'x', spriteSetId: 'x', greeting: 'g', approve: [], rebuff: []);
    expect(a.banter, isEmpty);
    const b = Character(
        id: 'y', spriteSetId: 'y', greeting: 'g', approve: [], rebuff: [],
        banter: ['one', 'two']);
    expect(b.banter, ['one', 'two']);
  });
}
