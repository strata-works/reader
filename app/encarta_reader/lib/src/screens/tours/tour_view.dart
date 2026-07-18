// Task 7: the flutter_scene 3-D viewport for an Encarta 3-D tour, with orbit
// gestures. Reuses the Task-1 spike's proven wiring (see
// lib/src/screens/tours/spike/tour_spike_app.dart and
// docs/superpowers/plans/spike-notes-flutter_scene.md):
//
//   * flutter_scene 0.16.0 has NO SceneView widget, so we own the render loop:
//     a CustomPainter calls Scene.render(camera, canvas, viewport:) each frame,
//     driven by a Ticker. Scene.initializeStaticResources() is awaited once.
//   * The triangle-mesh building loads via Node.fromGlbAsset(glbAsset).
//   * flutter_scene drops POINTS primitives, so the statue point cloud is read
//     from pointsAsset ([u32 count][count*3 f32 positions, planar]
//     [count*3 f32 colors, planar], little-endian) and expanded into
//     camera-facing billboard quads (6 verts/point) via
//     MeshGeometry.fromArrays + UnlitMaterial with doubleSided = true.
//
// New in Task 7 (beyond the fixed-camera spike):
//   1. Gesture -> OrbitCamera mapping (drag = azimuth/elevation, pinch/scroll =
//      distance) with clamps, calling onCameraChanged + setState.
//   2. Camera-driven billboard RE-ORIENTATION: the spike built billboards for a
//      fixed camera; here we rebuild the point MeshGeometry from the current
//      camera's right/up basis whenever the camera changes materially, so the
//      splats never go edge-on/invisible while orbiting. (~50k pts is a few ms
//      to rebuild on the CPU, and we only do it on camera-change, not per
//      frame.) A vertex-shader / instanced-billboard approach is the future
//      optimization and is OUT OF SCOPE for this task.
//   3. A graceful guard around ALL async GL/asset loading: if the glb/points
//      are absent (they are gitignored and regenerated locally via
//      tool/materialize_tour_assets.py), the widget still BUILDS a placeholder
//      and still HANDLES gestures, so widget tests run without the assets.
//
// OrbitCamera (package:encarta_3dtours) uses vector_math_64; flutter_scene uses
// vector_math (32-bit). We bridge by copying .x/.y/.z doubles at the boundary.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

/// Max absolute elevation, ~85 degrees, so the orbit never flips over the pole.
const double _kMaxElevation = 1.48;

/// Sensitivity: screen pixels dragged -> radians of orbit rotation.
const double _kRotSpeed = 0.01;

/// A flutter_scene 3-D viewport that renders a tour's glb building mesh plus its
/// statue point cloud (as billboard quads), orbited by drag / pinch / scroll.
class TourView extends StatefulWidget {
  final String glbAsset;
  final String pointsAsset;
  final OrbitCamera camera;
  final void Function(OrbitCamera) onCameraChanged;

  const TourView({
    super.key,
    required this.glbAsset,
    required this.pointsAsset,
    required this.camera,
    required this.onCameraChanged,
  });

  @override
  State<TourView> createState() => _TourViewState();
}

class _TourViewState extends State<TourView> {
  // Created lazily inside _load(): the Scene() constructor touches the Flutter
  // GPU context, which is unavailable in headless/test environments and would
  // throw at field-init time — preventing the widget from ever mounting. We
  // guard it so the widget always builds and keeps handling gestures.
  Scene? _scene;
  Ticker? _ticker;

  // GL readiness. Until true, we render a placeholder (and still take gestures).
  bool _ready = false;

  // Why the renderer failed to start, if it did. Shown in the placeholder so a
  // GPU-init failure (e.g. Flutter GPU not enabled in the platform manifest)
  // reads as an actionable error instead of an eternal "Loading 3-D tour…".
  String? _loadError;

  // Raw point data (positions + colors), loaded once; billboards are rebuilt
  // from this against the current camera basis whenever the camera changes.
  Float32List? _pointPos; // planar xyz, count*3
  Float32List? _pointCol; // planar rgb, count*3
  int _pointCount = 0;
  Node? _pointsNode;

  // Distance clamps derived from the initial camera so framing stays sane
  // across tours of different scales.
  late double _minDistance;
  late double _maxDistance;

  // Gesture scratch state.
  Offset _lastFocalPoint = Offset.zero;
  double _scaleStartDistance = 0;

