import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import '../screens/article/article_page.dart';
import '../screens/home/home_page.dart';
import '../screens/mindmaze/mindmaze_page.dart';
import '../screens/search/search_page.dart';
import '../screens/tours/tours_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  // Back/Forward are driven by our HistoryController via pushPath, so a
  // DIRECTIONAL slide (auto_route's default) animates Back like a forward push,
  // which looks wrong. A short, non-directional fade reads as a clean content
  // swap — closer to how Encarta itself changed pages.
  @override
  RouteType get defaultRouteType => RouteType.custom(
        transitionsBuilder: TransitionsBuilders.fadeIn,
        duration: const Duration(milliseconds: 150),
        reverseDuration: const Duration(milliseconds: 150),
      );

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, path: '/', initial: true),
        AutoRoute(page: SearchRoute.page, path: '/search'),
        AutoRoute(page: ArticleRoute.page, path: '/article/:refid'),
        AutoRoute(page: MindMazeRoute.page, path: '/mindmaze'),
        AutoRoute(page: ToursRoute.page, path: '/tours/:tourId'),
      ];
}
