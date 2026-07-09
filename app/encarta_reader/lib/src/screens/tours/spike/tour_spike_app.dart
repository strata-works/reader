// TASK 1 SPIKE (throwaway, committed) — gating decision for the Encarta 3-D
// tour renderer. Answers: can flutter_scene (Impeller) render our Acropolis
// triangle mesh AND the statue point clouds on macOS?
//
// Findings baked into this file:
//   * flutter_scene 0.16.0 is the newest release that both resolves AND
//     compiles on this box's Flutter 3.42 beta. 0.18.x needs Flutter >= 3.44;
//     0.17.0 resolves but fails to COMPILE because it calls a flutter_gpu
//     texture-compression API (TextureCompressionFamily /
//     supportsTextureCompression / bc1RGBAUNormInt) that does not exist in the
//     flutter_gpu bundled with this SDK. 0.16.0 predates that API.
//   * 0.16.0 has no SceneView widget (that arrived in 0.17), so we drive
//     rendering ourselves: a CustomPainter calls Scene.render(camera, canvas)
//     each frame, repainted by a Ticker.
//   * flutter_scene has NO native POINTS support: both its offline importer
//     (`dart run flutter_scene:import`) and runtime `Node.fromGlbAsset` skip
//     every primitive whose mode != 4 (TRIANGLES). Source, mesh_data types:
//     "4 = TRIANGLES (the only mode flutter_scene supports)". So the 6 statue
//     POINTS primitives are dropped by the mesh loader.
//   * FALLBACK for points: we render them ourselves as camera-facing billboard
//     quads (2 tris/point) via MeshGeometry.fromArrays with per-vertex COLOR_0
//     and an UnlitMaterial (vertexColorWeight defaults to 1.0). Decimated to
//     ~50k points (stride 10 over 498k) for the spike.
//
// Run:  flutter run -d macos --enable-impeller \
//         -t lib/src/screens/tours/spike/tour_spike_app.dart
//
// The camera setup here (fixed PerspectiveCamera framing the scene AABB) is the
// reference Tasks 4/7 should mirror.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

// Scene AABB (from acr.gltf accessor min/max, all node transforms identity):
//   center ≈ (-0.8, 122.55, -56.6), size ≈ (124.8, 256.5, 227.6).
final vm.Vector3 kSceneCenter = vm.Vector3(-0.8, 122.55, -56.6);
const double kSceneRadius = 170.0; // ~half the largest extent, with headroom.

// Statue point-cloud centroid + bbox (from acr.bin COLOR_0/POSITION accessors).
final vm.Vector3 kPointsCentroid = vm.Vector3(5.8, 91.2, -15.6);
const double kPointsRadius = 140.0;

// When true, render ONLY the colored statue billboards (no building mesh),
// framed tightly on the point cloud. This isolates the point path so the
// per-vertex COLOR_0 (stone browns/tans/greys) is unmistakably visible.
final bool kPointsOnly =
    Platform.environment['SPIKE_POINTS_ONLY'] == '1';

// Fixed camera. Kept as a top-level so later tasks can lift it verbatim.
PerspectiveCamera buildTourCamera() {
  final vm.Vector3 target;
  final double radius;
  if (kPointsOnly) {
    target = kPointsCentroid;
    radius = kPointsRadius;
  } else {
    // Look a little below the AABB center (the Parthenon body sits low; the
    // tall AABB is inflated by spires/statues).
    target = kSceneCenter + vm.Vector3(0, -40, 0);
    radius = kSceneRadius;
  }
  final eye = target +
      vm.Vector3(radius * 0.9, radius * 0.55, radius * 1.15);
  return PerspectiveCamera(
    position: eye,
    target: target,
    up: vm.Vector3(0, 1, 0),
    fovRadiansY: 55 * (math.pi / 180.0),
    fovNear: 1.0,
    fovFar: 4000.0,
  );
}

void main() {
  runApp(const TourSpikeApp());
}

class TourSpikeApp extends StatelessWidget {
  const TourSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Encarta 3-D Tour Spike',
      debugShowCheckedModeBanner: false,
      home: const _SpikeHome(),
    );
  }
}

class _SpikeHome extends StatefulWidget {
  const _SpikeHome();

