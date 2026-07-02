import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/app_router.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openMindMaze navigates to /mindmaze and records history', () {
    final visited = <String>[];
    final nav = AppNavigator(
      history: HistoryController(),
      go: visited.add,
    );
    nav.openMindMaze();
    expect(visited, ['/mindmaze']);
    expect(nav.history.canGoBack, isFalse); // first entry
  });

  test('the router registers a /mindmaze route', () {
    final router = AppRouter();
    final paths = router.routes.map((r) => r.path).toList();
    expect(paths, contains('/mindmaze'));
  });
}
