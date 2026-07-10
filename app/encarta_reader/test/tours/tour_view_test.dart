// Widget test for the flutter_scene tour viewport (Task 7).
//
// Runs WITHOUT the glb/points assets (they are gitignored) — TourView must
// still build a placeholder and, crucially, still handle orbit gestures. A
// horizontal drag must produce a mutated OrbitCamera via onCameraChanged with a
// changed azimuth.
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:encarta_reader/src/screens/tours/tour_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('drag updates camera azimuth via onCameraChanged',
      (tester) async {
    OrbitCamera? captured;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 5);

    await tester.pumpWidget(MaterialApp(
      home: TourView(
        glbAsset: '/nope',
        pointsAsset: '/nope',
        camera: cam,
        onCameraChanged: (c) => captured = c,
      ),
    ));
    await tester.pump();

    await tester.drag(find.byType(TourView), const Offset(50, 0));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.azimuth, isNot(closeTo(cam.azimuth, 1e-9)));
  });

  testWidgets('vertical drag raises elevation but clamps at +1.48 rad',
      (tester) async {
    OrbitCamera? captured;
    // Start near the top clamp; a large upward drag must not exceed +1.48 rad.
    final cam =
        OrbitCamera(target: Vector3.zero(), distance: 5, elevation: 1.4);

    await tester.pumpWidget(MaterialApp(
      home: TourView(
        glbAsset: '/nope',
        pointsAsset: '/nope',
        camera: cam,
        onCameraChanged: (c) => captured = c,
      ),
    ));
    await tester.pump();

    // Negative dy raises elevation.
    await tester.drag(find.byType(TourView), const Offset(0, -4000));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.elevation, greaterThan(cam.elevation - 1e-9));
    expect(captured!.elevation, lessThanOrEqualTo(1.48 + 1e-9));
  });

  testWidgets('pointer scroll changes distance and clamps to a sane range',
      (tester) async {
    OrbitCamera? captured;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 200);

    await tester.pumpWidget(MaterialApp(
      home: TourView(
        glbAsset: '/nope',
        pointsAsset: '/nope',
        camera: cam,
        onCameraChanged: (c) => captured = c,
      ),
    ));
    await tester.pump();

    // A large scroll-down (positive dy) zooms out; distance grows but stays
    // finite/positive and within the derived upper clamp (distance * 20).
    final center = tester.getCenter(find.byType(TourView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100000)));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.distance, isNot(closeTo(cam.distance, 1e-9)));
    expect(captured!.distance, greaterThan(0));
    expect(captured!.distance, lessThanOrEqualTo(cam.distance * 20 + 1e-9));
  });
}
