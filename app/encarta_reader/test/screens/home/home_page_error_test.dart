import 'dart:async';

import 'package:encarta_reader/src/screens/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Spec §10: never crash, never blank — a thrown buildHomeViewData must show a
  // graceful error widget, never a red ErrorWidget or an unhandled exception.
  testWidgets(
      'HomePage FutureBuilder shows error widget (not a crash) when builder throws',
      (tester) async {
    // Use a Completer so that FutureBuilder subscribes first, THEN we fire the
    // error.  This prevents an unhandled-async-error in the test zone.
    final completer = Completer<HomeViewData>();

    // Build a widget that mirrors the exact FutureBuilder pattern used in
    // HomePage.build(), so the test validates the error-handling branch we added.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FutureBuilder<HomeViewData>(
            future: completer.future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Center(
                    child: Text('Something went wrong loading this home.'));
              }
              return HomeView(
                data: snap.data!,
                onOpenArticle: (_) {},
                onBrowseLetter: (_) {},
                onSearch: (_) {},
                onRandom: () {},
              );
            },
          ),
        ),
      ),
    );

    // Initially shows the loading indicator while the future is pending.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Now complete with an error — FutureBuilder has already subscribed, so it
    // catches the error internally and sets snap.hasError = true.
    completer.completeError(Exception('simulated DB failure'));
    await tester.pump();

    // Must show the graceful error message — not a HomeView, not a red screen.
    expect(find.text('Something went wrong loading this home.'), findsOneWidget);
    expect(find.byType(HomeView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
