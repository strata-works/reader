import 'dart:math' as math;

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('yaw 0, pitch 0 looks along +Z (matches OrbitCamera azimuth 0)', () {
    final cam = WalkCamera(position: Vector3.zero());
    final f = cam.forward();
    expect(f.x, closeTo(0, 1e-9));
    expect(f.y, closeTo(0, 1e-9));
    expect(f.z, closeTo(1, 1e-9));
  });

  test('a point straight ahead projects to screen center', () {
    final cam = WalkCamera(position: Vector3(2, 1.45, -3), yaw: 0.7, pitch: 0.1);
    final ahead = cam.position + cam.forward() * 10.0;
    final vp = cam.viewProjectionMatrix(800 / 600);
    final s = projectToScreen(ahead, vp, 800, 600);
    expect(s, isNotNull);
    expect(s!.x, closeTo(400, 1.0));
    expect(s.y, closeTo(300, 1.0));
  });

  test('look() accumulates yaw and clamps pitch to kMaxWalkPitch', () {
    final cam = WalkCamera(position: Vector3.zero());
    cam.look(0.5, 99.0);
    expect(cam.yaw, closeTo(0.5, 1e-9));
    expect(cam.pitch, closeTo(kMaxWalkPitch, 1e-9));
    cam.look(0.0, -99.0);
    expect(cam.pitch, closeTo(-kMaxWalkPitch, 1e-9));
  });

  test('fromHotspot maps anchor position and degree angle to yaw', () {
    final h = Hotspot(
      id: 'h1',
      text: 'Parthenon',
      anchor: Vector3(0.42, 1.44, 3.98),
      angle: 183.64,
    );
    final cam = WalkCamera.fromHotspot(h);
    expect(cam.position.x, closeTo(0.42, 1e-9));
    expect(cam.position.y, closeTo(1.44, 1e-9));
    expect(cam.position.z, closeTo(3.98, 1e-9));
    expect(cam.yaw, closeTo(183.64 * math.pi / 180.0, 1e-9));
    expect(cam.pitch, 0);
  });

  test('OrbitCamera and WalkCamera are both TourCameras', () {
    final TourCamera a = OrbitCamera(target: Vector3.zero());
    final TourCamera b = WalkCamera(position: Vector3.zero());
    expect(a.viewProjectionMatrix(1.0), isA<Matrix4>());
    expect(b.viewProjectionMatrix(1.0), isA<Matrix4>());
  });

  test('copy() is deep for position and preserves all fields', () {
    final cam = WalkCamera(position: Vector3(1, 2, 3), yaw: 0.4, pitch: 0.2);
    final c = cam.copy();
    c.position.x = 99;
    c.look(1.0, 0.0);
    expect(cam.position.x, 1);
    expect(cam.yaw, closeTo(0.4, 1e-9));
  });
}
