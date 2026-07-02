import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'mindmaze_pools.dart';
import 'room_view.dart';

@RoutePage()
class MindMazePage extends StatefulWidget {
  const MindMazePage({super.key});

  @override
  State<MindMazePage> createState() => _MindMazePageState();
}

class _MindMazePageState extends State<MindMazePage> {
  Future<Map<int, List<mm.Question>>?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final db = AppScope.of(context).db;
    if (db == null) {
      _future = Future.value(null);
      return;
    }
    // Coupling: the loaded pools' areas must cover every room.area used by
    // the maze below. buildMindMazePools defaults to areas [0,1], and
    // minimalMaze() uses exactly {0,1} — keep them in sync if either changes.
    _future = buildMindMazePools(
      mindmazeQuestions: (area) => db.mindmazeQuestions(area: area),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<Map<int, List<mm.Question>>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('MindMaze could not start.'));
        }
        final pools = snap.data;
        if (pools == null || pools.values.any((l) => l.isEmpty)) {
          return const Center(child: Text('MindMaze questions are unavailable.'));
        }
        final maze = mm.minimalMaze();
        final config = scope.assets?.config ?? const AssetConfig.defaultConfig();
        return RoomView(
          maze: maze,
          config: config,
          newGame: () => mm.GameSession(
            maze: maze,
            pools: pools,
            config: const mm.GameConfig(),
            random: Random(),
          ),
        );
      },
    );
  }
}
