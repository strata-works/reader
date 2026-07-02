import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HistoryController history;
  late List<String> gone;
  late AppNavigator nav;

  setUp(() {
    history = HistoryController();
    gone = <String>[];
    nav = AppNavigator(history: history, go: gone.add);
  });

  test('openArticle builds /article/:refid and records history', () {
    nav.openArticle(42);
    expect(gone.last, '/article/42');
    expect(history.current, '/article/42');
  });

  test('openArticle with paraId adds the anchor query', () {
    nav.openArticle(42, paraId: 'p7');
    expect(gone.last, '/article/42?para=p7');
  });

  test('openSearch encodes the query', () {
    nav.openSearch('black holes');
    expect(gone.last, '/search?q=black%20holes');
  });

  test('back navigates to the previous location without re-pushing', () {
    nav.openHome();
    nav.openArticle(1);
    gone.clear();
    nav.back();
    expect(gone.single, '/');
    expect(history.current, '/');
  });
}
