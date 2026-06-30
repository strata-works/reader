import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(HistoryController history, List<String> gone) {
    final nav = AppNavigator(history: history, go: gone.add);
    return MaterialApp(
      home: Scaffold(
        body: EncartaToolbar(
          theme: EncartaTheme.faithfulInSpirit(),
          history: history,
          navigator: nav,
        ),
      ),
    );
  }

  testWidgets('home button navigates to /', (tester) async {
    final gone = <String>[];
    await tester.pumpWidget(host(HistoryController(), gone));
    await tester.tap(find.byKey(const Key('toolbar.home')));
    expect(gone, contains('/'));
  });

  testWidgets('back is disabled with empty history, enabled after two pushes',
      (tester) async {
    final history = HistoryController();
    await tester.pumpWidget(host(history, <String>[]));
    final backFinder = find.byKey(const Key('toolbar.back'));
    expect(tester.widget<IconButton>(backFinder).onPressed, isNull);

    history.push('/');
    history.push('/article/1');
    await tester.pump();
    expect(tester.widget<IconButton>(backFinder).onPressed, isNotNull);
  });

  testWidgets('submitting the search box navigates to /search', (tester) async {
    final gone = <String>[];
    await tester.pumpWidget(host(HistoryController(), gone));
    await tester.enterText(find.byKey(const Key('toolbar.search')), 'mars');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(gone.last, '/search?q=mars');
  });
}
