// Widget test for Task 9's ToursPage: verifies the missing-assets path shows
// a friendly message (never a red error box), plus Task 7's walk-mode chrome
// (mode toggle, glide travel, stops panel, narration). The success/GL path
// for the 3-D viewport itself is NOT tested here — flutter_scene's GPU
// context is unavailable headless (see tour_view_test.dart's guarded-
// placeholder approach for why); these tests only exercise the page-level
// chrome built atop TourView's headless placeholder mode.
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_reader/src/screens/tours/tours_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stub AssetBundle whose load() throws for every key, so loadTour() always
/// hits its TourAssetsMissing catch path regardless of tourId.
class _ThrowingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('missing: $key');
}

/// A stub AssetBundle serving in-memory fixtures: JSON strings (scene,
/// hotspots) plus raw binary asset bytes (walkmap). The glb/points assets are
/// deliberately absent so TourView degrades to its headless placeholder,
/// matching tour_adapter_test.dart's _StubAssetBundle pattern.
class _FakeTourBundle extends CachingAssetBundle {
  final Map<String, String> strings;
  final Map<String, List<int>> binaries;
  _FakeTourBundle({this.strings = const {}, this.binaries = const {}});

  @override
  Future<ByteData> load(String key) async {
    final s = strings[key];
    if (s != null) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
    }
    final b = binaries[key];
    if (b != null) {
      return ByteData.sublistView(Uint8List.fromList(b));
    }
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final s = strings[key];
    if (s == null) throw FlutterError('Unable to load asset: $key');
    return s;
  }
}

/// A flat, walkable 14x40-ish ground plane (two triangles) so
/// `Walkmap.groundHeightAt` resolves everywhere the fixture's hotspot anchors
/// sit. Byte format per encarta_3dtours' Walkmap.fromBytes: u32 triCount (LE)
/// then triCount * 9 LE f32 (three xyz vertices per triangle).
List<int> flatWalkmapBytes() {
  const flat = <double>[
    -20,
    0,
    -20,
    20,
    0,
    -20,
    20,
    0,
    20,
    -20,
    0,
    -20,
    20,
    0,
    20,
    -20,
    0,
    20,
  ];
  final bd = ByteData(4 + flat.length * 4)
    ..setUint32(0, flat.length ~/ 9, Endian.little);
  for (var i = 0; i < flat.length; i++) {
    bd.setFloat32(4 + i * 4, flat[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

/// Two anchored (travelable) hotspots, ids h1/h2, matching the brief.
final _hotspotsJson = jsonEncode([
  {
    'id': 'h1',
    'text': 'Stop one',
    'anchor': [0, 1.44, 0, 90],
  },
  {
    'id': 'h2',
    'text': 'Stop two',
    'anchor': [4, 1.44, 4, 180],
  },
]);

_FakeTourBundle _tourBundleWithWalkmap() => _FakeTourBundle(
  strings: {
    'assets/3dtours/acropolis/acr.scene.json': '{"lights":[]}',
    'assets/3dtours/acropolis/acr.hotspots.json': _hotspotsJson,
  },
  binaries: {'assets/3dtours/acropolis/acr_walkmap.bin': flatWalkmapBytes()},
);

Future<void> pumpToursPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ToursPage(
        tourId: 'acropolis',
        bundleOverride: _tourBundleWithWalkmap(),
      ),
    ),
  );
  // NOT pumpAndSettle(): once the FutureBuilder resolves, TourView mounts and
  // starts its own render Ticker (tour_view.dart), which reschedules a frame
  // every tick for as long as the widget is alive — by design, it repaints
  // continuously rather than settling (see tour_view_test.dart, which for the
  // same reason drives frames with bounded `pump()` calls, never
  // pumpAndSettle). A few plain pumps are enough to drain the loadTour +
  // walkmap-load futures (in-memory fixtures, no real async delay) and let
  // the page settle into its loaded state.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows friendly message when tour assets are missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ToursPage(tourId: 'acropolis', bundleOverride: _ThrowingBundle()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not found'), findsOneWidget);
  });

  testWidgets('walk toggle enters walk mode at the first stop with narration', (
    tester,
  ) async {
    await pumpToursPage(tester); // existing helper, now with walkmap + anchors
    await tester.tap(find.byKey(const ValueKey('tour-mode-toggle')));
    await tester.pump(); // entering walk mode is a synchronous setState
    expect(find.byKey(const ValueKey('tour-narration')), findsOneWidget);
    expect(find.textContaining('stop 1 /'), findsOneWidget);
  });

  testWidgets('next glides to the following stop and updates the counter', (
    tester,
  ) async {
    await pumpToursPage(tester);
    await tester.tap(find.byKey(const ValueKey('tour-mode-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tour-next-stop')));
    // A bare pump() first establishes the AnimationController's ticker
    // baseline frame (elapsed 0) — like fading-transition tests generally
    // need, since the ticker's start time binds to the FIRST frame it
    // observes after forward(), not the moment forward() was called. Without
    // it, this first duration pump would be consumed as that baseline and
    // only the following pump's duration would count as elapsed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // mid-glide
    await tester.pump(
      const Duration(milliseconds: 700),
    ); // glide completes (>1200ms total)
    expect(find.textContaining('stop 2 /'), findsOneWidget);
  });

  testWidgets('stops panel lists stops and tapping one travels', (
    tester,
  ) async {
    await pumpToursPage(tester);
    await tester.tap(find.byKey(const ValueKey('tour-stops-panel-toggle')));
    await tester.pump();
    // Tap the second stop in the panel (use the second hotspot id from the fake).
    await tester.tap(find.byKey(const ValueKey('stop-h2')));
    await tester.pump(); // synchronously enters walk mode + starts the glide
    await tester.pump(const Duration(milliseconds: 1300)); // glide completes
    expect(find.textContaining('stop 2 /'), findsOneWidget);
  });
}
