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
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, rootBundle;
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
  final TourCamera camera;
  final void Function(OrbitCamera)? onOrbitChanged;
  final void Function(WalkCamera)? onWalkChanged;
  final Walkmap? walkmap;
  final bool showPoints;
  final bool inputLocked;

  const TourView({
    super.key,
    required this.glbAsset,
    required this.pointsAsset,
    required this.camera,
    this.onOrbitChanged,
    this.onWalkChanged,
    this.walkmap,
    this.showPoints = true,
    this.inputLocked = false,
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

  OrbitCamera? get _asOrbit =>
      widget.camera is OrbitCamera ? widget.camera as OrbitCamera : null;
  WalkCamera? get _asWalk =>
      widget.camera is WalkCamera ? widget.camera as WalkCamera : null;
  OrbitCamera get _orbit => _asOrbit!;

  // Held movement keys, integrated each ticker tick in walk mode.
  final Set<LogicalKeyboardKey> _keysDown = {};
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    final cam = widget.camera;
    if (cam is OrbitCamera) {
      final d = cam.distance;
      _minDistance = (d * 0.1).clamp(0.01, d);
      _maxDistance = d * 20;
    } else {
      _minDistance = 0.01;
      _maxDistance = double.infinity;
    }
    _load();
    // Repaint every frame so Scene.render runs continuously (0.16.0 has no
    // SceneView widget to own the ticker). Cheap when nothing changes. Also
    // integrates any held walk-movement keys against the real elapsed dt.
    _ticker = Ticker((elapsed) {
      final dt = _lastTick == null
          ? 0.0
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      _integrateWalkKeys(dt);
      if (mounted && _ready) setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(covariant TourView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Defense-in-depth for the stuck-key bug: entering a lock (e.g. glide
    // travel starting) drops all currently-held keys, so nothing can be
    // replayed once the lock lifts even if a KeyUp was somehow missed.
    if (widget.inputLocked && !oldWidget.inputLocked) {
      _keysDown.clear();
    }
    // showPoints toggling after mount (overview<->walk): the state object
    // survives the toggle, so without this the billboards would either stay
    // in the scene during walk mode or never load at all if the tour
    // started in walk mode.
    if (widget.showPoints != oldWidget.showPoints) {
      if (!widget.showPoints) {
        if (_pointsNode != null) {
          _scene?.remove(_pointsNode!);
          _pointsNode = null;
        }
        // Cached point data (_pointPos/_pointCol) is deliberately kept so a
        // later re-add doesn't have to reload the asset; reset the
        // last-built-for basis so that re-add always rebuilds.
        _lastBillboardForward = null;
      } else if (_pointPos != null && _pointCol != null) {
        _rebuildBillboards(widget.camera, force: true);
      } else if (_scene != null) {
        _ensurePoints();
      }
    }
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
      // Skipped entirely when showPoints is false (walk mode hides statue
      // billboards); didUpdateWidget calls _ensurePoints() itself if
      // showPoints later flips true (e.g. a tour that starts in walk mode).
      if (widget.showPoints) {
        await _ensurePoints();
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

  // Loads the point cloud (if not already cached in _pointPos/_pointCol) and
  // rebuilds the billboards against the current camera. Shared by _load()
  // (initial mount, when showPoints starts true) and didUpdateWidget
  // (showPoints flips true after mount — e.g. toggling from walk back to
  // overview, or a tour that started in walk mode and never loaded points)
  // so both paths share one guarded load-then-rebuild sequence. Guarded
  // independently of the mesh load: a missing/unreadable points asset must
  // not crash the widget.
  Future<void> _ensurePoints() async {
    try {
      if (_pointPos == null || _pointCol == null) {
        await _loadPointData();
      }
      _rebuildBillboards(widget.camera, force: true);
    } catch (_) {
      // No points; the building mesh (if any) still renders.
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
  void _rebuildBillboards(TourCamera cam, {bool force = false}) {
    final scene = _scene;
    final pos = _pointPos, col = _pointCol;
    if (scene == null || pos == null || col == null || _pointCount == 0) return;

    final vm.Vector3 eye, target;
    if (cam is OrbitCamera) {
      eye = _toVm(cam.eyePosition());
      target = _toVm(cam.target);
    } else if (cam is WalkCamera) {
      eye = _toVm(cam.position);
      target = _toVm(cam.position + cam.forward());
    } else {
      return;
    }
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
    // zoomed out but don't swallow the scene when zoomed in; walk mode (a
    // fixed-scale first-person view) uses a fixed small splat instead.
    final half =
        cam is OrbitCamera ? (cam.distance * 0.012).clamp(0.4, 6.0) : 0.4;
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

  // Builds the flutter_scene camera from the current TourCamera each frame,
  // handling both orbit and walk modes.
  PerspectiveCamera _sceneCamera() {
    final walk = _asWalk;
    if (walk != null) {
      final target = walk.position + walk.forward();
      return PerspectiveCamera(
        position: _toVm(walk.position),
        target: _toVm(target),
        up: vm.Vector3(0, 1, 0),
        fovRadiansY: walk.fovYRadians,
        fovNear: walk.near,
        fovFar: walk.far,
      );
    }
    final c = _orbit;
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
    final c = _orbit;
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
    widget.onOrbitChanged?.call(next);
    // Re-orient billboards toward the new view (throttled inside).
    _rebuildBillboards(next);
    if (mounted) setState(() {});
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_asOrbit == null || widget.inputLocked) return;
    _lastFocalPoint = d.focalPoint;
    _scaleStartDistance = _orbit.distance;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_asOrbit == null || widget.inputLocked) return;
    final c = _orbit;

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
    if (_asOrbit == null || widget.inputLocked) return;
    if (event is PointerScrollEvent) {
      final c = _orbit;
      // Scroll down (positive dy) zooms out; scale ~1.0015 per pixel.
      final factor = math.pow(1.0015, event.scrollDelta.dy).toDouble();
      final distance =
          (c.distance * factor).clamp(_minDistance, _maxDistance);
      _emit(_copyCamera(distance: distance));
    }
  }

  /// Walk speed in world units/second; Shift runs at 2.5x.
  static const double _kWalkSpeed = 3.0;
  static const double _kRunFactor = 2.5;
  static const double _kLookSpeed = 0.005;

  bool get _walkInputActive =>
      _asWalk != null && !widget.inputLocked && widget.onWalkChanged != null;

  void _integrateWalkKeys(double dt) {
    final cam = _asWalk;
    if (!_walkInputActive || cam == null || dt <= 0 || _keysDown.isEmpty) {
      return;
    }
    var dz = 0.0, dx = 0.0; // forward / strafe in the yaw plane
    if (_down(LogicalKeyboardKey.keyW) || _down(LogicalKeyboardKey.arrowUp)) {
      dz += 1;
    }
    if (_down(LogicalKeyboardKey.keyS) || _down(LogicalKeyboardKey.arrowDown)) {
      dz -= 1;
    }
    if (_down(LogicalKeyboardKey.keyD) ||
        _down(LogicalKeyboardKey.arrowRight)) {
      dx += 1;
    }
    if (_down(LogicalKeyboardKey.keyA) || _down(LogicalKeyboardKey.arrowLeft)) {
      dx -= 1;
    }
    if (dz == 0 && dx == 0) return;

    final run = _down(LogicalKeyboardKey.shiftLeft) ||
        _down(LogicalKeyboardKey.shiftRight);
    // Clamp dt to 0.1 s: caps a post-suspend/hitch catch-up step to ~0.3
    // units (run speed ~0.75) so a single huge dt can't tunnel through
    // walkmap holes/walls.
    final dtClamped = math.min(dt, 0.1);
    final speed = _kWalkSpeed * (run ? _kRunFactor : 1.0) * dtClamped;

    // Yaw-plane basis (pitch does not affect ground movement).
    final fwd = vm64.Vector3(math.sin(cam.yaw), 0, math.cos(cam.yaw));
    final right = vm64.Vector3(fwd.z, 0, -fwd.x) * -1.0; // fwd x up
    final step = (fwd * dz + right * dx).normalized() * speed;

    final next = _clampToWalkmap(cam.position, step);
    if (next == null) return;
    final out = cam.copy()..position = next;
    widget.onWalkChanged!(out);
  }

  bool _down(LogicalKeyboardKey k) => _keysDown.contains(k);

  /// Applies [step] to [from], keeping the eye on the walkmap: full step,
  /// else X-only, else Z-only (wall-slide), else null (blocked). Off-map is
  /// also blocked when no walkmap exists (walk mode is only offered with
  /// one, but stay safe).
  vm64.Vector3? _clampToWalkmap(vm64.Vector3 from, vm64.Vector3 step) {
    final wm = widget.walkmap;
    if (wm == null) return null;
    for (final s in [
      step,
      vm64.Vector3(step.x, 0, 0),
      vm64.Vector3(0, 0, step.z),
    ]) {
      if (s.length2 == 0) continue;
      final nx = from.x + s.x, nz = from.z + s.z;
      final h = wm.groundHeightAt(nx, nz);
      if (h != null) return vm64.Vector3(nx, h + kWalkEyeHeight, nz);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = (_ready && _scene != null)
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          );

    if (_asWalk != null) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // KeyUp must always be processed, even while input is locked
          // (e.g. mid-glide travel): otherwise a key released during the
          // lock stays stuck in _keysDown and the camera walks by itself
          // once the lock lifts. Only KeyDown additions (and returning
          // "handled") are gated behind _walkInputActive.
          if (event is KeyUpEvent) _keysDown.remove(event.logicalKey);
          if (!_walkInputActive) return KeyEventResult.ignored;
          if (event is KeyDownEvent) _keysDown.add(event.logicalKey);
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanUpdate: (d) {
            final cam = _asWalk;
            if (!_walkInputActive || cam == null) return;
            final out = cam.copy()
              ..look(d.delta.dx * _kLookSpeed, -d.delta.dy * _kLookSpeed);
            widget.onWalkChanged!(out);
          },
          child: content,
        ),
      );
    }

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: content,
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
