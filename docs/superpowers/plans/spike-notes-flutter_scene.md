# Spike notes — flutter_scene on macOS (Task 1, gating)

**Question:** Can `flutter_scene` (Impeller) render our Encarta Acropolis geometry
— triangle meshes (the Parthenon) AND the statue **point clouds** — on macOS?

## DECISION: `NATIVE OK`

flutter_scene renders both the triangle mesh and the (billboard-quad) statue
point cloud on macOS via Impeller/Metal. Points are NOT natively supported, but
the billboard-quad fallback works cleanly and is cheap. Proceed with
flutter_scene for Tasks 7–9, **with the version + fallback caveats below**.

Primary evidence: `docs/superpowers/plans/spike-screenshot.png` — ~50k colored
statue billboards (stone greys / olive-tan chariot horses / greens), rendered on
macOS Impeller. Secondary: `spike-screenshot-combined.png` (mesh + points in one
scene). `spike-screenshot-points.png` is a copy of the primary.

---

## Findings

### 1. Does flutter_scene render on macOS? — YES (Impeller/Metal)
Runs under `flutter run -d macos --enable-impeller --enable-flutter-gpu`. Log
confirms: `Using the Impeller rendering backend (Metal).` No SceneView widget in
the version we can use (see below), so the app owns a `CustomPainter` that calls
`Scene.render(camera, canvas, viewport:)`, repainted by a `Ticker`.

### 2. Version constraint — pin `flutter_scene: 0.16.0` (IMPORTANT)
The box runs **Flutter 3.42.0 beta** (Dart 3.12, engine 2026-03-03).
- `flutter_scene` `0.18.x` (latest): pub **refuses to resolve** — needs Flutter
  `>= 3.44` (really a master build ≥ 2026-06-09 for render-to-mip Flutter GPU).
- `0.17.0`: resolves, but **fails to COMPILE**. It calls flutter_gpu APIs absent
  from this SDK's bundled flutter_gpu:
  `gpu.TextureCompressionFamily`, `GpuContext.supportsTextureCompression`,
  `PixelFormat.bc1RGBAUNormInt` / `bc3…` / `etc2…` / `astc4x4LDR`
  (in `lib/src/texture/compressed_texture.dart` and `shader_library_inline.dart`).
  `flutter_gpu` ships inside the SDK, so it can't be bumped independently.
- `0.16.0`: resolves AND compiles AND renders. **Use this.** It predates the
  texture-compression API and has `MeshGeometry.fromArrays`, `Node.fromGlbAsset`,
  and the offline importer. (Tasks 7–9: bump to `SceneView` + latest once the
  toolchain moves to Flutter ≥ 3.44 / master.)

Dependency note: 0.16.0 pulls `image ^4.5.0 → archive ^4.0.1`, but the app +
`encarta_data` pin `archive ^3.6.0`. Added a spike `dependency_overrides:
archive: ^4.0.1` in `app/encarta_reader/pubspec.yaml`. The only archive use
(`ZipDecoder().decodeBytes` + iterate, `corpus_provisioner.dart`) is API-stable
3.x↔4.x. **Revisit** when de-spiking: either migrate the app to archive 4.x
project-wide or drop the override.

