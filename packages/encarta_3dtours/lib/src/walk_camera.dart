import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'camera.dart';
import 'models.dart';

/// Eye height above the walkmap ground, in world units. The corpus' authored
/// hotspot anchors stand at y ~= 1.44, so grounded movement uses the same
/// human-scale height.
const double kWalkEyeHeight = 1.45;

/// Max |pitch|, ~80 degrees, so first-person look never flips over the pole.
const double kMaxWalkPitch = 1.4;

/// A first-person camera: an eye [position] plus a [yaw]/[pitch] view
/// direction. Renderer-agnostic (vector_math_64, no Flutter), like
/// [OrbitCamera] — the two share the [TourCamera] contract so overlays and
/// the scene view can consume either mode's camera.
class WalkCamera implements TourCamera {
  Vector3 position;

  /// Radians around +Y. Yaw 0 looks along +Z and increasing yaw turns toward
  /// +X — the same convention as [OrbitCamera.azimuth]'s eye placement.
  double yaw;

  /// Radians; kept within +-[kMaxWalkPitch] by [look] (direct writes are the
  /// caller's responsibility, e.g. glide interpolation of clamped values).
  double pitch;

  double fovYRadians;
  double near, far;

  WalkCamera({
    required this.position,
    this.yaw = 0,
    this.pitch = 0,
    this.fovYRadians = 55 * math.pi / 180,
    this.near = 0.1,
    this.far = 4000,
  });

  /// An authored viewpoint: the hotspot's ANCHORPOINT position plus its
  /// heading angle (degrees). ANGLE CONVENTION IS PINNED EMPIRICALLY: a
  /// recognizable stop must face its subject in the running app. If the
  /// corpus convention proves mirrored or offset, fix the mapping HERE only
  /// (and update the fromHotspot unit test to match).
  factory WalkCamera.fromHotspot(Hotspot h) => WalkCamera(
        position: Vector3.copy(h.anchor),
        yaw: h.angle * math.pi / 180.0,
      );

  /// Unit view direction for the current yaw/pitch.
  Vector3 forward() {
    final cp = math.cos(pitch);
    return Vector3(cp * math.sin(yaw), math.sin(pitch), cp * math.cos(yaw));
  }

  /// Applies a look delta, clamping pitch so the view can't flip.
  void look(double dyaw, double dpitch) {
    yaw += dyaw;
    pitch = (pitch + dpitch).clamp(-kMaxWalkPitch, kMaxWalkPitch);
  }

  Matrix4 viewMatrix() =>
      makeViewMatrix(position, position + forward(), Vector3(0, 1, 0));

  Matrix4 projectionMatrix(double aspect) =>
      makePerspectiveMatrix(fovYRadians, aspect, near, far);

  @override
  Matrix4 viewProjectionMatrix(double aspect) =>
      (projectionMatrix(aspect) * viewMatrix()) as Matrix4;

  WalkCamera copy() => WalkCamera(
        position: Vector3.copy(position),
        yaw: yaw,
        pitch: pitch,
        fovYRadians: fovYRadians,
        near: near,
        far: far,
      );
}
