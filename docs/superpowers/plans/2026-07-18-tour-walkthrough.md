# First-Person Tour Walkthrough Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-person walk mode to the Encarta 3-D tour: drag-to-look, WASD movement clamped to the tour's walkmap, glide-travel between the authored hotspot viewpoints, with a stops panel + narration chrome — per `docs/superpowers/specs/2026-07-18-tour-walkthrough-design.md`.

**Architecture:** Camera and ground math live in the pure-Dart `packages/encarta_3dtours` package (`WalkCamera`, `Walkmap`, glide interpolation), unit-tested with `package:test`. The reader's `TourView` accepts a `TourCamera` (new shared base of `OrbitCamera`/`WalkCamera`) and swaps input wiring by camera type. `ToursPage` owns mode state, the stop list, and the glide animation. The walkmap triangles are extracted into a committed sidecar by `tool/materialize_tour_assets.py`.

**Tech Stack:** Flutter 3.42 beta, flutter_scene 0.16 (no SceneView — CustomPainter render loop), vector_math_64 (package) / vector_math (flutter_scene bridge), auto_route, `package:test` + `flutter_test`.

## Global Constraints

- Work in the worktree: `/Users/nexus/projects/experiments/strata/reader/.claude/worktrees/tour-render-fix` (branch `tour-render-fix`). All paths below are relative to that root.
- `packages/encarta_3dtours` must stay pure Dart (`vector_math_64`, no Flutter imports).
- The overview (orbit) behavior must not change: existing `test/tours/` tests must keep passing at every commit.
- flutter_scene uses 32-bit `vector_math`; the package uses `vector_math_64`. Bridge by copying `.x/.y/.z` (existing `_toVm` pattern in `tour_view.dart`).
- Run package tests with `dart test` from `packages/encarta_3dtours/`; reader tests with `flutter test` from `app/encarta_reader/`.
- Eye height constant: `1.45`. Max pitch: `1.4` rad. Walk speed: `3.0` units/s, Shift ×2.5. Glide duration: 1200 ms, ease-in-out.
- Every commit message ends with:
  `Claude-Session: https://claude.ai/code/session_01StY7rtNqCMQNCzcXZQ9ctd`

---

### Task 1: `TourCamera` base + `WalkCamera`

**Files:**
- Create: `packages/encarta_3dtours/lib/src/walk_camera.dart`
- Modify: `packages/encarta_3dtours/lib/src/camera.dart` (make `OrbitCamera` implement `TourCamera`)
- Modify: `packages/encarta_3dtours/lib/encarta_3dtours.dart` (add export)
- Test: `packages/encarta_3dtours/test/walk_camera_test.dart`

**Interfaces:**
- Consumes: `OrbitCamera` (existing), `Hotspot` (existing: `anchor: Vector3`, `angle: double` degrees).
- Produces: `abstract class TourCamera { Matrix4 viewProjectionMatrix(double aspect); }`; `class WalkCamera implements TourCamera` with `position: Vector3`, `yaw`, `pitch`, `fovYRadians`, `near`, `far`, `forward() → Vector3`, `look(double dyaw, double dpitch)`, `copy() → WalkCamera`, `factory WalkCamera.fromHotspot(Hotspot h)`; consts `kWalkEyeHeight = 1.45`, `kMaxWalkPitch = 1.4`.

- [ ] **Step 1: Write the failing test**