  @override
  State<_SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<_SpikeHome> {
  final Scene _scene = Scene();
  final PerspectiveCamera _camera = buildTourCamera();
  final GlobalKey _repaintKey = GlobalKey();
  Ticker? _ticker;
  bool _ready = false;
  String _status = 'loading…';
  int _pointCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Drive a repaint every frame so Scene.render runs continuously (0.16.0
    // has no SceneView widget to own the ticker).
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

      // (1) Triangle-mesh Parthenon via runtime GLB import. flutter_scene
      // keeps only mode-4 primitives, so this yields the building geometry
      // (POINTS statues are silently dropped — handled below).
      if (!kPointsOnly) {
        final meshNode = await Node.fromGlbAsset('assets/spike/acr.glb');
        _scene.add(meshNode);
        setState(() => _status = 'mesh loaded; building point billboards…');
      }

      // (2) Statue point clouds: our own billboard-quad geometry.
      final pointsNode = await _buildPointBillboards();
      _scene.add(pointsNode);

      setState(() {
        _ready = true;
        _status = 'rendered: mesh + $_pointCount statue points (billboards)';
      });

      // Durable evidence: capture the RepaintBoundary to a PNG after a few
      // frames have drawn. Set SPIKE_CAPTURE=<path> to enable.
      final capturePath = Platform.environment['SPIKE_CAPTURE'];
      if (capturePath != null) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await _capture(capturePath);
      }
    } catch (e, st) {
      setState(() => _status = 'ERROR: $e\n$st');
    }
  }

  Future<void> _capture(String path) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        File(path).writeAsBytesSync(bytes.buffer.asUint8List());
        debugPrint('SPIKE_CAPTURE wrote $path');
      }
    } catch (e) {
      debugPrint('SPIKE_CAPTURE failed: $e');
    }
  }

  // Loads assets/spike/acr_points.bin (u32 count; then N*vec3 pos; N*vec3 rgb)
  // and expands each point into a camera-facing quad (2 triangles). Billboards
  // are oriented on the CPU using the fixed camera's right/up basis.
  Future<Node> _buildPointBillboards() async {
    final data = await rootBundle.load('assets/spike/acr_points.bin');
    final bytes = data.buffer.asByteData();
    final count = bytes.getUint32(0, Endian.little);
    _pointCount = count;

    final posOffset = 4;
    final colOffset = posOffset + count * 3 * 4;

    // Camera basis for billboard orientation (fixed camera).
    final forward = (_camera.target - _camera.position).normalized();
    final worldUp = vm.Vector3(0, 1, 0);
    final right = forward.cross(worldUp).normalized();
    final up = right.cross(forward).normalized();

    const double half = 1.6; // quad half-size in world units (chunky splats).
    final ru = right * half;
    final uu = up * half;

    // Non-indexed triangle list: 6 verts/point (2 tris), each carrying the
    // point's COLOR_0. (An indexed quad would need 4 verts + u16 indices, but
    // 50k*4 verts overflows the u16 index space, so we expand instead.)
    final vpos = Float32List(count * 6 * 3);
    final vcol = Float32List(count * 6 * 4);

    for (int i = 0; i < count; i++) {
      final px = bytes.getFloat32(posOffset + (i * 3 + 0) * 4, Endian.little);
      final py = bytes.getFloat32(posOffset + (i * 3 + 1) * 4, Endian.little);
      final pz = bytes.getFloat32(posOffset + (i * 3 + 2) * 4, Endian.little);
      final cr = bytes.getFloat32(colOffset + (i * 3 + 0) * 4, Endian.little);
      final cg = bytes.getFloat32(colOffset + (i * 3 + 1) * 4, Endian.little);
      final cb = bytes.getFloat32(colOffset + (i * 3 + 2) * 4, Endian.little);

      // Quad corners: c-ru-uu, c+ru-uu, c+ru+uu, c-ru+uu
      final c = vm.Vector3(px, py, pz);
      final v0 = c - ru - uu;
      final v1 = c + ru - uu;
      final v2 = c + ru + uu;
      final v3 = c - ru + uu;
      // Two triangles: (v0,v1,v2) (v0,v2,v3)
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
    final geometry = MeshGeometry.fromArrays(
      positions: vpos,
      colors: vcol,
    );
    final material = UnlitMaterial() // vertexColorWeight defaults to 1.0
      // Billboards are single quads; disable back-face culling so they show
      // regardless of the camera-relative winding of the generated tris.
      ..doubleSided = true;
    final mesh = Mesh(geometry, material);
    return Node(name: 'statue_points', mesh: mesh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      body: Stack(
        children: [
          if (_ready)
            Positioned.fill(
              child: RepaintBoundary(
                key: _repaintKey,
                child: CustomPaint(
                  painter: _ScenePainter(_scene, _camera),
                  size: Size.infinite,
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Renders the scene each frame. flutter_scene 0.16.0 has no SceneView widget,
// so the app owns the CustomPainter that calls Scene.render. This is the
// pattern Tasks 7-9 would use on this SDK (or SceneView once on Flutter 3.44+).
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.camera);

  final Scene scene;
  final Camera camera;

  @override
  void paint(Canvas canvas, Size size) {
    scene.render(
      camera,
      canvas,
      viewport: Offset.zero & size,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}
