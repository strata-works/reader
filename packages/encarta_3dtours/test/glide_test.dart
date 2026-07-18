import 'dart:math' as math;

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('lerpAngle takes the shortest arc across the wrap', () {
    final a = 350 * math.pi / 180, b = 10 * math.pi / 180;
    // Midpoint should pass through 0 (360), not 180.
    final mid = lerpAngle(a, b, 0.5);
    expect(math.sin(mid), closeTo(0.0, 1e-9));
    expect(math.cos(mid), closeTo(1.0, 1e-9));
  });

  test('glideBetween lerps position and yaw, endpoints exact', () {
    final from = WalkCamera(position: Vector3(0, 1, 0), yaw: 0.0);
    final to = WalkCamera(position: Vector3(4, 1, 8), yaw: 1.0, pitch: 0.2);
    final mid = glideBetween(from, to, 0.5);
    expect(mid.position.x, closeTo(2, 1e-9));
    expect(mid.position.z, closeTo(4, 1e-9));
    expect(mid.yaw, closeTo(0.5, 1e-9));
    expect(mid.pitch, closeTo(0.1, 1e-9));
    expect(glideBetween(from, to, 0).yaw, closeTo(0.0, 1e-9));
    expect(glideBetween(from, to, 1).position.x, closeTo(4, 1e-9));
  });

  test('glideBetween does not mutate its inputs', () {
    final from = WalkCamera(position: Vector3(0, 1, 0));
    final to = WalkCamera(position: Vector3(4, 1, 8));
    glideBetween(from, to, 0.5).position.x = 99;
    expect(from.position.x, 0);
    expect(to.position.x, 4);
  });
}