  // The camera basis last used to build the billboards; lets us skip rebuilds
  // when the orbit has not moved materially.
  vm.Vector3? _lastBillboardForward;

  @override
  void initState() {
    super.initState();
    final d = widget.camera.distance;
    _minDistance = (d * 0.1).clamp(0.01, d);
    _maxDistance = d * 20;
    _load();
    // Repaint every frame so Scene.render runs continuously (0.16.0 has no
    // SceneView widget to own the ticker). Cheap when nothing changes.
    _ticker = Ticker((_) {
      if (mounted && _ready) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();
      // Constructing the Scene touches the Flutter GPU context, so it lives
      // here inside the guard rather than a field initializer.
      final scene = _scene ??= Scene();

      // (1) Triangle-mesh building via runtime GLB import. Guarded: a missing
      // or unreadable glb must not crash the widget (assets are gitignored).
      try {
        final meshNode = await Node.fromGlbAsset(widget.glbAsset);
        scene.add(meshNode);
      } catch (_) {
        // No building mesh; points (if any) still render.
      }

      // (2) Statue point cloud -> billboard quads. Guarded independently.
      try {
        await _loadPointData();
        _rebuildBillboards(widget.camera, force: true);
      } catch (_) {
        // No points; the building mesh (if any) still renders.
      }

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      // Static-resource init fails in headless/test environments (expected)
      // but also when Impeller/Flutter GPU is not enabled for the app (a real
      // configuration bug — see FLTEnableFlutterGPU in the platform
      // Info.plists). Stay in placeholder mode and keep handling gestures,
      // but surface the reason instead of swallowing it.
      _loadError = '$e';
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadPointData() async {
    final data = await rootBundle.load(widget.pointsAsset);
    final bytes = data.buffer.asByteData();
    final count = bytes.getUint32(0, Endian.little);
    const posOffset = 4;
    final colOffset = posOffset + count * 3 * 4;

    final pos = Float32List(count * 3);
    final col = Float32List(count * 3);
    for (int i = 0; i < count * 3; i++) {
      pos[i] = bytes.getFloat32(posOffset + i * 4, Endian.little);
      col[i] = bytes.getFloat32(colOffset + i * 4, Endian.little);
    }
    _pointPos = pos;
    _pointCol = col;
    _pointCount = count;
  }

  // Expands each point into a camera-facing quad (2 tris, 6 non-indexed verts)
  // using the given camera's right/up basis. Rebuilds the flutter_scene points
  // node in place. Skips work when the orbit has not rotated materially since
  // the last build (unless [force]).
  void _rebuildBillboards(OrbitCamera cam, {bool force = false}) {
    final scene = _scene;
    final pos = _pointPos, col = _pointCol;
    if (scene == null || pos == null || col == null || _pointCount == 0) return;

    final eye = _toVm(cam.eyePosition());
    final target = _toVm(cam.target);
    final forward = (target - eye).normalized();

    if (!force && _lastBillboardForward != null) {
      // Rebuild only when the view direction moved > ~0.5 degrees.
      if (forward.dot(_lastBillboardForward!) > 0.99996) return;
    }

    final worldUp = vm.Vector3(0, 1, 0);
    var right = forward.cross(worldUp);
    if (right.length2 < 1e-9) {
      // Looking straight up/down: pick an arbitrary stable right vector.
      right = vm.Vector3(1, 0, 0);
    }
    right = right.normalized();
    final up = right.cross(forward).normalized();

    // Quad half-size scales gently with distance so splats stay visible when
    // zoomed out but don't swallow the scene when zoomed in.
    final half = (cam.distance * 0.012).clamp(0.4, 6.0);
    final ru = right * half;
    final uu = up * half;

    final n = _pointCount;
    final vpos = Float32List(n * 6 * 3);
    final vcol = Float32List(n * 6 * 4);
    for (int i = 0; i < n; i++) {
      final px = pos[i * 3 + 0], py = pos[i * 3 + 1], pz = pos[i * 3 + 2];
      final cr = col[i * 3 + 0], cg = col[i * 3 + 1], cb = col[i * 3 + 2];
      final c = vm.Vector3(px, py, pz);
      final v0 = c - ru - uu;
      final v1 = c + ru - uu;
      final v2 = c + ru + uu;
      final v3 = c - ru + uu;
      final tri = [v0, v1, v2, v0, v2, v3];
      final base = i * 6;
      for (int k = 0; k < 6; k++) {
        final v = tri[k];
        vpos[(base + k) * 3 + 0] = v.x;
        vpos[(base + k) * 3 + 1] = v.y;
        vpos[(base + k) * 3 + 2] = v.z;
        vcol[(base + k) * 4 + 0] = cr;
        vcol[(base + k) * 4 + 1] = cg;
        vcol[(base + k) * 4 + 2] = cb;
        vcol[(base + k) * 4 + 3] = 1.0;
      }
    }

    final geometry = MeshGeometry.fromArrays(positions: vpos, colors: vcol);
    final material = UnlitMaterial() // vertexColorWeight defaults to 1.0
      ..doubleSided = true; // REQUIRED: single quads, else back-face-culled.
    final mesh = Mesh(geometry, material);

    final old = _pointsNode;
    if (old != null) scene.remove(old);
    final node = Node(name: 'statue_points', mesh: mesh);
    scene.add(node);
    _pointsNode = node;
    _lastBillboardForward = forward;
  }

  static vm.Vector3 _toVm(vm64.Vector3 v) => vm.Vector3(v.x, v.y, v.z);

  // Builds the flutter_scene camera from the current OrbitCamera each frame.
  PerspectiveCamera _sceneCamera() {
    final c = widget.camera;
    return PerspectiveCamera(
      position: _toVm(c.eyePosition()),
      target: _toVm(c.target),
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: c.fovYRadians,
      fovNear: c.near,
      fovFar: c.far,
    );
  }

  // Produce a mutated COPY of the camera (OrbitCamera has no copyWith; fields
  // are public + mutable, so we construct a fresh instance copying all fields).
  OrbitCamera _copyCamera({
    double? azimuth,
    double? elevation,
    double? distance,
  }) {
    final c = widget.camera;
    return OrbitCamera(
      target: c.target,
      azimuth: azimuth ?? c.azimuth,
      elevation: elevation ?? c.elevation,
      distance: distance ?? c.distance,
      fovYRadians: c.fovYRadians,
      near: c.near,
      far: c.far,
    );
  }

  void _emit(OrbitCamera next) {
    widget.onCameraChanged(next);
    // Re-orient billboards toward the new view (throttled inside).
    _rebuildBillboards(next);
    if (mounted) setState(() {});
  }

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocalPoint = d.focalPoint;
    _scaleStartDistance = widget.camera.distance;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final c = widget.camera;

    // Rotation from focal-point delta.
    final delta = d.focalPoint - _lastFocalPoint;
    _lastFocalPoint = d.focalPoint;
    final azimuth = c.azimuth + delta.dx * _kRotSpeed; // +dx -> +azimuth
    final elevation = (c.elevation - delta.dy * _kRotSpeed) // -dy -> +elevation
        .clamp(-_kMaxElevation, _kMaxElevation);

    // Pinch -> distance (divide by scale so pinch-out zooms in).
    var distance = c.distance;
    if (d.scale != 1.0 && d.scale > 0) {
      distance = (_scaleStartDistance / d.scale)
          .clamp(_minDistance, _maxDistance);
    }

    _emit(_copyCamera(
      azimuth: azimuth,
      elevation: elevation,
      distance: distance,
    ));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final c = widget.camera;
      // Scroll down (positive dy) zooms out; scale ~1.0015 per pixel.
      final factor = math.pow(1.0015, event.scrollDelta.dy).toDouble();
      final distance =
          (c.distance * factor).clamp(_minDistance, _maxDistance);
      _emit(_copyCamera(distance: distance));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: (_ready && _scene != null)
            ? CustomPaint(
                painter: _ScenePainter(_scene!, _sceneCamera()),
                size: Size.infinite,
              )
            : ColoredBox(
                color: const Color(0xFF10131A),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError == null
                          ? 'Loading 3-D tour…'
                          : 'The 3-D renderer could not start:\n$_loadError',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// Renders the scene each frame. flutter_scene 0.16.0 has no SceneView widget,
// so we own the CustomPainter that calls Scene.render (spike-established
// pattern; migrate to SceneView on Flutter >= 3.44 / flutter_scene >= 0.17).
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.camera);

  final Scene scene;
  final Camera camera;

  @override
  void paint(Canvas canvas, Size size) {
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}
