import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/end_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('end screen shows rank, score, art placeholders, and play-again', (tester) async {
    var played = 0;
    await tester.pumpWidget(MaterialApp(
      home: MindMazeEndScreen(
        config: const AssetConfig.defaultConfig(),
        score: 700,
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
}
