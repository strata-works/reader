import 'dart:math' as math;

import 'walk_camera.dart';

/// Shortest-arc angle interpolation (radians): 350deg -> 10deg passes
/// through 0, never the long way around.
double lerpAngle(double a, double b, double t) {
  var d = (b - a) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return a + d * t;
}

/// The glide-travel pose at progress [t] in [0, 1]. Pure and linear: the
/// caller applies its easing curve to t before calling (the reader uses a
/// 1200 ms ease-in-out). Returns a fresh camera; inputs are not mutated.
WalkCamera glideBetween(WalkCamera from, WalkCamera to, double t) {
  final cam = from.copy();
  cam.position = from.position + (to.position - from.position) * t;
  cam.yaw = lerpAngle(from.yaw, to.yaw, t);
  cam.pitch = from.pitch + (to.pitch - from.pitch) * t;
  return cam;
}
