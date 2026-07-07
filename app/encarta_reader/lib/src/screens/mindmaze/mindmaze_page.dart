import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'castle_adapter.dart';
import 'mindmaze_pools.dart';
import 'room_view.dart';

@RoutePage()
class MindMazePage extends StatefulWidget {
  const MindMazePage({super.key});

  @override
  State<MindMazePage> createState() => _MindMazePageState();
}

/// The loaded maze plus its question pools — everything RoomView needs.
class _Loaded {
  const _Loaded(this.maze, this.pools);
  final mm.MazeGraph maze;
  final Map<int, List<mm.Question>> pools;
}

class _MindMazePageState extends State<MindMazePage> {
  Future<_Loaded?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final scope = AppScope.of(context);
    final db = scope.db;
    final holder = scope.mindMazeGame;
    if (db == null) {
      _future = Future.value(null);
      return;
    }
    _future = () async {
      if (holder.maze != null && holder.pools != null) {
        return _Loaded(holder.maze!, holder.pools!);
      }
      // Build the authentic castle, then load exactly the pools its rooms use.
      final maze = castleToMaze(await db.mindmazeCastle());
      final pools = await buildMindMazePools(
        areas: mazeAreas(maze),
        mindmazeQuestions: (area) => db.mindmazeQuestions(area: area),
      );
      holder.maze = maze;
      holder.pools = pools;
      return _Loaded(maze, pools);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<_Loaded?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('MindMaze could not start.'));
        }
        final loaded = snap.data;
        if (loaded == null || loaded.pools.values.any((l) => l.isEmpty)) {
          return const Center(child: Text('MindMaze questions are unavailable.'));
        }
        final config = scope.assets?.config ?? const AssetConfig.defaultConfig();
        return RoomView(
          maze: loaded.maze,
          config: config,
          audio: scope.mindMazeAudio,
          onOpenArticle: (refid) => scope.navigator.openArticle(refid),
          holder: scope.mindMazeGame,
          newGame: () => mm.GameSession(
            maze: loaded.maze,
            pools: loaded.pools,
            config: const mm.GameConfig(),
            random: Random(),
          ),
        );
      },
    );
  }
}
