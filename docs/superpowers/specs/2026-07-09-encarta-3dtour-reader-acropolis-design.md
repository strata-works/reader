# Encarta 3-D Tour reader — Acropolis vertical slice (design)

**Date:** 2026-07-09
**Status:** Design approved; ready for implementation plan
**Repo:** `strata/reader` (Flutter/Dart pub workspace)

## Summary

Render Encarta's Acropolis 3-D Virtual Tour interactively inside the reader app.
A `/tours/acropolis` route shows the tour's geometry — the Parthenon (triangle
meshes) and the statue **point clouds** — in one 3-D scene with orbit/pan/zoom,
and tappable **hotspots** that pop the original label text. This is the first,
de-risking vertical slice; the other 6 decoded tours are deferred to a follow-up.

Upstream inputs already exist (decoded + merged): per-tour glTF + JSON produced by
the quarry pipeline at `quarry/output/3dvt/<tour>/<tour>.{gltf,bin,scene.json,hotspots.json}`
(gitignored build output). This project consumes the Acropolis (`acr`) artifacts.

## Program context

Sibling to the restored MindMaze game. The 3-D tour decode program (design +
plans under `akc/docs/superpowers/`, PRs `strata-works/akc#3`, `quarry#3`, merged)
produced the geometry. This is the reader/rendering sub-project. Decomposition of
the remaining program: **(this) Acropolis vertical slice → generalize to all 7
tours → corpus/experience polish.** Only the vertical slice is specified here.

## Definition of done

In the reader app on **macOS** (the primary/only fully-supported target today):
1. A Home-screen button opens a `/tours/acropolis` route (matching the MindMaze
   entry pattern).
2. The route renders the Acropolis tour in an interactive 3-D viewport:
   - Parthenon geometry from `acr.x` + `acr.3wm` (triangle meshes).
   - Statue geometry from the `.3cl` point clouds, colored.
   - Orbit / pan / zoom camera via gestures.
3. Hotspots (from `acr.hotspots.json`, those with non-empty text) render as
   tappable markers positioned over their 3-D anchors; tapping shows the label
   text in a popup/panel.
4. Assets load through the established `encarta_assets` + `dataDir` convention;
   missing artifacts degrade to a friendly message, never a crash.

Explicitly **out of scope:** the other 6 tours; executing the original
`MACRO.MOUSEUP` hotspot scripts; guided/animated camera paths; iOS/Android
delivery; textures on point clouds beyond their per-point vertex color.

## Architecture (mirrors the MindMaze headless-core + app-UI split)

**`packages/encarta_3dtours`** — headless, pure-Dart (no Flutter, no `dart:io`, no
render backend). Fully unit-testable. Exports via barrel `lib/encarta_3dtours.dart`:
- `Tour` — tour id/name + references to its geometry files + `lights` + `hotspots`.
- `Hotspot` — `{ id, text, anchor: (x,y,z), icon }` parsed from `hotspots.json`.
- `TourLight` — `{ name, position, color }` parsed from `scene.json`.
- Parsers: `parseScene(String json) -> List<TourLight>` (+ nodes),
  `parseHotspots(String json) -> List<Hotspot>`.
- `TourViewState` — small state object: selected hotspot id, camera
  (target/azimuth/elevation/distance) — plain Dart, no framework.

**`app/encarta_reader/lib/src/screens/tours/`** — the Flutter UI:
- `tours_page.dart` — `@RoutePage()` `ToursPage(tourId)`; loads the tour via the
  adapter, hosts the viewport + overlay.
- `tour_view.dart` — the `flutter_scene` (Impeller) 3-D viewport; gesture handling
  drives `TourViewState`'s camera; owns the mesh scene + the point-cloud pass.
- `hotspot_overlay.dart` — each frame, projects hotspot 3-D anchors to screen space
  using the same camera/projection as the viewport, and lays tappable Flutter
  markers over them; tap → label popup. Renderer-agnostic.
- `tour_adapter.dart` — resolves + loads the tour's artifacts through
  `encarta_assets`, builds the `Tour` model and the renderable geometry.

**Rendering dependency** (`flutter_scene` + `flutter_scene_importer`) lives with the
tours UI (or a thin isolated package if it grows) — **never** in `encarta_render`
(kept free of io/asset/render-backend concerns), matching how `encarta_assets`
isolates `media_kit`/`dart:io`.

**Routing / navigation:** add `AutoRoute(page: ToursRoute.page, path: '/tours/:tourId')`
to `app_router.dart`; add `AppNavigator.openTour(String tourId)`; add a Home
`FilledButton.icon` (e.g. `Icons.view_in_ar`, "3-D Tours") wired via
`AppScope.of(context).navigator`; re-run `build_runner`. Camera-state persistence
across navigation (if needed) follows the `MindMazeGameHolder`/`AppScope` pattern.

## Rendering approach + the gating spike

