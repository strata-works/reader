import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:encarta_reader/src/screens/mindmaze/castle_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

data.MindMazeCastle _castle() => const data.MindMazeCastle(
      rooms: [
        data.MindMazeRoom(id: 'atrium', area: 0, backdropId: 'atrium', characterId: 'jester', isGoal: false),
        data.MindMazeRoom(id: 'throne', area: 6, backdropId: 'atrium', characterId: 'king', isGoal: true),
      ],
      doors: [
        data.MindMazeDoor(roomId: 'atrium', direction: 'right', targetRoomId: 'throne'),
        data.MindMazeDoor(roomId: 'throne', direction: 'south', targetRoomId: 'atrium'),
      ],
      characters: [
        data.MindMazeCharacter(id: 'jester', spriteSet: 'jester', greeting: 'Welcome!', banter: ['a', 'b']),
        data.MindMazeCharacter(id: 'king', spriteSet: 'king', greeting: 'Prove it.', banter: ['c']),
      ],
    );

void main() {
  test('castleToMaze wires rooms, doors, start and goal', () {
    final maze = castleToMaze(_castle());
    expect(maze.startRoomId, 'atrium');
    expect(maze.goalRoomId, 'throne');
    expect(maze.rooms.keys.toSet(), {'atrium', 'throne'});
    expect(maze.room('atrium').backdropId, 'atrium');
    expect(maze.doorTarget('atrium', mm.Direction.right)?.id, 'throne');
  });

  test('character greeting maps through; approve/rebuff are populated', () {
    final maze = castleToMaze(_castle());
    final c = maze.room('atrium').character;
    expect(c.id, 'jester');
    expect(c.spriteSetId, 'jester');
    expect(c.greeting, 'Welcome!');
    expect(c.approve, isNotEmpty);
    expect(c.rebuff, isNotEmpty);
  });

  test('mazeAreas is the sorted distinct room areas', () {
    expect(mazeAreas(castleToMaze(_castle())), [0, 6]);
  });

  test('throws when there is no goal room', () {
    final noGoal = data.MindMazeCastle(
      rooms: const [
        data.MindMazeRoom(id: 'atrium', area: 0, backdropId: 'atrium', characterId: 'jester', isGoal: false),
      ],
      doors: const [],
      characters: const [
        data.MindMazeCharacter(id: 'jester', spriteSet: 'jester', greeting: 'hi', banter: []),
      ],
    );
    expect(() => castleToMaze(noGoal), throwsArgumentError);
  });

  test('throws when there is no atrium start room', () {
    final noAtrium = data.MindMazeCastle(
      rooms: const [
        data.MindMazeRoom(id: 'throne', area: 6, backdropId: 'atrium', characterId: 'king', isGoal: true),
      ],
      doors: const [],
      characters: const [
        data.MindMazeCharacter(id: 'king', spriteSet: 'king', greeting: 'hi', banter: []),
      ],
    );
    expect(() => castleToMaze(noAtrium), throwsArgumentError);
  });

  test('castleToMaze carries character banter through', () {
    final castle = data.MindMazeCastle(
      characters: [
        const data.MindMazeCharacter(
            id: 'jester', spriteSet: 'jester', greeting: 'hi', banter: ['b1', 'b2']),
      ],
      rooms: [
        const data.MindMazeRoom(
            id: 'atrium', area: 0, backdropId: 'atrium',
            characterId: 'jester', isGoal: false),
        const data.MindMazeRoom(
            id: 'throne', area: 0, backdropId: 'atrium',
            characterId: 'jester', isGoal: true),
      ],
      doors: const [
        data.MindMazeDoor(roomId: 'atrium', direction: 'right', targetRoomId: 'throne'),
      ],
    );
    final maze = castleToMaze(castle);
    expect(maze.room('atrium').character.banter, ['b1', 'b2']);
  });
}
