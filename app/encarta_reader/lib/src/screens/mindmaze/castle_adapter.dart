import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

// The decoded castle has authentic greetings but no per-answer reaction lines
// (the original used generic right/wrong cues), so approve/rebuff are authored
// generic feedback, shared by every character. Banter variety is Phase 6.
const _genericApprove = <String>[
  'Correct — the way opens.',
  'Well answered. Proceed.',
];
const _genericRebuff = <String>[
  'No — think again, seeker.',
  'Not so. The door stays shut.',
];

// The decode has no is_start flag; the Phase 5a authored spine always enters at
// the atrium. Kept as a named convention (candidate for an is_start flag in a
// future quarry pass).
const _startRoomId = 'atrium';

/// Adapts the data-layer [castle] into the engine's [mm.MazeGraph].
///
/// Connectivity is the Phase 5a authored spine; room/character content and
/// greetings are authentic. Throws [ArgumentError] if the castle lacks a goal
/// room or the `atrium` start room, so the page can degrade gracefully rather
/// than build a broken maze.
mm.MazeGraph castleToMaze(data.MindMazeCastle castle) {
  final characters = {for (final c in castle.characters) c.id: c};

  final goals = castle.rooms.where((r) => r.isGoal);
  if (goals.length != 1) {
    throw ArgumentError('castle must have exactly one goal room, found ${goals.length}');
  }
  if (!castle.rooms.any((r) => r.id == _startRoomId)) {
    throw ArgumentError('castle has no "$_startRoomId" start room');
  }

  final doorsByRoom = <String, List<mm.Door>>{};
  for (final d in castle.doors) {
    (doorsByRoom[d.roomId] ??= []).add(
      mm.Door(direction: mm.Direction.values.byName(d.direction), targetRoomId: d.targetRoomId),
    );
  }

  final rooms = <String, mm.Room>{};
  for (final r in castle.rooms) {
    final c = characters[r.characterId];
    rooms[r.id] = mm.Room(
      id: r.id,
      area: r.area ?? 0,
      backdropId: r.backdropId,
      character: mm.Character(
        id: r.characterId,
        spriteSetId: c?.spriteSet ?? r.characterId,
        greeting: c?.greeting ?? '',
        approve: _genericApprove,
        rebuff: _genericRebuff,
      ),
      doors: doorsByRoom[r.id] ?? const [],
    );
  }

  return mm.MazeGraph(
    rooms: rooms,
    startRoomId: _startRoomId,
    goalRoomId: goals.single.id,
  );
}

/// The sorted, distinct room areas the [maze] uses — the exact set of question
/// pools that must be loaded to construct a [mm.GameSession] over it.
List<int> mazeAreas(mm.MazeGraph maze) {
  final areas = {for (final r in maze.rooms.values) r.area}.toList()..sort();
  return areas;
}
