# Encarta 3-D Tour reader — Acropolis vertical slice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render Encarta's Acropolis 3-D tour interactively in the reader app on macOS — Parthenon meshes + statue point clouds in a `flutter_scene` viewport with orbit/pan/zoom and tappable hotspot label popups, reached from a Home button.

**Architecture:** Mirror the MindMaze split — a headless pure-Dart package `packages/encarta_3dtours` (models, JSON parsers, orbit camera + 3-D→2-D projection, view-state) that is fully unit-tested, and the Flutter UI in `app/encarta_reader/lib/src/screens/tours/` (flutter_scene viewport + a renderer-agnostic hotspot overlay that projects 3-D anchors to screen). Assets flow via the established `encarta_assets` + `dataDir` convention, materialized by a one-time import tool.

**Tech Stack:** Dart/Flutter (Flutter 3.42 beta, Impeller), `flutter_scene` + `flutter_scene_importer` (3-D), `vector_math` (matrices/projection — the standard Flutter math lib), `auto_route` (routing), stdlib `test`/`flutter_test`.

## Global Constraints

- **Platform:** macOS only for this slice (the app's primary target). Do not add iOS/Android-specific work.
- **Package naming:** `encarta_<domain>`, snake_case, `publish_to: none`, `version: 0.1.0`, `resolution: workspace`. New package = `packages/encarta_3dtours`; add it to the root `pubspec.yaml` `workspace:` list explicitly (globs unsupported).
- **Layering:** `encarta_3dtours` is pure Dart — NO Flutter, NO `dart:io`, NO render-backend imports. The 3-D render dependency (`flutter_scene`) lives only in the app tours screens (or a dedicated package), NEVER in `encarta_render`. `dart:io` for asset reads stays behind `encarta_assets`.
- **Artifacts (source):** `quarry/output/3dvt/acr/acr.{gltf,bin,scene.json,hotspots.json}` (gitignored build output). Nothing under `output/` or `assets_derived/` is committed to git.
- **Asset convention:** derived tour assets live at `<dataDir>/assets_derived/3dtours/<tourId>/`; tourId for the Acropolis = `acropolis`. Default `dataDir` = `/Users/nexus/projects/experiments/strata/quarry/build`.
- **JSON shapes (exact):**
  - `hotspots.json`: `[{ "id": str, "text": str, "anchor": [x,y,z,angle] (4 floats), "icon": int|null, "macros": {..} }]` — 108 entries, 45 with non-empty `text`. Render only non-empty-text hotspots. Use `anchor[0..2]` as position.
  - `scene.json`: `{ "nodes": [{"name": str, "transform": [16 floats]}], "lights": [{"name": str, "position": [x,y,z], "color": [r,g,b] 0-255}], "cloud_placements": [...] }`.
- **Hotspot macros** (`macros.MOUSEUP = "SCRIPT.EVENT(...)"`) are NOT executed — surface `text` only.
- **Test commands** run from a package/app dir: pure Dart `dart test`; Flutter `flutter test`. The app builds/runs with `flutter run -d macos` from `app/encarta_reader`.
- **Reader precedent to imitate:** `packages/encarta_assets/tool/transcode_mindmaze_art.dart` (derived-asset import tool), `app/encarta_reader/lib/src/screens/mindmaze/` (app-hosted feature UI), `app/encarta_reader/lib/src/nav/{app_router,app_navigator}.dart`, `home_{page,view}.dart` (Home button wiring), `packages/encarta_assets/lib/src/asset_config.dart`.

---

### Task 1: flutter_scene point-cloud SPIKE (gating — manual verification)

The one real unknown: can `flutter_scene` render our statue **point clouds** on macOS? This spike answers it before any production code depends on the answer. It is exploratory (manual screenshot verification), not TDD.

**Files:**
- Add dep: `app/encarta_reader/pubspec.yaml` (`flutter_scene`, `flutter_scene_importer`)
- Create (throwaway, committed): `app/encarta_reader/lib/src/screens/tours/spike/tour_spike_app.dart`
- Create: `reader/docs/superpowers/plans/spike-notes-flutter_scene.md` (findings + decision)

- [ ] **Step 1: Add flutter_scene + do the glTF→.model conversion for acr**

Add to `app/encarta_reader/pubspec.yaml` dependencies: `flutter_scene` and (dev) `flutter_scene_importer`. Run `flutter pub get`. Then convert the Acropolis glTF to flutter_scene's `.model` using the importer's documented CLI (check its README via `dart run flutter_scene_importer:import --help` or the package docs). Target:
```bash
cd ~/projects/experiments/strata/reader/app/encarta_reader
dart run flutter_scene_importer:import \
  --input /Users/nexus/projects/experiments/strata/quarry/output/3dvt/acr/acr.gltf \
  --output /tmp/acr.model
```
If the importer rejects the glTF (e.g. POINTS-mode primitives), record the exact error — that is itself a key finding.

- [ ] **Step 2: Build a minimal spike app that renders mesh + points**

Write `tour_spike_app.dart`: a `MaterialApp` whose home hosts a `flutter_scene` scene loaded from `/tmp/acr.model`, with a fixed camera framing the model. Follow flutter_scene's current API (Scene, Node.fromAsset / loadModel, Camera). Goal is a single static frame. If the `.model` contains only triangle meshes (POINTS dropped by the importer), ALSO attempt to render the statue points directly: load `acr.hotspots`/`.3cl`-derived points is out of scope here — instead load the point positions+colors from the glTF's POINTS accessors (parse `acr.gltf`+`acr.bin` minimally) and render them as EITHER (a) a flutter_scene points primitive if supported, or (b) billboarded quads (2 tris/point), decimating to ≤50k points for the spike.

- [ ] **Step 3: Run on macOS and capture a screenshot**

Run: `flutter run -d macos -t lib/src/screens/tours/spike/tour_spike_app.dart`
Capture a screenshot of the rendered frame. **Exit criterion:** the frame shows the Parthenon triangle mesh AND at least one colored statue point cloud (via native points or billboard quads).

- [ ] **Step 4: Record findings + the decision**

Write `spike-notes-flutter_scene.md`: does flutter_scene render on macOS? Does the importer accept our glTF? Are POINTS supported natively, or is the billboard-quad path needed (and at what decimation)? How is the camera set (so Task 4/7 can mirror it)? **DECISION:** `NATIVE OK` (proceed with flutter_scene for Tasks 7–9) or `FALLBACK` (this plan switches the render layer to WebView/three.js — STOP and escalate to the controller/human to revise Tasks 7–9 before continuing). Include the screenshot path.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/experiments/strata/reader
git add app/encarta_reader/pubspec.yaml app/encarta_reader/lib/src/screens/tours/spike/ docs/superpowers/plans/spike-notes-flutter_scene.md app/encarta_reader/pubspec.lock
git commit -m "spike(3dtours): flutter_scene macOS mesh+point-cloud render + decision"
```

> **GATING:** If the decision is `FALLBACK`, do not proceed to Tasks 7–9 as written — escalate. Tasks 2–6 (pure Dart + assets) are render-agnostic and proceed regardless.

---

### Task 2: `encarta_3dtours` package scaffold + models

**Files:**
- Create: `packages/encarta_3dtours/pubspec.yaml`
- Create: `packages/encarta_3dtours/lib/encarta_3dtours.dart` (barrel)
- Create: `packages/encarta_3dtours/lib/src/models.dart`
- Create: `packages/encarta_3dtours/test/models_test.dart`
- Modify: `pubspec.yaml` (root workspace list) — add `packages/encarta_3dtours`

**Interfaces:**
- Produces:
  - `class Hotspot { final String id; final String text; final Vector3 anchor; final double angle; final int? icon; const Hotspot(...); }`
  - `class TourLight { final String name; final Vector3 position; final int r, g, b; const TourLight(...); }`
  - `class Tour { final String id; final String name; final List<Hotspot> hotspots; final List<TourLight> lights; const Tour(...); }`
  - (`Vector3` from `package:vector_math/vector_math_64.dart`.)

- [ ] **Step 1: Write the package pubspec + barrel + failing test**

`packages/encarta_3dtours/pubspec.yaml`:
```yaml
name: encarta_3dtours
description: Headless model + parsers + camera for Encarta 3-D Virtual Tours.
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: '>=3.12.0-0 <4.0.0'
dependencies:
  vector_math: ^2.1.4
dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```
Add `- packages/encarta_3dtours` to the root `pubspec.yaml` `workspace:` list (after `packages/encarta_mindmaze`).

`packages/encarta_3dtours/test/models_test.dart`:
```dart
import 'package:vector_math/vector_math_64.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

void main() {
  test('Tour holds hotspots and lights', () {
    final t = Tour(
      id: 'acropolis',
      name: 'Acropolis',
      hotspots: [Hotspot(id: '_H26', text: 'Coloring the Sculptures', anchor: Vector3(0.42, 1.44, 3.98), angle: 183.64, icon: 6)],
      lights: [TourLight(name: '_TORCH4', position: Vector3(1.48, 0.23, -3.24), r: 1, g: 30, b: 83)],
    );
    expect(t.hotspots.single.text, 'Coloring the Sculptures');
    expect(t.hotspots.single.anchor.z, closeTo(3.98, 1e-6));
    expect(t.lights.single.b, 83);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/encarta_3dtours && dart pub get && dart test`
Expected: FAIL — `encarta_3dtours.dart`/models not found.

- [ ] **Step 3: Implement models + barrel**

`packages/encarta_3dtours/lib/src/models.dart`:
```dart
import 'package:vector_math/vector_math_64.dart';

class Hotspot {
  final String id;
  final String text;
  final Vector3 anchor;
  final double angle;
  final int? icon;
  const Hotspot({
    required this.id,
    required this.text,
    required this.anchor,
    required this.angle,
    this.icon,
  });
}

class TourLight {
  final String name;
  final Vector3 position;
  final int r, g, b;
  const TourLight({
    required this.name,
    required this.position,
    required this.r,
    required this.g,
    required this.b,
  });
}

class Tour {
  final String id;
  final String name;
  final List<Hotspot> hotspots;
  final List<TourLight> lights;
  const Tour({
    required this.id,
    required this.name,
    required this.hotspots,
    required this.lights,
  });
}
```
`packages/encarta_3dtours/lib/encarta_3dtours.dart`:
```dart
export 'src/models.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/experiments/strata/reader
git add packages/encarta_3dtours pubspec.yaml pubspec.lock
git commit -m "feat(3dtours): headless package scaffold + tour models"
```

---

### Task 3: JSON parsers (`parseHotspots`, `parseScene`)

**Files:**
- Create: `packages/encarta_3dtours/lib/src/parsers.dart`
- Create: `packages/encarta_3dtours/test/parsers_test.dart`
- Modify: `packages/encarta_3dtours/lib/encarta_3dtours.dart` (export parsers)

**Interfaces:**
- Consumes: `Hotspot`, `TourLight` (Task 2).
- Produces:
  - `List<Hotspot> parseHotspots(String jsonStr)` — parses the hotspots array; keeps ONLY entries with non-empty `text`; `anchor` from `anchor[0..2]`, `angle` from `anchor[3]`.
  - `List<TourLight> parseScene(String jsonStr)` — parses `scene.json` `lights` into `TourLight`s.

- [ ] **Step 1: Write the failing test (real JSON shapes)**

`packages/encarta_3dtours/test/parsers_test.dart`:
```dart
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

const _hotspots = '''
[
  {"id":"_ZEUS2","text":"","anchor":[0,0,0,0],"icon":null,"macros":{}},
  {"id":"_H26","text":"Coloring the Sculptures","anchor":[0.422562,1.442125,3.977404,183.64006],"icon":6,"macros":{"MOUSEUP":"SCRIPT.EVENT(x)"}}
]''';

const _scene = '''
{"nodes":[{"name":"_TORCH4","transform":[1,0,0,0, 0,1,0,0, 0,0,1,0, 1.48,0.23,-3.24,1]}],
 "lights":[{"name":"_TORCH4","position":[1.48,0.23,-3.24],"color":[1,30,83]}],
 "cloud_placements":[]}''';

void main() {
  test('parseHotspots keeps only non-empty text and splits anchor/angle', () {
    final hs = parseHotspots(_hotspots);
    expect(hs.length, 1);
    expect(hs.single.id, '_H26');
    expect(hs.single.anchor.x, closeTo(0.422562, 1e-6));
    expect(hs.single.angle, closeTo(183.64006, 1e-5));
    expect(hs.single.icon, 6);
  });

  test('parseScene reads lights', () {
    final lights = parseScene(_scene);
    expect(lights.single.name, '_TORCH4');
    expect(lights.single.color3(), [1, 30, 83]);
  });
}
```
(Note: this test uses `TourLight.color3()` returning `[r,g,b]` — add that helper to `TourLight` in this task if not present.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/encarta_3dtours && dart test test/parsers_test.dart`
Expected: FAIL — `parseHotspots`/`parseScene` not defined.

- [ ] **Step 3: Implement parsers**

`packages/encarta_3dtours/lib/src/parsers.dart`:
```dart
import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import 'models.dart';

List<Hotspot> parseHotspots(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  final out = <Hotspot>[];
  for (final e in list.cast<Map<String, dynamic>>()) {
    final text = (e['text'] as String?) ?? '';
    if (text.isEmpty) continue;
    final a = (e['anchor'] as List).cast<num>();
    out.add(Hotspot(
      id: e['id'] as String,
      text: text,
      anchor: Vector3(a[0].toDouble(), a[1].toDouble(), a[2].toDouble()),
      angle: a.length > 3 ? a[3].toDouble() : 0.0,
      icon: e['icon'] as int?,
    ));
  }
  return out;
}

List<TourLight> parseScene(String jsonStr) {
  final root = jsonDecode(jsonStr) as Map<String, dynamic>;
  final lights = (root['lights'] as List?) ?? const [];
  return [
    for (final l in lights.cast<Map<String, dynamic>>())
      TourLight(
        name: l['name'] as String,
        position: () {
          final p = (l['position'] as List).cast<num>();
          return Vector3(p[0].toDouble(), p[1].toDouble(), p[2].toDouble());
        }(),
        r: (l['color'] as List)[0] as int,
        g: (l['color'] as List)[1] as int,
        b: (l['color'] as List)[2] as int,
      ),
  ];
}
```
Add to `models.dart` `TourLight`: `List<int> color3() => [r, g, b];`. Export parsers from the barrel: add `export 'src/parsers.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test`
Expected: PASS (all tests). Also sanity-run against the REAL file once:
`dart run --enable-asserts -e "..."` is awkward — instead add a throwaway assertion in a scratch or just trust the fixture; the real file is validated at adapter time (Task 6).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_3dtours
git commit -m "feat(3dtours): scene/hotspots JSON parsers"
```

---

### Task 4: Orbit camera + 3-D→2-D projection (renderer-agnostic)

This is the math that keeps the hotspot overlay in sync with the 3-D view and is fully unit-testable. Both the flutter_scene camera (Task 7) and the overlay (Task 8) derive from it.

**Files:**
- Create: `packages/encarta_3dtours/lib/src/camera.dart`
- Create: `packages/encarta_3dtours/test/camera_test.dart`
- Modify: barrel (export camera)

**Interfaces:**
- Produces:
  - `class OrbitCamera { Vector3 target; double azimuth, elevation, distance; double fovYRadians; ... Vector3 eyePosition(); Matrix4 viewMatrix(); Matrix4 projectionMatrix(double aspect); }`
  - `Offset? projectToScreen(Vector3 world, Matrix4 viewProj, Size screen)` — returns null if the point is behind the camera (w<=0) or outside NDC by a margin; else the pixel offset (y-down).

- [ ] **Step 1: Write the failing test**

`packages/encarta_3dtours/test/camera_test.dart`:
```dart
import 'dart:ui' show Size, Offset;
import 'package:vector_math/vector_math_64.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

void main() {
  test('a point at the camera target projects near screen center', () {
    final cam = OrbitCamera(target: Vector3.zero(), azimuth: 0, elevation: 0, distance: 5);
    const size = Size(800, 600);
    final vp = cam.projectionMatrix(size.width / size.height) * cam.viewMatrix();
    final o = projectToScreen(Vector3.zero(), vp, size);
    expect(o, isNotNull);
    expect(o!.dx, closeTo(400, 1.0));
    expect(o.dy, closeTo(300, 1.0));
  });

  test('a point behind the camera projects to null', () {
    final cam = OrbitCamera(target: Vector3.zero(), azimuth: 0, elevation: 0, distance: 5);
    const size = Size(800, 600);
    final vp = cam.projectionMatrix(size.width / size.height) * cam.viewMatrix();
    // camera looks down -Z from +Z(=5); a point far behind the eye (+Z) is off-screen/behind
    expect(projectToScreen(Vector3(0, 0, 50), vp, size), isNull);
  });
}
```
(`dart:ui` `Size`/`Offset` are available to `dart test` via the Flutter-bundled Dart when run with `flutter test`; if plain `dart test` can't import `dart:ui`, define tiny local `Size`/`Offset`-like records instead — decide in Step 3 and keep the package Flutter-free by using a small `({double dx, double dy})` return type. PREFER the Flutter-free approach: return a `Vector2?` and adapt in the app.)

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/camera_test.dart`
Expected: FAIL — `OrbitCamera`/`projectToScreen` undefined.

- [ ] **Step 3: Implement camera + projection (Flutter-free — return `Vector2?`)**

To keep `encarta_3dtours` Flutter-free, DO NOT import `dart:ui`. Return `Vector2?` (pixels) from `projectToScreen`, and take screen size as `(double width, double height)`. Adjust the Step-1 test accordingly (use `Vector2`, `width/height` doubles).

`packages/encarta_3dtours/lib/src/camera.dart`:
```dart
import 'package:vector_math/vector_math_64.dart';

class OrbitCamera {
  Vector3 target;
  double azimuth;   // radians, around +Y
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

  Vector3 eyePosition() {
    final ce = math.cos(elevation), se = math.sin(elevation);
    final ca = math.cos(azimuth), sa = math.sin(azimuth);
    final dir = Vector3(ce * sa, se, ce * ca);
    return target + dir * distance;
  }

  Matrix4 viewMatrix() =>
      makeViewMatrix(eyePosition(), target, Vector3(0, 1, 0));

  Matrix4 projectionMatrix(double aspect) =>
      makePerspectiveMatrix(fovYRadians, aspect, near, far);
}

/// Project a world point through [viewProj] to pixel coords (y-down).
/// Returns null when the point is behind the camera.
Vector2? projectToScreen(Vector3 world, Matrix4 viewProj, double width, double height) {
  final clip = viewProj.transform(Vector4(world.x, world.y, world.z, 1.0));
  if (clip.w <= 0) return null; // behind camera
  final ndcX = clip.x / clip.w, ndcY = clip.y / clip.w;
  final px = (ndcX * 0.5 + 0.5) * width;
  final py = (1.0 - (ndcY * 0.5 + 0.5)) * height;
  return Vector2(px, py);
}
```
Add `import 'dart:math' as math;` at top. `makeViewMatrix`/`makePerspectiveMatrix` are from `vector_math`. Export `src/camera.dart` from the barrel.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_3dtours
git commit -m "feat(3dtours): orbit camera + world->screen projection"
```

---

### Task 5: `AssetConfig.toursDir` + `import_3dtours` tool

**Files:**
- Modify: `packages/encarta_assets/lib/src/asset_config.dart` (add `toursDir`)
- Create: `packages/encarta_assets/tool/import_3dtours.dart`
- Test: `packages/encarta_assets/test/asset_config_tours_test.dart`

**Interfaces:**
- Produces: `String get toursDir` on `AssetConfig` = `<dataDir>/assets_derived/3dtours`; a CLI tool that materializes `<toursDir>/acropolis/`.

- [ ] **Step 1: Write the failing test**

`packages/encarta_assets/test/asset_config_tours_test.dart`:
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:test/test.dart';

void main() {
  test('toursDir is under assets_derived/3dtours', () {
    final c = AssetConfig('/data');
    expect(c.toursDir, '/data/assets_derived/3dtours');
  });
}
```
(Confirm `AssetConfig` is exported from `encarta_assets.dart`; if not, import the src path used by other tests in that package.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/encarta_assets && flutter test test/asset_config_tours_test.dart`
Expected: FAIL — `toursDir` undefined.

- [ ] **Step 3: Implement `toursDir` + the import tool**

Add to `asset_config.dart` (after `derivedDir`):
```dart
  /// Derived 3-D tour artifacts: `<dataDir>/assets_derived/3dtours`.
  /// Each tour is a subdir, e.g. `<toursDir>/acropolis/acr.model`.
  String get toursDir => p.join(derivedDir, '3dtours');
```
`packages/encarta_assets/tool/import_3dtours.dart` (mirrors `transcode_mindmaze_art.dart` — a standalone dev tool):
```dart
// Usage: dart run encarta_assets:import_3dtours \
//   [--src <quarry/output/3dvt>] [--data-dir <dataDir>] [--tour acr:acropolis]
// Copies quarry per-tour glTF/bin/JSON into <dataDir>/assets_derived/3dtours/<tourId>/
// and converts the glTF to flutter_scene's .model via flutter_scene_importer.
import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final src = _arg(args, '--src') ??
      '/Users/nexus/projects/experiments/strata/quarry/output/3dvt';
  final dataDir = _arg(args, '--data-dir') ??
      '/Users/nexus/projects/experiments/strata/quarry/build';
  // tour mapping: quarry dir name `acr` -> reader tourId `acropolis`.
  final mapping = {'acr': 'acropolis'};
  for (final entry in mapping.entries) {
    final srcDir = Directory(p.join(src, entry.key));
    final dstDir = Directory(p.join(dataDir, 'assets_derived', '3dtours', entry.value));
    if (!srcDir.existsSync()) {
      stderr.writeln('skip ${entry.key}: $srcDir not found');
      continue;
    }
    dstDir.createSync(recursive: true);
    for (final f in srcDir.listSync().whereType<File>()) {
      final dst = p.join(dstDir.path, p.basename(f.path));
      f.copySync(dst);
      stdout.writeln('copied ${p.basename(f.path)}');
    }
    stdout.writeln('NOTE: run flutter_scene_importer on '
        '${p.join(dstDir.path, "${entry.key}.gltf")} -> ${p.join(dstDir.path, "${entry.key}.model")} '
        '(see Task 1 spike for the exact command).');
  }
}

String? _arg(List<String> a, String name) {
  final i = a.indexOf(name);
  return (i >= 0 && i + 1 < a.length) ? a[i + 1] : null;
}
```
(The `.model` conversion command is the one established in Task 1; wire it here as an actual `Process.run` call once the spike confirms the CLI, or leave the documented NOTE + run it manually for the slice — decide based on Task 1's findings and update this tool accordingly.)

- [ ] **Step 4: Run test + run the tool to materialize assets**

Run test: `flutter test test/asset_config_tours_test.dart` → PASS.
Materialize: `cd packages/encarta_assets && dart run tool/import_3dtours.dart` then convert the glTF→.model per Task 1. Verify `ls <dataDir>/assets_derived/3dtours/acropolis/` shows `acr.gltf acr.bin acr.scene.json acr.hotspots.json acr.model`.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/asset_config.dart packages/encarta_assets/tool/import_3dtours.dart packages/encarta_assets/test/asset_config_tours_test.dart
git commit -m "feat(3dtours): AssetConfig.toursDir + import_3dtours tool"
```

---

### Task 6: `tour_adapter` — load the Tour model + geometry path

**Files:**
- Create: `app/encarta_reader/lib/src/screens/tours/tour_adapter.dart`
- Test: `app/encarta_reader/test/tours/tour_adapter_test.dart`

**Interfaces:**
- Consumes: `parseHotspots`, `parseScene`, `Tour` (encarta_3dtours); `AssetConfig.toursDir` (encarta_assets).
- Produces:
  - `class TourAssets { final Tour tour; final String modelPath; const TourAssets(...); }`
  - `Future<TourAssets> loadTour(String tourId, {required String toursDir})` — reads `<toursDir>/<tourId>/acr.scene.json` + `acr.hotspots.json`, builds `Tour`, returns the `acr.model` path. Throws `TourAssetsMissing` (a typed exception) if the dir/files are absent.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/tours/tour_adapter_test.dart`:
```dart
import 'dart:io';
import 'package:encarta_reader/src/screens/tours/tour_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loadTour parses fixtures from toursDir', () async {
    final dir = Directory.systemTemp.createTempSync('tours');
    final td = Directory('${dir.path}/acropolis')..createSync();
    File('${td.path}/acr.scene.json').writeAsStringSync(
      '{"nodes":[],"lights":[{"name":"L","position":[1,2,3],"color":[1,30,83]}],"cloud_placements":[]}');
    File('${td.path}/acr.hotspots.json').writeAsStringSync(
      '[{"id":"_H26","text":"Coloring the Sculptures","anchor":[0.42,1.44,3.98,183.6],"icon":6,"macros":{}}]');
    File('${td.path}/acr.model').writeAsStringSync('x'); // presence only
    final a = await loadTour('acropolis', toursDir: dir.path);
    expect(a.tour.hotspots.single.text, 'Coloring the Sculptures');
    expect(a.tour.lights.single.b, 83);
    expect(a.modelPath, '${td.path}/acr.model');
  });

  test('loadTour throws TourAssetsMissing when absent', () async {
    expect(() => loadTour('nope', toursDir: '/does/not/exist'),
        throwsA(isA<TourAssetsMissing>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/tours/tour_adapter_test.dart`
Expected: FAIL — `tour_adapter.dart` missing. (Add `encarta_3dtours` to `app/encarta_reader/pubspec.yaml` dependencies now; run `flutter pub get`.)

- [ ] **Step 3: Implement the adapter**

`app/encarta_reader/lib/src/screens/tours/tour_adapter.dart`:
```dart
import 'dart:io';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:path/path.dart' as p;

class TourAssetsMissing implements Exception {
  final String message;
  TourAssetsMissing(this.message);
  @override
  String toString() => 'TourAssetsMissing: $message';
}

class TourAssets {
  final Tour tour;
  final String modelPath;
  const TourAssets(this.tour, this.modelPath);
}

const _tourNames = {'acropolis': 'Acropolis'};
// quarry file stem within each tour dir (Acropolis = 'acr').
const _fileStem = {'acropolis': 'acr'};

Future<TourAssets> loadTour(String tourId, {required String toursDir}) async {
  final stem = _fileStem[tourId] ?? tourId;
  final dir = p.join(toursDir, tourId);
  final scene = File(p.join(dir, '$stem.scene.json'));
  final hotspots = File(p.join(dir, '$stem.hotspots.json'));
  final model = File(p.join(dir, '$stem.model'));
  if (!scene.existsSync() || !hotspots.existsSync() || !model.existsSync()) {
    throw TourAssetsMissing(
        'Tour "$tourId" assets not found in $dir — run `dart run encarta_assets:import_3dtours`.');
  }
  final tour = Tour(
    id: tourId,
    name: _tourNames[tourId] ?? tourId,
    hotspots: parseHotspots(await hotspots.readAsString()),
    lights: parseScene(await scene.readAsString()),
  );
  return TourAssets(tour, model.path);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tours/tour_adapter_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tour_adapter.dart app/encarta_reader/test/tours/tour_adapter_test.dart app/encarta_reader/pubspec.yaml app/encarta_reader/pubspec.lock
git commit -m "feat(3dtours): tour_adapter loads Tour model + .model path"
```

---

### Task 7: `tour_view` — flutter_scene 3-D viewport + camera gestures

**Depends on Task 1's `NATIVE OK` decision and the flutter_scene API/camera pattern it established.** If Task 1 was `FALLBACK`, this task is replaced by the WebView viewer (escalate first).

**Files:**
- Create: `app/encarta_reader/lib/src/screens/tours/tour_view.dart`
- Test: `app/encarta_reader/test/tours/tour_view_test.dart`

**Interfaces:**
- Consumes: `TourAssets.modelPath` (Task 6); `OrbitCamera` (Task 4).
- Produces:
  - `class TourView extends StatefulWidget { final String modelPath; final OrbitCamera camera; final void Function(OrbitCamera) onCameraChanged; const TourView(...); }` — renders the `.model` via flutter_scene, maps drag→azimuth/elevation, scroll/pinch→distance, two-finger/right-drag→pan (target), and calls `onCameraChanged` so the overlay stays in sync.

- [ ] **Step 1: Write a build/gesture test (no live GL frame asserted)**

`app/encarta_reader/test/tours/tour_view_test.dart`:
```dart
import 'package:encarta_reader/src/screens/tours/tour_view.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('drag updates camera azimuth via onCameraChanged', (tester) async {
    OrbitCamera? last;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 5);
    await tester.pumpWidget(MaterialApp(
      home: TourView(
        modelPath: '/nonexistent.model', // GL load is guarded; widget still builds
        camera: cam,
        onCameraChanged: (c) => last = c,
      ),
    ));
    await tester.drag(find.byType(TourView), const Offset(50, 0));
    await tester.pump();
    expect(last, isNotNull);
    expect(last!.azimuth, isNot(closeTo(cam.azimuth, 1e-9)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tours/tour_view_test.dart`
Expected: FAIL — `tour_view.dart` missing.

- [ ] **Step 3: Implement `TourView`**

Implement per Task 1's established flutter_scene pattern. Structure (fill flutter_scene specifics from the spike):
- A `StatefulWidget` holding a `flutter_scene` `Scene` and a loaded `Node` from `modelPath` (guard load failures so tests/build don't crash — if the model can't load, show a `ColoredBox` placeholder and still handle gestures).
- Wrap the scene render in a `GestureDetector`/`Listener`: `onScaleUpdate` (rotation via focal delta → azimuth/elevation; scale → distance) and pointer-scroll → distance. On each change, clamp elevation to ±~85°, distance to a sane range, mutate a copy of the camera, and call `onCameraChanged`.
- Drive the flutter_scene camera each frame from `camera.eyePosition()`/`target` (mirror the spike's camera setup).
- The statue points render via the spike's chosen path (native points or billboard quads); encapsulate as a helper the spike produced.

> **Implementer note:** the flutter_scene widget/API calls are NOT pre-written here because they come from Task 1's spike findings (`spike-notes-flutter_scene.md`). Reuse that code. The gesture→camera mapping and the `onCameraChanged` contract above are the testable part; the GL wiring is verified manually (Step 4).

- [ ] **Step 4: Run test + manual macOS check**

Run: `flutter test test/tours/tour_view_test.dart` → PASS.
Manual: temporarily point a scratch `main` at `TourView` with the real `acr.model` and `flutter run -d macos`; confirm the Parthenon + statues render and dragging orbits. (Full integration is exercised in Task 9/10.)

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tour_view.dart app/encarta_reader/test/tours/tour_view_test.dart
git commit -m "feat(3dtours): flutter_scene tour viewport + orbit gestures"
```

---

### Task 8: `hotspot_overlay` — projected tappable markers + label popup

**Files:**
- Create: `app/encarta_reader/lib/src/screens/tours/hotspot_overlay.dart`
- Test: `app/encarta_reader/test/tours/hotspot_overlay_test.dart`

**Interfaces:**
- Consumes: `Hotspot` list, `OrbitCamera` + `projectToScreen` (Task 4).
- Produces:
  - `class HotspotOverlay extends StatelessWidget { final List<Hotspot> hotspots; final OrbitCamera camera; final Size viewport; final void Function(Hotspot) onTap; const HotspotOverlay(...); }` — a `Stack` that positions a tappable marker for each hotspot whose anchor projects in front of the camera and inside the viewport; markers call `onTap`.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/tours/hotspot_overlay_test.dart`:
```dart
import 'package:encarta_reader/src/screens/tours/hotspot_overlay.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('tapping a projected marker fires onTap with the hotspot', (tester) async {
    Hotspot? tapped;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 5);
    final hs = [Hotspot(id: '_H26', text: 'Coloring the Sculptures', anchor: Vector3.zero(), angle: 0, icon: 6)];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 800, height: 600,
        child: HotspotOverlay(
          hotspots: hs, camera: cam, viewport: const Size(800, 600),
          onTap: (h) => tapped = h,
        ),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('hotspot-_H26')));
    expect(tapped?.id, '_H26');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tours/hotspot_overlay_test.dart`
Expected: FAIL — `hotspot_overlay.dart` missing.

- [ ] **Step 3: Implement the overlay**

`app/encarta_reader/lib/src/screens/tours/hotspot_overlay.dart`:
```dart
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

class HotspotOverlay extends StatelessWidget {
  final List<Hotspot> hotspots;
  final OrbitCamera camera;
  final Size viewport;
  final void Function(Hotspot) onTap;
  const HotspotOverlay({
    super.key,
    required this.hotspots,
    required this.camera,
    required this.viewport,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vp = camera.projectionMatrix(viewport.width / viewport.height) * camera.viewMatrix();
    final markers = <Widget>[];
    for (final h in hotspots) {
      final Vector2? s = projectToScreen(h.anchor, vp, viewport.width, viewport.height);
      if (s == null) continue;
      if (s.x < 0 || s.y < 0 || s.x > viewport.width || s.y > viewport.height) continue;
      markers.add(Positioned(
        left: s.x - 14, top: s.y - 14,
        child: GestureDetector(
          key: ValueKey('hotspot-${h.id}'),
          onTap: () => onTap(h),
          child: const _Marker(),
        ),
      ));
    }
    return Stack(children: markers);
  }
}

class _Marker extends StatelessWidget {
  const _Marker();
  @override
  Widget build(BuildContext context) => Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 1.5),
        ),
        child: const Icon(Icons.info_outline, size: 16, color: Colors.black87),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tours/hotspot_overlay_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/hotspot_overlay.dart app/encarta_reader/test/tours/hotspot_overlay_test.dart
git commit -m "feat(3dtours): projected tappable hotspot overlay"
```

---

### Task 9: `tours_page` — assemble viewport + overlay + label popup + states

**Files:**
- Create: `app/encarta_reader/lib/src/screens/tours/tours_page.dart`
- Test: `app/encarta_reader/test/tours/tours_page_test.dart`

**Interfaces:**
- Consumes: `loadTour`/`TourAssets`/`TourAssetsMissing` (Task 6), `TourView` (Task 7), `HotspotOverlay` (Task 8), `OrbitCamera` (Task 4).
- Produces: `@RoutePage() class ToursPage extends StatefulWidget { final String tourId; const ToursPage({required this.tourId}); }` — a `FutureBuilder` over `loadTour`: loading spinner; on `TourAssetsMissing` a friendly message; on success a `Stack` of `TourView` + `HotspotOverlay`, with a shared `OrbitCamera` in state (kept in sync via `onCameraChanged` → `setState`), and a label popup panel shown when a hotspot is tapped (hotspot `text`). Add a `LayoutBuilder` to supply the viewport `Size`.

- [ ] **Step 1: Write the failing test (missing-assets path is deterministic)**

`app/encarta_reader/test/tours/tours_page_test.dart`:
```dart
import 'package:encarta_reader/src/screens/tours/tours_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows friendly message when tour assets are missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ToursPage(tourId: 'acropolis', toursDirOverride: '/does/not/exist'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('not found'), findsOneWidget);
  });
}
```
(Give `ToursPage` an optional `@visibleForTesting String? toursDirOverride` so the test avoids real asset dirs; production resolves `toursDir` from `AppScope`'s `AssetConfig`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tours/tours_page_test.dart`
Expected: FAIL — `tours_page.dart` missing.

- [ ] **Step 3: Implement `ToursPage`**

Implement the `@RoutePage()` widget: resolve `toursDir` (from `toursDirOverride` or `AppScope.of(context)`'s assets config), `FutureBuilder<TourAssets>` on `loadTour`. States: spinner while waiting; `TourAssetsMissing`/error → centered friendly `Text` with the exception message; success → `LayoutBuilder` → `Stack([TourView(...), HotspotOverlay(...)])`, holding an `OrbitCamera` in `State` (initialize `target`/`distance` to frame the model — a reasonable default e.g. target ≈ scene center, distance ≈ 8; refine after the manual check), updating it in `onCameraChanged` via `setState`, and showing a dismissible label panel (a `Positioned` card with `hotspot.text`) when `HotspotOverlay.onTap` fires. Keep it a focused file; extract the popup card as a small private widget.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tours/tours_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/tours/tours_page.dart app/encarta_reader/test/tours/tours_page_test.dart
git commit -m "feat(3dtours): ToursPage assembles viewport + overlay + label popup"
```

---

### Task 10: Wire routing, navigation, and the Home button

**Files:**
- Modify: `app/encarta_reader/lib/src/nav/app_router.dart` (import + route)
- Modify: `app/encarta_reader/lib/src/nav/app_navigator.dart` (`openTour`)
- Modify: `app/encarta_reader/lib/src/screens/home/home_page.dart` (pass `onOpenTours`)
- Modify: `app/encarta_reader/lib/src/screens/home/home_view.dart` (button)
- Regenerate: `app_router.gr.dart` (build_runner)
- Test: `app/encarta_reader/test/tours/tours_route_test.dart`

**Interfaces:**
- Consumes: `ToursPage` (Task 9), `AppNavigator` (existing).
- Produces: `ToursRoute` (generated); `AppNavigator.openTour(String tourId)`; a Home "3-D Tours" button.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/tours/tours_route_test.dart`:
```dart
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openTour navigates to /tours/<id> and records history', () {
    final loc = <String>[];
    final nav = AppNavigator(history: HistoryController(), go: loc.add);
    nav.openTour('acropolis');
    expect(loc.single, '/tours/acropolis');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tours/tours_route_test.dart`
Expected: FAIL — `openTour` undefined.

- [ ] **Step 3: Apply the wiring edits**

In `app_navigator.dart`, after `openMindMaze()`:
```dart
  void openTour(String tourId) => _navigate('/tours/$tourId');
```
In `app_router.dart`, add the import with the others:
```dart
import '../screens/tours/tours_page.dart';
```
and add the route to the `routes` list (after the mindmaze line):
```dart
        AutoRoute(page: ToursRoute.page, path: '/tours/:tourId'),
```
In `home_view.dart`, add a nullable callback field next to `onPlayMindMaze`:
```dart
  final VoidCallback? onOpenTours;
```
add `this.onOpenTours,` to the constructor, and add a button after the MindMaze block:
```dart
                if (widget.onOpenTours != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: FilledButton.icon(
                        key: const ValueKey('tours-open'),
                        onPressed: widget.onOpenTours,
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('3-D Tours'),
                      ),
                    ),
                  ),
```
In `home_page.dart`, in the `HomeView(...)` call, add:
```dart
          onOpenTours: () => AppScope.of(context).navigator.openTour('acropolis'),
```

- [ ] **Step 4: Regenerate the router + run tests**

Run:
```bash
cd app/encarta_reader
dart run build_runner build --delete-conflicting-outputs
flutter test test/tours/
```
Expected: `app_router.gr.dart` regenerates with `ToursRoute`; all tours tests PASS.

- [ ] **Step 5: Manual end-to-end on macOS + commit**

Materialize assets (Task 5) if not done, then:
```bash
flutter run -d macos
```
Click "3-D Tours" on Home → the Acropolis renders; orbit works; tapping a hotspot shows its label. Then:
```bash
git add app/encarta_reader/lib/src/nav/app_router.dart app/encarta_reader/lib/src/nav/app_navigator.dart app/encarta_reader/lib/src/nav/app_router.gr.dart app/encarta_reader/lib/src/screens/home/home_page.dart app/encarta_reader/lib/src/screens/home/home_view.dart app/encarta_reader/test/tours/tours_route_test.dart
git commit -m "feat(3dtours): route + nav + Home button for 3-D Tours"
```

---

## Self-Review

**Spec coverage:**
- DoD 1 (Home button → route): Task 10. ✓
- DoD 2 (render meshes + point clouds + orbit): Tasks 1 (spike), 7 (view). ✓
- DoD 3 (hotspots → tappable label popups): Tasks 3 (parse), 4 (projection), 8 (overlay), 9 (popup). ✓
- DoD 4 (assets via encarta_assets + graceful missing): Tasks 5 (toursDir+import), 6 (adapter + TourAssetsMissing), 9 (friendly message). ✓
- Architecture (headless package + app UI + isolated render dep): Tasks 2–4 (package), 6–10 (app). ✓
- Rendering spike + fallback: Task 1 (gating decision). ✓
- macros not executed / only non-empty-text hotspots: Task 3 filter + Task 9 popup shows `text`. ✓

**Placeholder scan:** Pure-Dart tasks (2,3,4,5,6,8,10) contain complete code. Task 1 (spike) and Task 7 (`tour_view`) intentionally defer the exact `flutter_scene` API calls to the spike's findings — this is a genuine, gated dependency (the spike exists precisely to discover that API), not a hidden placeholder; the testable contracts (gesture→camera, onCameraChanged) ARE specified. Task 3 Step 4 and Task 5 Step 3 note a manual/decision follow-up tied to Task 1 — acceptable and explicit.

**Type consistency:** `Hotspot{id,text,anchor:Vector3,angle,icon}`, `TourLight{name,position,r,g,b}`, `Tour{id,name,hotspots,lights}` defined in Task 2 and used consistently in Tasks 3/6/8/9. `OrbitCamera` + `projectToScreen(...)->Vector2?` defined in Task 4, used in Tasks 7/8/9. `loadTour(...)->TourAssets` + `TourAssetsMissing` defined in Task 6, used in Task 9. `AssetConfig.toursDir` (Task 5) used by Task 9's toursDir resolution. `openTour`/`ToursRoute`/`ToursPage` consistent across Tasks 9–10.

**Known gate carried into execution:** Task 1's decision governs Tasks 7 & 9's render layer. `NATIVE OK` → proceed as written; `FALLBACK` → escalate to revise the view layer to WebView/three.js before Tasks 7–9. Tasks 2–6 are render-agnostic and unaffected.
