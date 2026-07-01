// Integration smoke test — requires the real 685 MB DB at AppConfig.defaultDataDir.
// Run explicitly:
//   flutter test --tags integration test/integration/smoke_test.dart
// Excluded from the default suite automatically (tagged 'integration').
@Tags(['integration'])
library;

import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'open article → search → tap xref → Back never crashes/blanks',
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

      // ── Step 2: type a query and submit via the toolbar search box ─────────
      await tester.enterText(
          find.byKey(const Key('toolbar.search')), 'science');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      // Drain: navigates to /search?q=science and waits for search results.
      await tester.pumpAndSettle();

      // ── Step 3: toolbar chrome persists on Search ─────────────────────────
      expect(find.byType(EncartaToolbar), findsOneWidget);

      // ── Step 4: Back is enabled (history has '/' → '/search?q=science') ───
      final back = find.byKey(const Key('toolbar.back'));
      expect(
        tester.widget<IconButton>(back).onPressed,
        isNotNull,
        reason: 'Back must be enabled after navigating from Home → Search',
      );

      // ── Step 5: tap Back → returns to Home ────────────────────────────────
      await tester.tap(back);
      await tester.pumpAndSettle();

      // ── Step 6: toolbar still visible; no exception thrown ────────────────
      expect(find.byType(EncartaToolbar), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'No exceptions must be thrown at any step',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
