import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// A camera that orbits around [target] at a fixed [distance], driven by
/// spherical [azimuth]/[elevation] angles. Renderer-agnostic: produces plain
/// `vector_math` matrices/vectors so it can drive any 3-D backend
/// (flutter_scene, etc.) without this package depending on Flutter.
class OrbitCamera {
  Vector3 target;
  double azimuth; // radians, around +Y
  double elevation; // radians
  double distance;
  double fovYRadians;
  double near, far;

  OrbitCamera({
    required this.target,
    this.azimuth = 0,
    this.elevation = 0,
    this.distance = 5,
    this.fovYRadians = 0.9,
    this.near = 0.05,
    this.far = 5000,
  });

  /// The camera's position in world space.
  Vector3 eyePosition() {
    final ce = math.cos(elevation), se = math.sin(elevation);
    final ca = math.cos(azimuth), sa = math.sin(azimuth);
    final dir = Vector3(ce * sa, se, ce * ca);
    return target + dir * distance;
  }

  /// The view matrix looking from [eyePosition] at [target], +Y up.
  Matrix4 viewMatrix() =>
      makeViewMatrix(eyePosition(), target, Vector3(0, 1, 0));

  /// The perspective projection matrix for the given [aspect] ratio
  /// (width / height).
  Matrix4 projectionMatrix(double aspect) =>
      makePerspectiveMatrix(fovYRadians, aspect, near, far);

  /// Convenience combination of [projectionMatrix] and [viewMatrix].
  ///
  /// `Matrix4.operator*` in `vector_math` returns `dynamic`, so this method
  /// exists to give callers a properly-typed `Matrix4` without every call
  /// site needing an `as Matrix4` cast.
  Matrix4 viewProjectionMatrix(double aspect) =>
      (projectionMatrix(aspect) * viewMatrix()) as Matrix4;
}

/// Projects a world-space point through [viewProj] to pixel coordinates
/// (origin top-left, y-down) on a [width] x [height] screen.
///
/// Returns `null` when the point is behind the camera (clip.w <= 0).
Vector2? projectToScreen(
  Vector3 world,
  Matrix4 viewProj,
  double width,
  double height,
) {
  final clip = viewProj.transform(Vector4(world.x, world.y, world.z, 1.0));
  if (clip.w <= 0) return null; // behind camera
  final ndcX = clip.x / clip.w, ndcY = clip.y / clip.w;
  final px = (ndcX * 0.5 + 0.5) * width;
  final py = (1.0 - (ndcY * 0.5 + 0.5)) * height;
  return Vector2(px, py);
}
