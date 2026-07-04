import 'dart:math';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:encarta_reader/src/screens/mindmaze/game_audio.dart';
import 'package:encarta_reader/src/screens/mindmaze/room_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAudio implements GameAudio {
  final List<GameSfx> sfx = [];
  int backgroundStarts = 0;
  bool _muted = false;
  @override
  void startBackground() => backgroundStarts++;
  @override
  void playSfx(GameSfx s) => sfx.add(s);
  @override
  void setMuted(bool m) => _muted = m;
  @override
  bool get muted => _muted;
  @override
  void dispose() {}
}

Question _q(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct-$id', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _pools() => {
      0: [for (var i = 0; i < 10; i++) _q(i, 0)],
      1: [for (var i = 10; i < 20; i++) _q(i, 1)],
    };

GameSession _newGame({int lives = 3}) => GameSession(
      maze: minimalMaze(),
      pools: _pools(),
      config: GameConfig(startingLives: lives),
      random: Random(1),
    );

Widget _app({int lives = 3, GameAudio? audio}) => MaterialApp(
      home: RoomView(
        newGame: () => _newGame(lives: lives),
        maze: minimalMaze(),
        config: const AssetConfig('/no/such/dir'), // art → placeholders
        audio: audio ?? _RecordingAudio(),
      ),
    );

void main() {
  testWidgets('renders the clue and one answer button per choice', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.textContaining('clue '), findsWidgets);
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-answer-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-lives')), findsOneWidget);
  });

  testWidgets('correct answer clears the room → door buttons replace answers', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // Tap whichever answer is correct.
    await tester.tap(_correctAnswerFinder(tester));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-answer-0')), findsNothing);
    // atrium has doors right→library and tower→gallery
    expect(
      find.byKey(const ValueKey('mm-door-right')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('mm-door-tower')).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('wrong answer removes a life and re-poses a question', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_wrongAnswerFinder(tester));
    await tester.pump();
    // still answering (not cleared), and an answer button is present again
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
    // 3 → 2 hearts: assert the lives row reports 2 (see _RoomViewState renders count)
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('draining lives shows the lose overlay; Try again resets', (tester) async {
    await tester.pumpWidget(_app(lives: 1));
    await tester.pump();
    await tester.tap(_wrongAnswerFinder(tester));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-lost')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mm-restart')));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-lost')), findsNothing);
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
  });

  testWidgets('answering through to the goal shows the win overlay', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // Follow the known winning path over minimalMaze() deterministically
    // (a greedy first-door walk would cycle atrium↔library forever, since
    // library's doors list the backward edge first):
    //   atrium --right--> library --right--> hall --tower--> throne(goal)
    // At each room: answer correctly (clear), then move; finally clear the goal.
    const path = [Direction.right, Direction.right, Direction.tower];
    for (final dir in path) {
      await tester.tap(_correctAnswerFinder(tester)); // clear current room
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('mm-door-${dir.name}'))); // step forward
      await tester.pump();
    }
    await tester.tap(_correctAnswerFinder(tester)); // answer the throne's question
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-won')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-answer-0')), findsNothing);
  });

  testWidgets('construction failure degrades to a message, not a red screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoomView(
        newGame: () => throw ArgumentError('boom'),
        maze: minimalMaze(),
        config: const AssetConfig('/no/such/dir'),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-start-failed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts background music on entry and plays SFX on outcomes',
      (tester) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(MaterialApp(
      home: RoomView(
        newGame: _newGame,
        maze: minimalMaze(),
        config: const AssetConfig('/no/such/dir'),
        audio: audio,
      ),
    ));
    await tester.pump();
    expect(audio.backgroundStarts, 1);

    await tester.tap(_wrongAnswerFinder(tester));
    await tester.pump();
    expect(audio.sfx, contains(GameSfx.wrong));

    await tester.tap(_correctAnswerFinder(tester));
    await tester.pump();
    expect(audio.sfx, contains(GameSfx.correct));

    await tester.tap(find.byKey(const ValueKey('mm-door-right')));
    await tester.pump();
    expect(audio.sfx, contains(GameSfx.door));
  });

  testWidgets('mute button toggles audio mute', (tester) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(MaterialApp(
      home: RoomView(
        newGame: _newGame,
        maze: minimalMaze(),
        config: const AssetConfig('/no/such/dir'),
        audio: audio,
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mm-mute')));
    await tester.pump();
    expect(audio.muted, isTrue);
  });
}

// Helpers that locate the correct/wrong answer button by the label convention.
Finder _correctAnswerFinder(WidgetTester tester) =>
    find.byWidgetPredicate((w) =>
        w is FilledButton &&
        w.child is Text &&
        (w.child as Text).data != null &&
        (w.child as Text).data!.startsWith('correct-'));

Finder _wrongAnswerFinder(WidgetTester tester) =>
    find.byWidgetPredicate((w) =>
        w is FilledButton &&
        w.child is Text &&
        (w.child as Text).data == 'w1');
