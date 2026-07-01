@Tags(['integration'])
library;

import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:encarta_reader/src/widgets/app_scope.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TapGestureRecognizer? _firstLink(WidgetTester tester) {
  TapGestureRecognizer? found;
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    void walk(InlineSpan s) {
      if (found != null) return;
      if (s is TextSpan) {
        final r = s.recognizer;
        if (r is TapGestureRecognizer && r.onTap != null) { found = r; return; }
        for (final c in s.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
    }
    walk(rt.text);
    if (found != null) break;
  }
  return found;
}

void main() {
  testWidgets('tapping an in-article link navigates to another article', (tester) async {
    final env = await bootstrap(const AppConfig(AppConfig.defaultDataDir), initMedia: () {});
    addTearDown(env.dispose);
    await tester.pumpWidget(EncartaReaderApp(env: env));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Open the (rich, link-heavy) Africa article.
    AppScope.of(tester.element(find.byType(EncartaToolbar))).navigator.openArticle(761572628);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(EncartaArticleBody), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);

    // Find a real in-article link and fire it (mirrors a tap on its glyphs).
    final link = _firstLink(tester);
    expect(link, isNotNull, reason: 'Africa body must render at least one live xref link');
    link!.onTap!();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Must have navigated to another article, without crashing.
    expect(find.byType(EncartaArticleBody), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
