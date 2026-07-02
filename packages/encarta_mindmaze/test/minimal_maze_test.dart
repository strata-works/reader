import 'dart:math';

import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

// Synthetic pools big enough for a playthrough that never repeats a question.
Question _q(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _pools() => {
      0: [for (var i = 0; i < 10; i++) _q(i, 0)],
      1: [for (var i = 10; i < 20; i++) _q(i, 1)],
    };

Set<String> _reachable(MazeGraph m) {
  final seen = <String>{};
  final stack = [m.startRoomId];
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!seen.add(id)) continue;
    for (final d in m.room(id).doors) {
      stack.add(d.targetRoomId);
    }
  }
  return seen;
}

int _correct(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect);

void main() {
  test('graph invariants: start/goal exist, doors resolve, no orphan rooms', () {
    final m = minimalMaze();
    expect(m.rooms.containsKey(m.startRoomId), isTrue);
    expect(m.rooms.containsKey(m.goalRoomId), isTrue);
    for (final room in m.rooms.values) {
      for (final door in room.doors) {
        expect(m.rooms.containsKey(door.targetRoomId), isTrue,
            reason: '${room.id} -> ${door.targetRoomId} must resolve');
      }
      expect(room.area == 0 || room.area == 1, isTrue);
    }
    expect(_reachable(m), equals(m.rooms.keys.toSet())); // every room reachable
  });

  test('a full correct playthrough reaches and clears the goal → won', () {
    final s = GameSession(
      maze: minimalMaze(), pools: _pools(),
      config: const GameConfig(), random: Random(3),
    );
    // Greedy: answer correctly, then step toward the goal via the first door
    // whose target is not yet cleared; bounded to avoid an infinite loop.
    for (var step = 0; step < 50 && s.snapshot.status == GameStatus.playing; step++) {
      if (s.snapshot.currentQuestion != null) {
        s.answer(_correct(s));
      } else {
        final room = minimalMaze().room(s.snapshot.currentRoomId);
        final next = room.doors.firstWhere(
          (d) => !s.snapshot.clearedRooms.contains(d.targetRoomId),
          orElse: () => room.doors.first,
        );
        s.move(next.direction);
      }
    }
    expect(s.snapshot.status, GameStatus.won);
  });

  test('always answering wrong ends in a loss', () {
    final s = GameSession(
      maze: minimalMaze(), pools: _pools(),
      config: const GameConfig(), random: Random(5),
    );
    for (var step = 0; step < 50 && s.snapshot.status == GameStatus.playing; step++) {
      final wrong = s.snapshot.currentQuestion!.choices.indexWhere((c) => !c.isCorrect);
      s.answer(wrong);
    }
    expect(s.snapshot.status, GameStatus.lost);
  });
}
