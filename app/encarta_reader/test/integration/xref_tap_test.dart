@Tags(['integration'])
library;

import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:encarta_reader/src/widgets/app_scope.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _shownTitle(WidgetTester tester) =>
    tester.widget<EncartaArticleBody>(find.byType(EncartaArticleBody)).doc.title;

void main() {
  testWidgets('article -> article navigation actually swaps the displayed article',
      (tester) async {
    final env = await bootstrap(const AppConfig(AppConfig.defaultDataDir),
        initMedia: () {});
    addTearDown(env.dispose);
    await tester.pumpWidget(EncartaReaderApp(env: env));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final nav =
        AppScope.of(tester.element(find.byType(EncartaToolbar))).navigator;

    // Open Africa.
    nav.openArticle(761572628);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(_shownTitle(tester), 'Africa');

    // A distinct target article that Africa links to.
    const target = 461511156;
    final targetArticle = await env.db.getArticle(target);
    expect(targetArticle, isNotNull);
    expect(targetArticle!.title, isNot('Africa'));

    // Navigate article -> article (the exact path an in-article link takes).
    nav.openArticle(target);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The DISPLAYED article must now be the target, not Africa.
    expect(_shownTitle(tester), targetArticle.title,
        reason: 'article->article navigation must swap the displayed article');
    expect(find.byType(ErrorWidget), findsNothing);

    // Back must return to Africa in ONE step (no phantom entry).
    nav.back();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(_shownTitle(tester), 'Africa',
        reason: 'one Back must return to Africa (no phantom history entry)');
  });
}
