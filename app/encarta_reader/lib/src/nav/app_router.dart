import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import '../screens/article/article_page.dart';
import '../screens/home/home_page.dart';
import '../screens/search/search_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, path: '/', initial: true),
        AutoRoute(page: SearchRoute.page, path: '/search'),
        AutoRoute(page: ArticleRoute.page, path: '/article/:refid'),
      ];
}
