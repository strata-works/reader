// Integration smoke test — requires the real 685 MB DB at AppConfig.defaultDataDir.
// Run explicitly:
//   flutter test --tags integration test/integration/smoke_test.dart
// Excluded from the default suite automatically (tagged 'integration').
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

void main() {
  testWidgets(
    'open article → second article → back → search → back never crashes/blanks',
    (tester) async {
      // Bootstrap against the real DB; suppress libmpv (not available headless).
      final env = await bootstrap(
        const AppConfig(AppConfig.defaultDataDir),
        initMedia: () {}, // no-op: media_kit/libmpv not available in flutter test
      );
      addTearDown(env.dispose);

      await tester.pumpWidget(EncartaReaderApp(env: env));
      // Drain the event loop so the home-page Future (db.featured) can complete.
      await tester.pumpAndSettle();

      // ── Step 1: toolbar chrome is present on Home ─────────────────────────
      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      // Obtain a real refid guaranteed to exist in the corpus.
      final featured = await env.db.featured(limit: 1);
      expect(featured, isNotEmpty, reason: 'DB must have at least one featured article');
      final refid1 = featured.first.refid;
      final title1 = featured.first.title;

      // ── Step 2: navigate to Article 1 via the wired AppNavigator ──────────
      AppScope.of(tester.element(find.byType(EncartaToolbar)))
          .navigator
          .openArticle(refid1);
      await tester.pumpAndSettle();

      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(
        find.byType(EncartaArticleBody),
        findsOneWidget,
        reason:
            'ArticlePage must inflate EncartaArticleBody for refid=$refid1 ($title1)',
      );
      expect(tester.takeException(), isNull,
          reason: 'No exception loading article $refid1 ($title1)');
      expect(find.byType(ErrorWidget), findsNothing);

      // ── Step 3: navigate to Article 2 (article→article routing) ───────────
      final article2 = await env.db.randomArticle();
      expect(article2, isNotNull,
          reason: 'DB must have at least one randomly-chosen article');
      final refid2 = article2!.refid;

      AppScope.of(tester.element(find.byType(EncartaToolbar)))
          .navigator
          .openArticle(refid2);
      await tester.pumpAndSettle();

      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(
        find.byType(EncartaArticleBody),
        findsOneWidget,
        reason:
            'ArticlePage must inflate EncartaArticleBody for refid=$refid2 (${article2.title})',
      );
      expect(tester.takeException(), isNull,
          reason: 'No exception loading article $refid2');
      expect(find.byType(ErrorWidget), findsNothing);

      // ── Step 3b: a KNOWN duplicate-id article (regression guard) ──────────
      // The "William Shakespeare" article (refid 761562101) reuses element ids
      // across nested elements. Anchor keying once gave them the same GlobalKey
      // → a framework 'child == _child' crash. Opening it must not error.
      final shakespeare = await env.db.getArticle(761562101);
      if (shakespeare != null) {
        AppScope.of(tester.element(find.byType(EncartaToolbar)))
            .navigator
            .openArticle(761562101);
        await tester.pumpAndSettle();
        expect(find.byType(EncartaArticleBody), findsOneWidget,
            reason: 'duplicate-id article must render its body, not an error');
        expect(tester.takeException(), isNull,
            reason: 'No GlobalKey collision on the duplicate-id article');
        expect(find.byType(ErrorWidget), findsNothing);
      }

      // ── Step 4: press Back → returns to a prior article ───────────────────
      final back = find.byKey(const Key('toolbar.back'));
      expect(
        tester.widget<IconButton>(back).onPressed,
        isNotNull,
        reason: 'Back must be enabled after article→article navigation',
      );
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(
        find.byType(EncartaArticleBody),
        findsOneWidget,
        reason: 'Back from article 2 must return to an article screen',
      );
      expect(tester.takeException(), isNull,
          reason: 'No exception after Back to article 1');
      expect(find.byType(ErrorWidget), findsNothing);

      // ── Step 5: type a query and submit via the toolbar search box ─────────
      await tester.enterText(
          find.byKey(const Key('toolbar.search')), 'science');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      // Drain: navigates to /search?q=science and waits for search results.
      await tester.pumpAndSettle();

      // ── Step 6: toolbar chrome persists on Search ─────────────────────────
      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      // ── Step 7: Back is enabled (history has prior entries) ───────────────
      expect(
        tester.widget<IconButton>(back).onPressed,
        isNotNull,
        reason: 'Back must be enabled after navigating from article → Search',
      );

      // ── Step 8: tap Back → returns to previous screen ─────────────────────
      await tester.tap(back);
      await tester.pumpAndSettle();

      // ── Step 9: toolbar still visible; no exception thrown ────────────────
      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'No exceptions must be thrown at any step',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