Chosen: **native Flutter via `flutter_scene` (Impeller)** — macOS is a first-class
Impeller target, no WebView.

- **Task 1 is a spike** (gates the rest): stand up a minimal `flutter_scene` view on
  macOS and confirm BOTH (a) a triangle mesh from the Acropolis glTF renders, and
  (b) the statue **point clouds** display acceptably. flutter_scene is triangle-mesh
  oriented; POINTS-primitive support is unverified. If POINTS is unsupported, the
  spike evaluates rendering points as billboarded/instanced quads (decimating the
  498k points as needed for a smooth frame). **Spike exit criterion:** a static
  macOS frame showing the Parthenon mesh + ≥1 colored statue cloud.
  **Fallback:** if no acceptable native point-cloud path is found, switch this slice
  to the WebView/three.js approach (`flutter_inappwebview` + a local asset server +
  `GLTFLoader`/`THREE.Points`). This is an explicit, documented decision point after
  the spike, not a silent pivot.
- Mesh pipeline: glTF (`acr.gltf` + `.bin`) → `flutter_scene` `.model` via the
  offline `flutter_scene_importer`, run inside the import tool (below).
- Camera: free orbit/pan/zoom mapped from gestures to `TourViewState`.

## Hotspots / interaction

`acr.hotspots.json` yields ~108 hotspots (`id`, `text`, `anchor` x/y/z, `icon`).
Render those with non-empty `text`. Each frame the overlay projects the anchor to
2-D via the active camera/projection and positions a tappable marker (icon +
optional short label); tapping selects the hotspot (`TourViewState`) and shows its
full label text in a popup/side panel. The original `MACRO.MOUSEUP=SCRIPT...`
behaviors are opaque engine scripting and are **not executed** — surfacing the
human-readable label is the faithful core for this slice.

## Asset import pipeline (mirrors MindMaze `.dib`→PNG transcode)

- New `packages/encarta_assets/tool/import_3dtours.dart`: copies
  `quarry/output/3dvt/acr/*` → `<dataDir>/assets_derived/3dtours/acropolis/`, and
  runs the glTF→`.model` conversion so the runtime loads the ready `.model` (+ the
  JSON files). One-time/dev tool, like `transcode_mindmaze_art.dart`.
- `AssetConfig` (`packages/encarta_assets`) grows a `toursDir` helper
  (`<dataDir>/assets_derived/3dtours`); `tour_adapter.dart` reads from
  `<toursDir>/<tourId>/` via plain `dart:io` gated behind `encarta_assets`, with a
  graceful "tour assets not found — run import_3dtours" fallback.
- Nothing committed to git; artifacts are produced by quarry + the import tool and
  consumed via the `dataDir` convention.

## Data flow

```
quarry/output/3dvt/acr/*  (gltf,bin,scene.json,hotspots.json)
  → import_3dtours.dart  → <dataDir>/assets_derived/3dtours/acropolis/*  (+ .model)
  → tour_adapter (encarta_assets)  → Tour model + renderable geometry
  → tours_page: tour_view (flutter_scene 3D) + hotspot_overlay (2D projected)
```

## Testing

- `encarta_3dtours` (pure Dart): unit tests for `parseScene`/`parseHotspots`
  against small real fixture JSON (copied from the Acropolis output), and
  `TourViewState` transitions (select hotspot, camera update). These are the bulk
  of automated coverage.
- App: a widget test that `ToursPage` builds with a stub adapter, and that
  `hotspot_overlay`'s anchor→screen projection places markers at expected 2-D
  positions for known anchors + a known camera (projection math is testable without
  a live GL frame).
- The spike's actual 3-D render is verified manually via a macOS screenshot (no
  automated GL-frame assertion).

## Primary risks & mitigations

1. **flutter_scene point-cloud support** — the central unknown. Mitigated by the
   Task-1 gating spike (billboard-quad fallback within native; WebView/three.js
   fallback across approaches).
2. **flutter_scene maturity / glTF→.model workflow friction** — surfaced early by
   the spike; the import tool encapsulates the conversion.
3. **macOS-only** — matches the app's current primary target; iOS/Android deferred.
4. **Artifact availability** — `output/3dvt/acr/*` is gitignored build output; the
   import tool + graceful missing-asset fallback handle absence.

## References

- Upstream decode: `akc/docs/formats/3dvt-*.md`, `akc/docs/superpowers/plans/2026-07-08-*`.
- Reader precedent: `packages/encarta_mindmaze` + `app/encarta_reader/lib/src/screens/mindmaze/`
  (headless-core + app-UI split); `packages/encarta_assets/tool/transcode_mindmaze_art.dart`
  (derived-asset transcode); `app/encarta_reader/lib/src/nav/app_router.dart` (auto_route).
- Artifacts: `quarry/output/3dvt/acr/acr.{gltf,bin,scene.json,hotspots.json}`.
