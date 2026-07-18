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
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('drag updates camera azimuth via onOrbitChanged',
      (tester) async {
    OrbitCamera? captured;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 5);

    await tester.pumpWidget(MaterialApp(
      home: TourView(
        glbAsset: '/nope',
        pointsAsset: '/nope',
        camera: cam,
        onOrbitChanged: (c) => captured = c,
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
        onOrbitChanged: (c) => captured = c,
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
        onOrbitChanged: (c) => captured = c,
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

  group('walk mode', () {
    // A 40x40 flat square at y=0 around the origin (two triangles).
    final flatGround = Walkmap.fromTriangles(const [
      -20, 0, -20, 20, 0, -20, 20, 0, 20,
      -20, 0, -20, 20, 0, 20, -20, 0, 20,
    ]);

    // IMPORTANT: TourView never mutates widget.camera — it emits fresh copies
    // via onWalkChanged and relies on its parent to rebuild it with the new
    // camera (ToursPage does this with setState). The harness must close that
    // loop or movement will never accumulate across ticks.
    Future<WalkCamera Function()> pumpWalk(
      WidgetTester tester, {
      required WalkCamera camera,
      Walkmap? walkmap,
      bool inputLocked = false,
      void Function()? onEmit,
    }) async {
      var cam = camera;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => TourView(
            glbAsset: 'missing.glb',
            pointsAsset: 'missing.bin',
            camera: cam,
            onWalkChanged: (c) {
              onEmit?.call();
              setState(() => cam = c);
            },
            walkmap: walkmap,
            showPoints: false,
            inputLocked: inputLocked,
          ),
        ),
      ));
      return () => cam;
    }

    testWidgets('drag look accumulates yaw and pitch', (tester) async {
      final cam = await pumpWalk(tester,
          camera: WalkCamera(position: Vector3(0, 1.45, 0)));
      await tester.drag(find.byType(TourView), const Offset(120, -60),
          warnIfMissed: false);
      await tester.pump();
      // Touch slop eats part of the first move, so assert direction+rough
      // magnitude, not exact deltas.
      expect(cam().yaw, greaterThan(0.2));
      expect(cam().pitch, greaterThan(0.05));
    });

    testWidgets('W key walks forward along yaw, clamped to ground height',
        (tester) async {
      var emitted = false;
      final cam = await pumpWalk(tester,
          camera: WalkCamera(position: Vector3(0, 1.45, 0)), // yaw 0 -> +Z
          walkmap: flatGround,
          onEmit: () => emitted = true);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      // Pump many small frames so the ticker integrates real dts.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(emitted, isTrue);
      expect(cam().position.z, greaterThan(0.5)); // ~1.4 after ~0.48 s at 3 u/s
      expect(cam().position.x.abs(), lessThan(1e-6));
      expect(cam().position.y, closeTo(0 + kWalkEyeHeight, 1e-6));
    });

    testWidgets('movement off the walkmap edge is blocked', (tester) async {
      final cam = await pumpWalk(tester,
          camera: WalkCamera(position: Vector3(0, 1.45, 19.9)), // near +Z edge
          walkmap: flatGround);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(cam().position.z, lessThanOrEqualTo(20.0 + 1e-6));
    });

    testWidgets('inputLocked ignores drags and keys', (tester) async {
      var emitted = false;
      final cam = await pumpWalk(tester,
          camera: WalkCamera(position: Vector3(0, 1.45, 0)),
          walkmap: flatGround,
          inputLocked: true,
          onEmit: () => emitted = true);
      await tester.drag(find.byType(TourView), const Offset(60, 0),
          warnIfMissed: false);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(emitted, isFalse);
      expect(cam().position.z, 0);
    });
  });
}
