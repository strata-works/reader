import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/end_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _end(int lives) => MaterialApp(
      home: Scaffold(
        body: MindMazeEndScreen(
          config: const AssetConfig('/no/such/dir'),
          score: 500,
          livesRemaining: lives,
          onPlayAgain: () {},
        ),
      ),
    );

void main() {
  testWidgets('end screen shows rank, score, art placeholders, and play-again', (tester) async {
    var played = 0;
    await tester.pumpWidget(MaterialApp(
      home: MindMazeEndScreen(
        config: const AssetConfig('/no/such/dir'), // nonexistent → art placeholders (never a real Image.file)
        score: 700,
        livesRemaining: 3,
        onPlayAgain: () => played++,
      ),
    ));

    // Authentic rank text + score.
    expect(find.text('Master Scholar Of MindMaze'), findsOneWidget);
    expect(find.textContaining('700'), findsOneWidget);
    // Art wired (derived PNGs absent in tests → labeled placeholders, no Image.file).
    expect(find.byKey(const ValueKey('mm-art-missing-end1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-trophy')), findsOneWidget);
    // Play again is wired.
    await tester.tap(find.byKey(const ValueKey('mm-restart')));
    expect(played, 1);
  });

  testWidgets('3 lives → gold: trophy + Master Scholar rank', (tester) async {
    await tester.pumpWidget(_end(3));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-gold')), findsOneWidget);
    expect(find.text('Master Scholar Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-trophy')), findsOneWidget);
  });

  testWidgets('2 lives → silver medal', (tester) async {
    await tester.pumpWidget(_end(2));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-silver')), findsOneWidget);
    expect(find.text('Scholar Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-medal')), findsOneWidget);
  });

  testWidgets('1 life → bronze ribbon', (tester) async {
    await tester.pumpWidget(_end(1));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-bronze')), findsOneWidget);
    expect(find.text('Apprentice Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-ribbon')), findsOneWidget);
  });
}
