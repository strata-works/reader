import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'castle_adapter.dart';
import 'game_audio.dart';
import 'mindmaze_audio.dart';
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
  GameAudio? _audio;

  GameAudio _audioFor(AssetConfig config) {
    // Guard construction: in headless tests (or if mpv fails) fall back to
    // silence instead of throwing.
    if (_audio != null) return _audio!;
    try {
      _audio = MindMazeAudio(config);
    } catch (_) {
      _audio = const SilentGameAudio();
    }
    return _audio!;
  }

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final db = AppScope.of(context).db;
    if (db == null) {
      _future = Future.value(null);
      return;
    }
    _future = () async {
      // Build the authentic castle, then load exactly the pools its rooms use.
      final maze = castleToMaze(await db.mindmazeCastle());
      final pools = await buildMindMazePools(
        areas: mazeAreas(maze),
        mindmazeQuestions: (area) => db.mindmazeQuestions(area: area),
      );
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
          audio: _audioFor(config),
          onOpenArticle: (refid) => scope.navigator.openArticle(refid),
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
