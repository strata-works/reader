import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:encarta_reader/src/widgets/app_scope.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppScope.of exposes injected dependencies', (tester) async {
    final theme = EncartaTheme.faithfulInSpirit();
    final titles = ArticleTitleCache(fetch: (_) async => null);
    final nav = AppNavigator(history: HistoryController(), go: (_) {});
    AppScope? captured;

    await tester.pumpWidget(
      AppScope(
        db: null,
        assets: null,
        theme: theme,
        navigator: nav,
        titles: titles,
        child: Builder(
          builder: (context) {
            captured = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(captured, isNotNull);
    expect(identical(captured!.theme, theme), isTrue);
    expect(identical(captured!.titles, titles), isTrue);
  });
}
