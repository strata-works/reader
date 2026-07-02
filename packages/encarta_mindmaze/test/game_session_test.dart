import 'dart:math';

import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

const _char = Character(
  id: 'c', spriteSetId: 'c',
  greeting: 'greet', approve: ['approve'], rebuff: ['rebuff'],
);

// start 'a' (area 0) --right--> goal 'b' (area 1)
MazeGraph _maze() => MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'b',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.right, targetRoomId: 'b')]),
        'b': const Room(id: 'b', area: 1, backdropId: 'bookshlf', character: _char,
            doors: [Door(direction: Direction.left, targetRoomId: 'a')]),
      },
    );

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
      0: [_q(1, 0), _q(2, 0), _q(3, 0)],
      1: [_q(11, 1), _q(12, 1), _q(13, 1)],
    };

GameSession _session({GameConfig config = const GameConfig()}) =>
    GameSession(maze: _maze(), pools: _pools(), config: config, random: Random(1));

int _correctIndex(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect);
int _wrongIndex(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => !c.isCorrect);

void main() {
  test('starts in the start room with a question and a greeting', () {
    final s = _session();
    expect(s.snapshot.currentRoomId, 'a');
    expect(s.snapshot.currentQuestion, isNotNull);
    expect(s.snapshot.lives, 3);
    expect(s.snapshot.status, GameStatus.playing);
    expect(s.snapshot.lastCharacterLine, 'greet');
  });

  test('correct answer clears the room, adds score, and posts an approve line', () {
    final s = _session();
    s.answer(_correctIndex(s));
    expect(s.snapshot.currentRoomCleared, isTrue);
    expect(s.snapshot.score, 100);
    expect(s.snapshot.currentQuestion, isNull);
    expect(s.snapshot.lastCharacterLine, 'approve');
    expect(s.snapshot.status, GameStatus.playing); // 'a' is not the goal
  });

  test('wrong answer costs a life, posts a rebuff, and re-poses a fresh question', () {
    final s = _session();
    final firstId = s.snapshot.currentQuestion!.id;
    s.answer(_wrongIndex(s));
    expect(s.snapshot.lives, 2);
    expect(s.snapshot.lastCharacterLine, 'rebuff');
    expect(s.snapshot.currentQuestion, isNotNull);
    expect(s.snapshot.currentQuestion!.id, isNot(firstId)); // retry = different question
    expect(s.snapshot.currentRoomCleared, isFalse);
  });

  test('running out of lives ends the game as lost', () {
    final s = _session(config: const GameConfig(startingLives: 1));
    s.answer(_wrongIndex(s));
    expect(s.snapshot.lives, 0);
    expect(s.snapshot.status, GameStatus.lost);
    // further input is a no-op
    s.answer(0);
    s.move(Direction.right);
    expect(s.snapshot.status, GameStatus.lost);
  });

  test('move is blocked until the room is cleared', () {
    final s = _session();
    s.move(Direction.right); // room 'a' not cleared yet
    expect(s.snapshot.currentRoomId, 'a');
    s.answer(_correctIndex(s));
    s.move(Direction.right); // now allowed
    expect(s.snapshot.currentRoomId, 'b');
    expect(s.snapshot.currentQuestion, isNotNull); // goal room poses its question
  });

  test('clearing the goal room wins the game', () {
    final s = _session();
    s.answer(_correctIndex(s)); // clear 'a'
    s.move(Direction.right);    // enter goal 'b'
    expect(s.snapshot.status, GameStatus.playing); // walking in does not win
    s.answer(_correctIndex(s)); // answer the goal's question
    expect(s.snapshot.status, GameStatus.won);
    expect(s.snapshot.score, 200);
  });

  test('snapshot has value equality on a stable state', () {
    final s = _session();
    expect(s.snapshot, equals(s.snapshot));
  });

  test('retry never re-poses the immediately-preceding question id, even with only 2 in the pool', () {
    final maze = MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'a',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char, doors: []),
      },
    );
    final pools = {0: [_q(1, 0), _q(2, 0)]};
    final s = GameSession(
      maze: maze,
      pools: pools,
      config: const GameConfig(startingLives: 5),
      random: Random(1),
    );
    var previousId = s.snapshot.currentQuestion!.id;
    for (var i = 0; i < 10; i++) {
      s.answer(_wrongIndex(s));
      if (s.snapshot.status == GameStatus.lost) break;
      final currentId = s.snapshot.currentQuestion!.id;
      expect(currentId, isNot(previousId));
      previousId = currentId;
    }
  });

  test('losing the game leaves currentQuestion null in the snapshot', () {
    final s = _session(config: const GameConfig(startingLives: 1));
    s.answer(_wrongIndex(s));
    expect(s.snapshot.status, GameStatus.lost);
    expect(s.snapshot.currentQuestion, isNull);
  });
}