`packages/encarta_3dtours/test/walk_camera_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `packages/encarta_3dtours/`): `dart test test/walk_camera_test.dart`
Expected: FAIL — `'WalkCamera' isn't defined` / `'TourCamera' isn't defined`.

- [ ] **Step 3: Implement**

`packages/encarta_3dtours/lib/src/walk_camera.dart`:

```dart
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
```

In `packages/encarta_3dtours/lib/src/camera.dart`, add the base class above `OrbitCamera` and implement it (only these two edits):

```dart
/// Renderer-agnostic contract shared by the tour camera modes ([OrbitCamera]
/// orbit overview, WalkCamera first-person): everything projection consumers
/// (hotspot overlay, scene view) need.
abstract class TourCamera {
  Matrix4 viewProjectionMatrix(double aspect);
}
```

```dart
class OrbitCamera implements TourCamera {
```

(`OrbitCamera.viewProjectionMatrix` already exists and gains `@override`.)

In `packages/encarta_3dtours/lib/encarta_3dtours.dart` add:

```dart
export 'src/walk_camera.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run (from `packages/encarta_3dtours/`): `dart test`
Expected: all pass (new file + existing `camera_test.dart`, `models_test.dart`, `parsers_test.dart`).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_3dtours/lib/src/walk_camera.dart packages/encarta_3dtours/lib/src/camera.dart packages/encarta_3dtours/lib/encarta_3dtours.dart packages/encarta_3dtours/test/walk_camera_test.dart
git commit -m "feat(3dtours): WalkCamera + TourCamera base for first-person mode"
```

---

### Task 2: `Walkmap` ground solver

**Files:**
- Create: `packages/encarta_3dtours/lib/src/walkmap.dart`
- Modify: `packages/encarta_3dtours/lib/encarta_3dtours.dart` (add export)
- Test: `packages/encarta_3dtours/test/walkmap_test.dart`

**Interfaces:**
- Consumes: nothing package-internal (pure bytes/math).
- Produces: `class Walkmap { Walkmap.fromTriangles(List<double> flatXyz); factory Walkmap.fromBytes(ByteData bytes); int get triangleCount; double? groundHeightAt(double x, double z); }`. Byte format (matches Task 4's packer): `u32 triCount` LE, then `triCount * 9` LE f32 (three xyz vertices per triangle).

- [ ] **Step 1: Write the failing test**

`packages/encarta_3dtours/test/walkmap_test.dart`:

```dart
import 'dart:typed_data';

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

ByteData _pack(List<double> flat) {
  final b = BytesBuilder();
  final head = ByteData(4)..setUint32(0, flat.length ~/ 9, Endian.little);
  b.add(head.buffer.asUint8List());
  final f = ByteData(flat.length * 4);
  for (var i = 0; i < flat.length; i++) {
    f.setFloat32(i * 4, flat[i], Endian.little);
  }
  b.add(f.buffer.asUint8List());
  final bytes = b.toBytes();
  return ByteData.sublistView(bytes);
}

void main() {
  // One right triangle in the XZ plane, sloping in y: (0,0,0) (4,0,0) (0,4,4).
  const tri = <double>[0, 0, 0, 4, 0, 0, 0, 4, 4];

  test('point inside a triangle returns barycentric height', () {
    final wm = Walkmap.fromTriangles(tri);
    // At (1, 1): weights put us 1/4 along the z-sloping edge -> y = 1.
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
    // Flat corner region.
    expect(wm.groundHeightAt(2, 0.5), closeTo(0.5, 1e-6));
  });

  test('point outside every triangle returns null', () {
    final wm = Walkmap.fromTriangles(tri);
    expect(wm.groundHeightAt(-1, -1), isNull);
    expect(wm.groundHeightAt(10, 10), isNull);
  });

  test('overlapping triangles: highest ground wins', () {
    final wm = Walkmap.fromTriangles([
      ...tri, // height ~1 at (1,1)
      0, 5, 0, 4, 5, 0, 0, 5, 4, // same footprint, flat at y=5
    ]);
    expect(wm.groundHeightAt(1, 1), closeTo(5.0, 1e-6));
  });

  test('degenerate (zero-area) triangles are skipped, not NaN', () {
    final wm = Walkmap.fromTriangles([0, 9, 0, 0, 9, 0, 0, 9, 0, ...tri]);
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
  });

  test('fromBytes parses the packed sidecar format', () {
    final wm = Walkmap.fromBytes(_pack(tri));
    expect(wm.triangleCount, 1);
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
    expect(wm.groundHeightAt(10, 10), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/walkmap_test.dart`
Expected: FAIL — `'Walkmap' isn't defined`.

- [ ] **Step 3: Implement**

`packages/encarta_3dtours/lib/src/walkmap.dart`:

```dart
import 'dart:typed_data';

/// The tour's walkable-ground surface: a triangle soup queried for ground
/// height under an (x, z) column. Backed by the `.3wm` "walkmap" mesh the
/// original engine loads (`WALKMAP.LOAD(`), extracted into a flat sidecar by
/// tool/materialize_tour_assets.py.
///
/// Byte format: `u32 triCount` (LE), then `triCount * 9` LE f32 — three
/// xyz vertices per triangle.
class Walkmap {
  final Float64List _tris; // 9 doubles per triangle

  Walkmap.fromTriangles(List<double> flatXyz)
      : assert(flatXyz.length % 9 == 0),
        _tris = Float64List.fromList(flatXyz);

  factory Walkmap.fromBytes(ByteData bytes) {
    final count = bytes.getUint32(0, Endian.little);
    final flat = List<double>.generate(
      count * 9,
      (i) => bytes.getFloat32(4 + i * 4, Endian.little),
    );
    return Walkmap.fromTriangles(flat);
  }

  int get triangleCount => _tris.length ~/ 9;

  /// The ground height under (x, z), or null when the point is off the map.
  /// With overlapping walkable layers, the highest ground wins.
  double? groundHeightAt(double x, double z) {
    double? best;
    for (var t = 0; t < _tris.length; t += 9) {
      final ax = _tris[t], ay = _tris[t + 1], az = _tris[t + 2];
      final bx = _tris[t + 3], by = _tris[t + 4], bz = _tris[t + 5];
      final cx = _tris[t + 6], cy = _tris[t + 7], cz = _tris[t + 8];
      // Barycentric coordinates in the XZ plane.
      final den = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
      if (den.abs() < 1e-12) continue; // degenerate footprint
      final w0 = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / den;
      final w1 = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / den;
      final w2 = 1.0 - w0 - w1;
      const eps = -1e-9;
      if (w0 < eps || w1 < eps || w2 < eps) continue; // outside
      final y = w0 * ay + w1 * by + w2 * cy;
      if (best == null || y > best) best = y;
    }
    return best;
  }
}
```

Add to `packages/encarta_3dtours/lib/encarta_3dtours.dart`:

```dart
export 'src/walkmap.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_3dtours/lib/src/walkmap.dart packages/encarta_3dtours/lib/encarta_3dtours.dart packages/encarta_3dtours/test/walkmap_test.dart
git commit -m "feat(3dtours): Walkmap ground solver from .3wm triangle soup"
```

---

### Task 3: Glide pose interpolation

**Files:**
- Create: `packages/encarta_3dtours/lib/src/glide.dart`
- Modify: `packages/encarta_3dtours/lib/encarta_3dtours.dart` (add export)
- Test: `packages/encarta_3dtours/test/glide_test.dart`

**Interfaces:**
- Consumes: `WalkCamera` (Task 1).
- Produces: `double lerpAngle(double a, double b, double t)` (shortest arc, radians); `WalkCamera glideBetween(WalkCamera from, WalkCamera to, double t)` — pure, returns a fresh camera; caller applies its easing curve to `t` first.

- [ ] **Step 1: Write the failing test**

`packages/encarta_3dtours/test/glide_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/glide_test.dart`
Expected: FAIL — `'lerpAngle' isn't defined`.

- [ ] **Step 3: Implement**

`packages/encarta_3dtours/lib/src/glide.dart`:

```dart
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
```

Add to `packages/encarta_3dtours/lib/encarta_3dtours.dart`:

```dart
export 'src/glide.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_3dtours/lib/src/glide.dart packages/encarta_3dtours/lib/encarta_3dtours.dart packages/encarta_3dtours/test/glide_test.dart
git commit -m "feat(3dtours): shortest-arc glide interpolation for stop travel"
```

---

### Task 4: Walkmap sidecar extraction in the materialize tool

**Files:**
- Modify: `app/encarta_reader/tool/materialize_tour_assets.py` (append a section before the final BBOX print)
- Produces asset: `app/encarta_reader/assets/3dtours/acropolis/acr_walkmap.bin` (committed)

**Interfaces:**
- Consumes: the quarry glTF at `/Users/nexus/projects/experiments/strata/quarry/output/3dvt/acr/` (`gltf` + `binblob` already loaded at the top of the script). The walkmap mesh is the one whose `name` ends with `.3wm` (case-insensitive).
- Produces: `acr_walkmap.bin` in the Task 2 byte format (`u32 triCount` + `triCount*9` f32 LE, indices resolved to a flat soup).

- [ ] **Step 1: Append the extraction to `tool/materialize_tour_assets.py`**

Add before the final `BBOX` print, after the points section (mirror the script's existing style):

```python
# ---- 4. Walkmap sidecar (COMMITTED): the .3wm mesh's triangles, flattened ----
# The .3wm is the original engine's walkmap (walkable ground). The reader's
# Walkmap ground solver (packages/encarta_3dtours) consumes this flat soup:
#   u32 triCount ; triCount * 9 f32 (three xyz vertices per triangle), LE.
wm_tris = []
for m in gltf["meshes"]:
    if not m["name"].lower().endswith(".3wm"):
        continue
    for prim in m["primitives"]:
        if prim.get("mode", 4) != 4 or "indices" not in prim:
            continue
        pos_acc = gltf["accessors"][prim["attributes"]["POSITION"]]
        pos_off = gltf["bufferViews"][pos_acc["bufferView"]]["byteOffset"]
        verts = struct.unpack_from(f"<{pos_acc['count'] * 3}f", binblob, pos_off)
        idx_acc = gltf["accessors"][prim["indices"]]
        idx_off = gltf["bufferViews"][idx_acc["bufferView"]]["byteOffset"]
        fmt = {5125: "I", 5123: "H"}[idx_acc["componentType"]]
        idx = struct.unpack_from(f"<{idx_acc['count']}{fmt}", binblob, idx_off)
        for i in idx:
            wm_tris.extend(verts[i * 3 : i * 3 + 3])

walk_path = os.path.join(OUT_ASSETS, "acr_walkmap.bin")
with open(walk_path, "wb") as f:
    f.write(struct.pack("<I", len(wm_tris) // 9))
    f.write(struct.pack(f"<{len(wm_tris)}f", *wm_tris))
print(f"wrote {walk_path}  ({len(wm_tris) // 9} tris)  [committed]")
```

- [ ] **Step 2: Run and verify**

Run (from `app/encarta_reader/`): `python3 tool/materialize_tour_assets.py`
Expected: existing outputs unchanged plus a `wrote .../acr_walkmap.bin  (N tris)` line with N > 0.

Verify the header matches the file size:

```bash
python3 - <<'EOF'
import struct
b = open('assets/3dtours/acropolis/acr_walkmap.bin','rb').read()
n = struct.unpack('<I', b[:4])[0]
assert len(b) == 4 + n * 36, (n, len(b))
print('walkmap OK:', n, 'tris')
EOF
```

Expected: `walkmap OK: <N> tris`.

- [ ] **Step 3: Commit**

```bash
git add app/encarta_reader/tool/materialize_tour_assets.py app/encarta_reader/assets/3dtours/acropolis/acr_walkmap.bin
git commit -m "feat(3dtours): extract .3wm walkmap sidecar for ground clamping"
```

---

### Task 5: `loadTour` returns the walkmap asset key

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/tours/tour_adapter.dart`
- Test: `app/encarta_reader/test/tours/tour_adapter_test.dart` (extend)

**Interfaces:**
- Consumes: existing `TourAssets(tour, glbAsset, pointsAsset)`.
- Produces: `TourAssets` gains `final String walkmapAsset;` (4th positional constructor arg). `loadTour` returns `'$baseDir/${stem}_walkmap.bin'` for it. The walkmap file's presence is NOT checked here — `ToursPage` (Task 7) degrades gracefully when the bundle load fails.

- [ ] **Step 1: Extend the test**

In `app/encarta_reader/test/tours/tour_adapter_test.dart`, add to the existing success-path test (the one asserting `glbAsset`/`pointsAsset`; follow its local variable names):

```dart
expect(assets.walkmapAsset, 'assets/3dtours/acropolis/acr_walkmap.bin');
```

- [ ] **Step 2: Run to verify it fails**

Run (from `app/encarta_reader/`): `flutter test test/tours/tour_adapter_test.dart`
Expected: FAIL — `walkmapAsset` not defined.

- [ ] **Step 3: Implement**

In `tour_adapter.dart`:

```dart
class TourAssets {
  final Tour tour;
  final String glbAsset;
  final String pointsAsset;
  final String walkmapAsset;
  const TourAssets(this.tour, this.glbAsset, this.pointsAsset, this.walkmapAsset);
}
```

and the return statement becomes:

```dart
  return TourAssets(tour, '$baseDir/$stem.glb', '$baseDir/${stem}_points.bin',
      '$baseDir/${stem}_walkmap.bin');
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/tours/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tour_adapter.dart app/encarta_reader/test/tours/tour_adapter_test.dart
git commit -m "feat(3dtours): loadTour exposes the walkmap asset key"
```

---

### Task 6: `TourView` walk mode (drag-look, WASD, ground clamp)

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/tours/tour_view.dart`
- Modify: `app/encarta_reader/lib/src/screens/tours/hotspot_overlay.dart` (`OrbitCamera camera` → `TourCamera camera`)
- Modify: `app/encarta_reader/lib/src/screens/tours/tours_page.dart` (call-site only: `onCameraChanged:` → `onOrbitChanged:` — full page rework is Task 7)
- Test: `app/encarta_reader/test/tours/tour_view_test.dart` (extend; existing orbit tests must keep passing)

**Interfaces:**
- Consumes: `TourCamera`, `WalkCamera` (`forward()`, `look()`, `copy()`, `kWalkEyeHeight`), `Walkmap.groundHeightAt` (Tasks 1–2).
- Produces: new `TourView` constructor:

```dart
const TourView({
  super.key,
  required this.glbAsset,
  required this.pointsAsset,
  required this.camera,          // TourCamera: OrbitCamera or WalkCamera
  this.onOrbitChanged,           // void Function(OrbitCamera)? — orbit gestures
  this.onWalkChanged,            // void Function(WalkCamera)? — walk look/move
  this.walkmap,                  // Walkmap? — ground clamp in walk mode
  this.showPoints = true,        // false hides statue billboards (walk mode)
  this.inputLocked = false,      // true during glide travel
});
```

Behavior contract for Task 7: in walk mode TourView emits fresh `WalkCamera` copies via `onWalkChanged` (never mutates `widget.camera`); keyboard movement runs off the existing ticker at `3.0` units/s (Shift ×2.5), W/S along yaw-forward, A/D strafe, arrows aliased; a step is ground-clamped (`eye.y = ground + kWalkEyeHeight`), blocked off-map, with X-only/Z-only retry (wall-slide); drag = `look(dx * 0.005, -dy * 0.005)`.

- [ ] **Step 1: Write the failing tests**

Append to `app/encarta_reader/test/tours/tour_view_test.dart` (keep the existing orbit tests; reuse the file's existing pump helper if one exists, otherwise this pattern):

```dart
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
```

Add the imports the group needs at the top of the test file:

```dart
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:vector_math/vector_math_64.dart' show Vector3;
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/tours/tour_view_test.dart`
Expected: existing tests pass after the rename below is done together with the implementation; the new `walk mode` group FAILS first (no `onWalkChanged` parameter).

- [ ] **Step 3: Implement in `tour_view.dart`**

Widget field changes (replacing the old `camera`/`onCameraChanged` pair):

```dart
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
  ...
}
```

State additions/changes (the existing orbit fields and methods stay; every
`widget.camera` use in the orbit paths becomes `_orbit` via the getters):

```dart
  OrbitCamera? get _asOrbit =>
      widget.camera is OrbitCamera ? widget.camera as OrbitCamera : null;
  WalkCamera? get _asWalk =>
      widget.camera is WalkCamera ? widget.camera as WalkCamera : null;
  OrbitCamera get _orbit => _asOrbit!;

  // Held movement keys, integrated each ticker tick in walk mode.
  final Set<LogicalKeyboardKey> _keysDown = {};
  Duration? _lastTick;
```

`initState`'s distance clamps guard on orbit mode:

```dart
    final orbit = widget.camera;
    if (orbit is OrbitCamera) {
      final d = orbit.distance;
      _minDistance = (d * 0.1).clamp(0.01, d);
      _maxDistance = d * 20;
    } else {
      _minDistance = 0.01;
      _maxDistance = double.infinity;
    }
```

The ticker gains movement integration (replace the existing ticker body):

```dart
    _ticker = Ticker((elapsed) {
      final dt = _lastTick == null
          ? 0.0
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      _integrateWalkKeys(dt);
      if (mounted && _ready) setState(() {});
    })..start();
```

Movement + clamp (new methods):

```dart
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
    final speed = _kWalkSpeed * (run ? _kRunFactor : 1.0) * dt;

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
```

Input wiring in `build` (walk mode wraps the existing child; orbit path unchanged). Replace the current `Listener(...GestureDetector(...))` return with:

```dart
  @override
  Widget build(BuildContext context) {
    final content = (_ready && _scene != null)
        ? CustomPaint(
            painter: _ScenePainter(_scene!, _sceneCamera()),
            size: Size.infinite,
          )
        : ColoredBox(
            // ... existing placeholder unchanged ...
          );

    if (_asWalk != null) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (!_walkInputActive) return KeyEventResult.ignored;
          if (event is KeyDownEvent) _keysDown.add(event.logicalKey);
          if (event is KeyUpEvent) _keysDown.remove(event.logicalKey);
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
```

`_sceneCamera()` handles both camera kinds (uses the existing `_toVm` bridge):

```dart
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
    // ... existing orbit body unchanged ...
  }
```

Billboards honor `showPoints` — guard the load and rebuild calls:

```dart
      // in _load(), around the points step:
      if (widget.showPoints) {
        try {
          await _loadPointData();
          _rebuildBillboards(widget.camera, force: true);
        } catch (_) {}
      }
```

`_rebuildBillboards` takes the camera generically; change its signature and
basis derivation (orbit call sites pass `OrbitCamera`, and it's never called
in walk mode because `showPoints` is false there — but stay correct):

```dart
  void _rebuildBillboards(TourCamera camera, {bool force = false}) {
    ...
    final vm.Vector3 eye, target;
    if (camera is OrbitCamera) {
      eye = _toVm(camera.eyePosition());
      target = _toVm(camera.target);
    } else if (camera is WalkCamera) {
      eye = _toVm(camera.position);
      target = _toVm(camera.position + camera.forward());
    } else {
      return;
    }
    final forward = (target - eye).normalized();
    ...
    // half-size: orbit scales with distance; walk uses a fixed small splat.
    final half = camera is OrbitCamera
        ? (camera.distance * 0.012).clamp(0.4, 6.0)
        : 0.4;
    ...
  }
```

Orbit gesture handlers (`_onScaleUpdate`, `_onPointerSignal`, `_copyCamera`,
`_emit`) reference `_orbit` instead of `widget.camera`, are additionally
guarded with `if (_asOrbit == null || widget.inputLocked) return;`, and
`_emit` calls `widget.onOrbitChanged?.call(next)`.

In `hotspot_overlay.dart`, change the field type only:

```dart
  final TourCamera camera;
```

In `tours_page.dart` (minimal, Task 7 does the real work):

```dart
                    child: TourView(
                      glbAsset: assets.glbAsset,
                      pointsAsset: assets.pointsAsset,
                      camera: _camera,
                      onOrbitChanged: (c) => setState(() => _camera = c),
                    ),
```

Add the imports `tour_view.dart` now needs:

```dart
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, rootBundle;
import 'package:vector_math/vector_math_64.dart' as vm64;
```

(and delete the old `show rootBundle`-only services import).

- [ ] **Step 4: Run tests to verify everything passes**

Run: `flutter test test/tours/`
Expected: existing orbit tests + new walk group all pass.

- [ ] **Step 5: Run the full reader suite**

Run: `flutter test`
Expected: 128+ passed (previous baseline plus new tests), 2 skipped, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tour_view.dart app/encarta_reader/lib/src/screens/tours/hotspot_overlay.dart app/encarta_reader/lib/src/screens/tours/tours_page.dart app/encarta_reader/test/tours/tour_view_test.dart
git commit -m "feat(3dtours): TourView walk mode — drag-look, WASD, walkmap clamp"
```

---

### Task 7: `ToursPage` — mode toggle, stops panel, glide travel, narration

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/tours/tours_page.dart`
- Test: `app/encarta_reader/test/tours/tours_page_test.dart` (extend)

**Interfaces:**
- Consumes: `TourView` (Task 6 constructor), `WalkCamera.fromHotspot`, `glideBetween`, `Walkmap.fromBytes`, `TourAssets.walkmapAsset` (Task 5), `Hotspot` (`anchor: Vector3`, `angle`, `text`, `id`).
- Produces: page-level behavior only. Keys for tests: mode toggle `ValueKey('tour-mode-toggle')`, prev/next `ValueKey('tour-prev-stop')` / `ValueKey('tour-next-stop')`, stops panel entries `ValueKey('stop-<hotspot.id>')`, panel toggle `ValueKey('tour-stops-panel-toggle')`, narration card `ValueKey('tour-narration')`.

Behavior:
- `_TourMode { overview, walk }`, starts in `overview` (the existing view).
- Travelable stops: `assets.tour.hotspots.where((h) => h.anchor.length2 > 0).toList()` (corpus order).
- Walkmap: loaded in `initState` chain via `(widget.bundleOverride ?? rootBundle).load(assets.walkmapAsset)` → `Walkmap.fromBytes(ByteData.sublistView(data.buffer.asUint8List()))`; on error → `null`. Walk toggle is disabled (`onPressed: null`) when the walkmap is null or there are no travelable stops.
- Entering walk mode the first time: `_walkCamera = WalkCamera.fromHotspot(stops[0]); _currentStop = 0;` and show the narration card. Re-entering keeps the previous pose.
- Travel (`_travelTo(int index)`): glide from `_walkCamera` to `WalkCamera.fromHotspot(stops[index])` with an `AnimationController` (1200 ms, `Curves.easeInOut`, `SingleTickerProviderStateMixin`); during glide `inputLocked: true` on TourView; each tick `setState(() => _walkCamera = glideBetween(_from, _to, curve.value))`; on complete, set `_currentStop = index`, show narration (`_selected = stops[index]`).
- In walk mode, tapping an in-scene hotspot marker whose hotspot is travelable travels to it; non-travelable hotspots show the popup as today. Overview behavior unchanged.
- `TourView` gets: `camera: _mode == _TourMode.walk ? _walkCamera! : _camera`, `onWalkChanged: (c) => setState(() => _walkCamera = c)`, `walkmap: _walkmap`, `showPoints: _mode == _TourMode.overview`, `inputLocked: _gliding`.
- Header row (a `Positioned` at the top of the existing `Stack`): toggle button (icon `Icons.directions_walk` / `Icons.public`), prev/next `IconButton`s (disabled in overview or mid-glide), counter `Text('stop ${_currentStop! + 1} / ${stops.length}')` when a stop is current.
- Stops panel: a right-side `Positioned` column, collapsible via the panel-toggle button; `ListView` of `ListTile`s (title = `h.text`, `maxLines: 1`, ellipsis; selected = current), tap → switch to walk mode if needed and `_travelTo(i)`.
- Narration card: the existing `_HotspotLabelCard`, given `key: const ValueKey('tour-narration')`.

- [ ] **Step 1: Write the failing tests**

Append to `app/encarta_reader/test/tours/tours_page_test.dart` (reuse the file's existing fake-bundle helper for `bundleOverride`; extend the fake so `acr_walkmap.bin` returns the flat-ground bytes below and the hotspots JSON contains at least two anchored hotspots, e.g. anchors `(0, 1.44, 0, 90)` and `(4, 1.44, 4, 180)`):

```dart
List<int> flatWalkmapBytes() {
  const flat = <double>[
    -20, 0, -20, 20, 0, -20, 20, 0, 20,
    -20, 0, -20, 20, 0, 20, -20, 0, 20,
  ];
  final bd = ByteData(4 + flat.length * 4)
    ..setUint32(0, flat.length ~/ 9, Endian.little);
  for (var i = 0; i < flat.length; i++) {
    bd.setFloat32(4 + i * 4, flat[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

testWidgets('walk toggle enters walk mode at the first stop with narration',
    (tester) async {
  await pumpToursPage(tester); // existing helper, now with walkmap + anchors
  await tester.tap(find.byKey(const ValueKey('tour-mode-toggle')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('tour-narration')), findsOneWidget);
  expect(find.textContaining('stop 1 /'), findsOneWidget);
});

testWidgets('next glides to the following stop and updates the counter',
    (tester) async {
  await pumpToursPage(tester);
  await tester.tap(find.byKey(const ValueKey('tour-mode-toggle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tour-next-stop')));
  await tester.pump(const Duration(milliseconds: 600)); // mid-glide
  await tester.pumpAndSettle(); // glide completes
  expect(find.textContaining('stop 2 /'), findsOneWidget);
});

testWidgets('stops panel lists stops and tapping one travels', (tester) async {
  await pumpToursPage(tester);
  await tester.tap(find.byKey(const ValueKey('tour-stops-panel-toggle')));
  await tester.pumpAndSettle();
  // Tap the second stop in the panel (use the second hotspot id from the fake).
  await tester.tap(find.byKey(const ValueKey('stop-h2')));
  await tester.pumpAndSettle();
  expect(find.textContaining('stop 2 /'), findsOneWidget);
});
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/tours/tours_page_test.dart`
Expected: new tests FAIL (no `tour-mode-toggle` key); existing tests pass.

- [ ] **Step 3: Implement in `tours_page.dart`** per the behavior contract above. Key state block:

```dart
enum _TourMode { overview, walk }

class _ToursPageState extends State<ToursPage>
    with SingleTickerProviderStateMixin {
  late final Future<TourAssets> _future;
  _TourMode _mode = _TourMode.overview;
  Walkmap? _walkmap;
  WalkCamera? _walkCamera;
  int? _currentStop;
  bool _panelOpen = false;
  Hotspot? _selected;

  late final AnimationController _glideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final CurvedAnimation _glideCurve =
      CurvedAnimation(parent: _glideCtrl, curve: Curves.easeInOut);
  WalkCamera? _glideFrom, _glideTo;
  int? _glideTarget;
  bool get _gliding => _glideCtrl.isAnimating;
  ...
}
```

Travel core:

```dart
  void _travelTo(List<Hotspot> stops, int index) {
    final from = _walkCamera ?? WalkCamera.fromHotspot(stops[index]);
    _glideFrom = from;
    _glideTo = WalkCamera.fromHotspot(stops[index]);
    _glideTarget = index;
    _glideCtrl
      ..reset()
      ..forward();
  }

  @override
  void initState() {
    super.initState();
    _future = loadTour(widget.tourId, bundle: widget.bundleOverride)
      ..then(_loadWalkmap);
    _glideCurve.addListener(() {
      final f = _glideFrom, t = _glideTo;
      if (f == null || t == null) return;
      setState(() => _walkCamera = glideBetween(f, t, _glideCurve.value));
    });
    _glideCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && _glideTarget != null) {
        setState(() {
          _currentStop = _glideTarget;
          _selected = _stops![_glideTarget!];
        });
      }
    });
  }
```

(`_stops` is computed once from the loaded assets and cached in state;
`_loadWalkmap` does the guarded bundle load described in the contract.
Remember `_glideCtrl.dispose()` / `_glideCurve.dispose()` in `dispose()`.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/tours/`
Expected: all pass.

- [ ] **Step 5: Full suite**

Run: `flutter test`
Expected: all pass (baseline + new), 2 skipped.

- [ ] **Step 6: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tours_page.dart app/encarta_reader/test/tours/tours_page_test.dart
git commit -m "feat(3dtours): walk mode chrome — stops panel, glide travel, narration"
```

---

### Task 8: Manual macOS verification + angle-convention pinning

**Files:**
- Possibly modify: `packages/encarta_3dtours/lib/src/walk_camera.dart` (one-line angle fix + its test) if the empirical check fails
- Create: `docs/superpowers/plans/tours-walkthrough-macos.png` (evidence screenshot)

**Interfaces:** none — this is the end-to-end gate.

- [ ] **Step 1: Run the app**

From `app/encarta_reader/`: `flutter run -d macos` (no flags — the Info.plist enables Impeller/Flutter GPU). Home → "3-D Tours".

- [ ] **Step 2: Verify overview mode is unchanged** — orbit drag, hotspot tap, popup.

- [ ] **Step 3: Enter walk mode and pin the angle convention**

Toggle walk mode. You should stand at the first stop at eye level. Travel to a stop whose text names a visible monument (e.g. a Parthenon stop) and confirm the view faces that monument. If the view is consistently mirrored or rotated by a fixed offset, fix the mapping in `WalkCamera.fromHotspot` ONLY (e.g. `yaw = math.pi - radians(angle)` or `yaw = radians(-angle)`), update the `fromHotspot` unit test to the corrected expectation, and re-run `dart test`.

- [ ] **Step 4: Verify walk mechanics** — WASD walks at ground level; walking into the hillside edge stops/slides instead of leaving the map; drag looks around; Shift runs; no statue billboards in the sky; stops panel travels with a smooth glide; narration card appears on arrival; prev/next work; counter correct.

- [ ] **Step 5: Capture evidence**

Screenshot the walk view at a recognizable stop to `docs/superpowers/plans/tours-walkthrough-macos.png` (window-scoped `screencapture -o -x -l <windowid>`).

- [ ] **Step 6: Full test suites one last time**

```bash
cd packages/encarta_3dtours && dart test
cd ../../app/encarta_reader && flutter test
```

Expected: all pass.

- [ ] **Step 7: Commit evidence (and any angle fix)**

```bash
git add docs/superpowers/plans/tours-walkthrough-macos.png packages/encarta_3dtours
git commit -m "feat(3dtours): manual macOS walkthrough verification + evidence"
git push
```
