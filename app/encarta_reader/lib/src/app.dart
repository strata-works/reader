import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'data/title_cache.dart';
import 'nav/app_navigator.dart';
import 'nav/app_router.dart';
import 'nav/history_controller.dart';
import 'screens/mindmaze/game_audio.dart';
import 'screens/mindmaze/mindmaze_audio.dart';
import 'screens/mindmaze/mindmaze_game_holder.dart';
import 'widgets/app_scope.dart';
import 'widgets/top_toolbar.dart';

class EncartaReaderApp extends StatefulWidget {
  final AppEnvironment? env;
  const EncartaReaderApp({super.key, required this.env});

  @override
  State<EncartaReaderApp> createState() => _EncartaReaderAppState();
}

class _EncartaReaderAppState extends State<EncartaReaderApp> {
  final _router = AppRouter();
  final _history = HistoryController();
  late final _theme = EncartaTheme.faithfulInSpirit();
  late final AppNavigator _navigator;
  late final ArticleTitleCache _titles;
  final _mindMazeGame = MindMazeGameHolder();
  late final GameAudio _mindMazeAudio;

  @override
  void initState() {
    super.initState();
    final assetConfig =
        widget.env?.assets.config ?? const AssetConfig.defaultConfig();
    GameAudio audio;
    try {
      audio = MindMazeAudio(assetConfig);
    } catch (_) {
      audio = const SilentGameAudio();
    }
    _mindMazeAudio = audio;
    _navigator = AppNavigator(
      history: _history,
      // Our HistoryController owns Back/Forward, so `go` just needs to DISPLAY
      // the given location. `navigatePath`/`replacePath` REUSE the existing page
      // when the target matches the current route pattern, so article -> article
      // never swapped the displayed ArticlePage (and history desynced, making
      // Back take two taps). `pushPath` always inflates a fresh page for the new
      // params, keeping display in sync with our history so Back works in one
      // tap. (Trade-off: auto_route's own stack grows over a session; harmless
      // here since our HistoryController — not auto_route — drives Back/Forward.)
      //
      // MindMaze owns a single app-lifetime background player (see
      // _mindMazeAudio above); every navigation routes through here, so this
      // is also the hook that starts/stops it by location.
      go: (location) {
        applyMindMazeBackground(location, _mindMazeAudio);
        _router.pushPath(location);
      },
    );
    final db = widget.env?.db;
    _titles = ArticleTitleCache(
      fetch: (refid) async => (await db?.getArticle(refid))?.title,
    );
    _history.push('/'); // record initial location
  }

  @override
  void dispose() {
    _mindMazeAudio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: widget.env?.db,
      assets: widget.env?.assets,
      theme: _theme,
      navigator: _navigator,
      titles: _titles,
      mindMazeGame: _mindMazeGame,
      mindMazeAudio: _mindMazeAudio,
      child: MaterialApp.router(
        title: 'Encarta Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Selawik',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E86B0), // chrome teal
          ),
          scaffoldBackgroundColor: const Color(0xFFFCFDFE), // content bg
        ),
        routerConfig: _router.config(),
        builder: (context, child) => Overlay(
          initialEntries: [
            OverlayEntry(
              opaque: true,
              maintainState: true,
              builder: (_) => Column(
                children: [
                  EncartaToolbar(
                    theme: _theme,
                    history: _history,
                    navigator: _navigator,
                  ),
                  Expanded(
                    child: Material(
                      child: child ?? const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
