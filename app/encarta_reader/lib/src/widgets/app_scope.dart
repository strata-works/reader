import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/widgets.dart';

import '../data/title_cache.dart';
import '../nav/app_navigator.dart';
import '../screens/mindmaze/mindmaze_game_holder.dart';

/// Carries app-wide singletons to every screen.
class AppScope extends InheritedWidget {
  final EncartaDb? db;
  final EncartaAssets? assets;
  final EncartaTheme theme;
  final AppNavigator navigator;
  final ArticleTitleCache titles;
  final MindMazeGameHolder mindMazeGame;

  const AppScope({
    super.key,
    required this.db,
    required this.assets,
    required this.theme,
    required this.navigator,
    required this.titles,
    required this.mindMazeGame,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      db != oldWidget.db ||
      assets != oldWidget.assets ||
      theme != oldWidget.theme ||
      navigator != oldWidget.navigator ||
      titles != oldWidget.titles ||
      mindMazeGame != oldWidget.mindMazeGame;
}
