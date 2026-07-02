/// Door directions (mirrors the recovered MindMaze door art: doorlt/doorrt/
/// doortow/ndoor/sdoor).
enum Direction { left, right, tower, north, south }

/// A one-way navigation edge from a room to [targetRoomId] via [direction].
class Door {
  const Door({required this.direction, required this.targetRoomId});
  final Direction direction;
  final String targetRoomId;
}

/// A castle character posing questions in a room. [spriteSetId] names the art
/// set (e.g. 'jester' → jester1..4). Banter lines are authored (reconstructed).
class Character {
  const Character({
    required this.id,
    required this.spriteSetId,
    required this.greeting,
    required this.approve,
    required this.rebuff,
  });
  final String id;
  final String spriteSetId;
  final String greeting;
  final List<String> approve;
  final List<String> rebuff;
}

/// A maze room: its question-pool [area], backdrop art, resident [character],
/// and outgoing [doors].
class Room {
  const Room({
    required this.id,
    required this.area,
    required this.backdropId,
    required this.character,
    required this.doors,
  });
  final String id;
  final int area;
  final String backdropId;
  final Character character;
  final List<Door> doors;
}

/// The castle graph: [rooms] keyed by id, with a [startRoomId] and [goalRoomId].
class MazeGraph {
  const MazeGraph({
    required this.rooms,
    required this.startRoomId,
    required this.goalRoomId,
  });
  final Map<String, Room> rooms;
  final String startRoomId;
  final String goalRoomId;

  /// The room for [id]; throws [ArgumentError] if it is not in the graph.
  Room room(String id) {
    final r = rooms[id];
    if (r == null) throw ArgumentError('no such room: $id');
    return r;
  }

  /// The room reached from [roomId] via a door in [d], or null if there is no
  /// such room or no such door.
  Room? doorTarget(String roomId, Direction d) {
    final r = rooms[roomId];
    if (r == null) return null;
    for (final door in r.doors) {
      if (door.direction == d) return rooms[door.targetRoomId];
    }
    return null;
  }
}