### 3. Does the importer accept our glTF? — YES, but drops POINTS silently
The offline importer is `dart run flutter_scene:import` (there is **no separate
`flutter_scene_importer` package** anymore; it lives in flutter_scene's `bin/`).
Output is a `.fsceneb` package (not `.model`). CLI:
`--input <glb> --output <fsceneb> [--working-directory] [--compress-textures]`.

- It reads a **single-file `.glb`**, not multi-file `.gltf`+`.bin`
  (`bin/import.dart` calls `parseGlb(bytes)`). So `acr.gltf`+`acr.bin` were packed
  into `acr.glb` first (`scratchpad/pack.py`, embeds the one buffer as the GLB
  BIN chunk). 13.9 MB GLB → 6.5 MB `.fsceneb`, **no error**.
- **POINTS are silently dropped.** Source is explicit — `mesh_data` types:
  `"4 = TRIANGLES (the only mode flutter_scene supports)"`; the emitter has
  `if (primitive.mode != 4) continue; // triangles only`. Same at runtime: our
  `Node.fromGlbAsset` run logged exactly 6×
  `Skipping mesh primitive with unsupported topology mode 0` — one per statue
  POINTS primitive. So both the offline and runtime paths keep only the 1543
  triangle meshes and discard the 6 POINTS meshes (498,125 pts).

We render the mesh at runtime via `Node.fromGlbAsset('assets/spike/acr.glb')`
(simplest; the offline `.fsceneb` path also works and is faster to load, prefer
it for production).

### 4. Native POINTS vs billboard-quads — BILLBOARD QUADS (required)
No native POINTS. We parse POSITION + COLOR_0 from the glTF/bin ourselves and
build **camera-facing billboard quads (2 tris = 6 non-indexed verts per point)**
with per-vertex COLOR_0, via `MeshGeometry.fromArrays(positions:, colors:)` +
`UnlitMaterial()` (its `vertexColorWeight` defaults to 1.0, so vertex colors show
directly). Notes for Tasks 7–9:
- **`material.doubleSided = true` is REQUIRED.** Default material back-face-culls
  (CCW winding); without it the billboards were culled and the frame was empty.
- Non-indexed triangle list (6 verts/pt): 50k pts × 4 verts overflows the u16
  index space, so we expand instead of indexing.
- **Decimation:** stride-10 over all 6 point meshes → **49,815 pts** (≤ 50k spike
  budget) from 498,125. Sufficient for readable statue silhouettes.
- Billboards oriented on the CPU from the fixed camera's right/up basis (cheap;
  fine for a static/near-static camera). A vertex-shader billboard or a
  gpu-instanced quad would scale better if the camera orbits.
- COLOR_0 values are real stone tones (browns/tans/greys), NOT white — visible
  in `spike-screenshot.png`.

### 5. Camera setup (Tasks 4/7 should mirror this)
`PerspectiveCamera` is eye/target/up + `fovRadiansY` + `fovNear`/`fovFar` (note:
`fovNear`/`fovFar`, not `near`/`far`). Scene has identity node transforms, so glTF
positions are already world-space. Scene AABB from accessor min/max:
center ≈ `(-0.8, 122.55, -56.6)`, size ≈ `(124.8, 256.5, 227.6)`. Point-cloud
centroid ≈ `(5.8, 91.2, -15.6)`.

```dart
PerspectiveCamera buildTourCamera() {
  final target = kSceneCenter + vm.Vector3(0, -40, 0); // building sits low in the AABB
  final eye = target +
      vm.Vector3(kSceneRadius * 0.9, kSceneRadius * 0.55, kSceneRadius * 1.15);
  return PerspectiveCamera(
    position: eye,
    target: target,
    up: vm.Vector3(0, 1, 0),
    fovRadiansY: 55 * (math.pi / 180.0),
    fovNear: 1.0,
    fovFar: 4000.0,
  );
}
```
Caveat: whole-scene framing is still rough (the AABB is inflated by a few outlier
meshes, so the building renders small/low in the combined shot). Tasks 4/7 should
compute framing from a trimmed/percentile bounds or the hotspot anchors rather
than the raw accessor AABB.

---

## How rendering is wired (0.16.0, no SceneView)
```dart
await Scene.initializeStaticResources();          // once, before render
final node = await Node.fromGlbAsset('assets/spike/acr.glb'); scene.add(node);
scene.add(pointsNode);                             // billboard-quad MeshGeometry
// widget tree:
RepaintBoundary(child: CustomPaint(painter: _ScenePainter(scene, camera)));
// painter.paint: scene.render(camera, canvas, viewport: Offset.zero & size);
```

## Screenshot method (durable evidence)
`RepaintBoundary.toImage()` does NOT read back flutter_scene's Impeller-rendered
texture — it produced a near-white blank (the 3D layer is composited via
`drawTexture`, outside the Skia picture the boundary records). Use an OS window
capture instead: get the app's CoreGraphics window id and
`screencapture -o -x -l <id> out.png` (per-window; does not grab the rest of the
desktop). See `scratchpad/winmain.swift`.

## DECISION: `NATIVE OK` (with caveats)
- Pin `flutter_scene: 0.16.0` until the toolchain reaches Flutter ≥ 3.44 / master
  (then move to `SceneView` + 0.18.x and drop the archive override).
- Points require the billboard-quad fallback + `doubleSided = true` + decimation.
- Whole-scene camera framing needs trimmed bounds (raw AABB over-frames).
