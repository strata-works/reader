import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

import 'mindmaze_art.dart';

// Authored win/rank text. The authentic rank string ("Master Scholar Of
// MindMaze") and story were decoded in Phase 5a analysis but are not persisted
// in a queryable table; the short win blurb is authored in-style.
const _rank = 'Master Scholar Of MindMaze';
const _blurb = "Zorlock's curse is broken. The throne room opens, and the "
    'castle is yours.';

/// The MindMaze victory screen: the `end1` scene behind a `trophy`, the
/// authentic rank, the final [score], and a play-again action.
class MindMazeEndScreen extends StatelessWidget {
  const MindMazeEndScreen({
    super.key,
    required this.config,
    required this.score,
    required this.onPlayAgain,
  });

  final AssetConfig config;
  final int score;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('mm-won'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          mindMazeArt(config, 'end1', fit: BoxFit.cover),
          Container(color: const Color(0xCC000000)),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: mindMazeArt(config, 'trophy', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  const Text('You have won the castle!',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 8),
                  const Text(_rank,
                      style: TextStyle(
                          color: Color(0xFFF2D06B),
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_blurb,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  Text('Final score: $score',
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('mm-restart'),
                    onPressed: onPlayAgain,
                    child: const Text('Play again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
