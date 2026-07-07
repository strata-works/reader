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

// Fixture for the answer()-outcome tests below: minimalMaze() with a pool per
// area of 10 posable questions each, mirroring room_view_test.dart's _newGame.
Question _minimalQ(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct-$id', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _minimalPools() => {
      0: [for (var i = 0; i < 10; i++) _minimalQ(i, 0)],
      1: [for (var i = 10; i < 20; i++) _minimalQ(i, 1)],
    };

GameSession session({int lives = 3}) => GameSession(
      maze: minimalMaze(),
      pools: _minimalPools(),
      config: GameConfig(startingLives: lives),
      random: Random(1),
    );

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

  test('construction throws when a room\'s area is absent from pools', () {
    final maze = MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'c',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.right, targetRoomId: 'c')]),
        // Room 'c' lives in area 5, which has no entry in the pools below.
        'c': const Room(id: 'c', area: 5, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.left, targetRoomId: 'a')]),
      },
    );
    final pools = {
      0: [_q(1, 0)],
      1: [_q(11, 1)],
    };
    expect(
      () => GameSession(
        maze: maze,
        pools: pools,
        config: const GameConfig(),
        random: Random(1),
      ),
      throwsArgumentError,
    );
  });

  test('construction throws when a room\'s area pool is present but every question is malformed', () {
    final maze = MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'a',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char, doors: []),
      },
    );
    // A pool with an entry for area 0, but its only question has zero correct
    // choices, so it is not posable.
    final malformedQuestion = Question(
      id: 1,
      area: 0,
      clue: 'clue 1',
      choices: const [
        AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
      ],
    );
    final pools = {0: [malformedQuestion]};
    expect(
      () => GameSession(
        maze: maze,
        pools: pools,
        config: const GameConfig(),
        random: Random(1),
      ),
      throwsArgumentError,
    );
  });

  test('construction does not throw when every room\'s area has a posable question', () {
    expect(() => _session(), returnsNormally);
  });

  group('answer() returns an outcome', () {
    test('correct (non-goal) → AnswerOutcome.correct', () {
      final s = session();
      final q = s.snapshot.currentQuestion!;
      final correct = q.choices.indexWhere((c) => c.isCorrect);
      expect(s.answer(correct), AnswerOutcome.correct);
    });

    test('wrong (lives remain) → AnswerOutcome.wrong', () {
      final s = session();
      final q = s.snapshot.currentQuestion!;
      final wrong = q.choices.indexWhere((c) => !c.isCorrect);
      expect(s.answer(wrong), AnswerOutcome.wrong);
    });

    test('wrong at 1 life → AnswerOutcome.lost', () {
      final s = session(lives: 1);
      final q = s.snapshot.currentQuestion!;
      final wrong = q.choices.indexWhere((c) => !c.isCorrect);
      expect(s.answer(wrong), AnswerOutcome.lost);
      expect(s.snapshot.status, GameStatus.lost);
    });

    test('no-op (already-answered / game over) → null', () {
      final s = session();
      final q = s.snapshot.currentQuestion!;
      s.answer(q.choices.indexWhere((c) => c.isCorrect)); // clears room
      expect(s.answer(0), isNull); // currentQuestion is null now
    });

    test('correct on the goal room → AnswerOutcome.won', () {
      final s = session();
      // Walk the known winning path over minimalMaze():
      const path = [Direction.right, Direction.right, Direction.tower];
      for (final d in path) {
        s.answer(s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect));
        s.move(d);
      }
      final goalQ = s.snapshot.currentQuestion!;
      expect(s.answer(goalQ.choices.indexWhere((c) => c.isCorrect)), AnswerOutcome.won);
      expect(s.snapshot.status, GameStatus.won);
    });
  });
}
