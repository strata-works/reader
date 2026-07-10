// Widget test for Task 9's ToursPage: verifies the missing-assets path shows
// a friendly message (never a red error box). The success/GL path is NOT
// tested here — flutter_scene's GPU context is unavailable headless (see
// tour_view_test.dart's guarded-placeholder approach for why).
import 'package:encarta_reader/src/screens/tours/tours_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stub AssetBundle whose load() throws for every key, so loadTour() always
/// hits its TourAssetsMissing catch path regardless of tourId.
class _ThrowingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw FlutterError('missing: $key');
}

void main() {
  testWidgets('shows friendly message when tour assets are missing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ToursPage(tourId: 'acropolis', bundleOverride: _ThrowingBundle()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('not found'), findsOneWidget);
  });
}
