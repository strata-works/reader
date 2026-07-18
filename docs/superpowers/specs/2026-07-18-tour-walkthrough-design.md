# Encarta 3-D Tour: First-Person Walkthrough — Design

Date: 2026-07-18
Status: approved in discussion; pending spec review
Depends on: reader PR #9 (GPU manifests, error surfacing, in-dome framing) and quarry PR #4 (materials + textures in the emitted glTF)

## Motivation

The tour screen currently renders the textured Acropolis diorama with an
orbit camera. It looks right but does not *feel* like Encarta's Virtual
Tours, which were guided, first-person experiences: you stood in the scene
at eye level, looked around, and traveled between authored stops.

The corpus already gives us everything a first-person mode needs:

- Every hotspot's `ANCHORPOINT` is `x,y,z,angle` — an authored eye-level
  viewpoint (y ≈ 1.44) with a facing heading. These are the original tour's
  stops (108 parsed for the Acropolis).
- The `.3wm` file is the tour's walkmap (the loader's own diagnostic string
  is `WALKMAP.LOAD(`): the walkable-ground surface, which we currently just
  render as one more mesh.

## Goals

1. First-person walk mode: stand in the scene, drag to look, WASD/arrows to
   move, constrained to the walkmap.
2. Guided structure: a stops panel built from the hotspots, glide-travel
   between stops, narration card on arrival.
3. Keep the existing orbit view as an "Overview" mode, unchanged.
4. macOS-first input; camera/ground math renderer-agnostic and unit-tested
   in `packages/encarta_3dtours`.

## Non-goals (explicitly out of scope)

- Audio (the containers ship no audio files).
- Decoding the `.32d` 2-D layers (`begin.32d`, `lh.32d`) — no reader exists.
- Statue point-cloud placement (transforms are unrecoverable from the
  corpus); billboards are hidden in walk mode instead.
- Routes/UI for the other six tours (they build in quarry but are not wired
  into the reader).
- iOS/touch controls (follow-up after the feel is proven on macOS).

## 1. Camera & input

`WalkCamera` joins `OrbitCamera` in `packages/encarta_3dtours` (pure Dart,
`vector_math_64`, no Flutter dependency):

- State: `position` (eye, world units), `yaw` (radians around +Y), `pitch`
  (clamped to ±80°), `fovYRadians`, `near = 0.1`, `far = 4000`.
- API: `viewMatrix()`, `projectionMatrix(aspect)`,
  `viewProjectionMatrix(aspect)` — the same shape `OrbitCamera` exposes.
  Both cameras implement a small shared base, `TourCamera`, exposing
  `viewProjectionMatrix(aspect)`, so `HotspotOverlay` projection and
  `TourView`'s scene camera accept either mode's camera.
- Anchor conversion: one documented function maps
  `ANCHORPOINT (x, y, z, angle)` → `position = (x, y, z)`,
  `yaw = radians(angle)`, `pitch = 0`. The angle's zero-direction and
  handedness are pinned empirically during implementation against a
  recognizable stop (a "Parthenon" stop must face the Parthenon); the
  conversion lives in one place so a convention fix is a one-line change.
- Input (macOS): drag-to-look (dx → yaw, dy → pitch, sensitivity in the
  same constant family as the orbit `_kRotSpeed`); WASD + arrow keys move
  in the yaw plane at ~3 world-units/s (site is ~20 units across), Shift ≈
  2.5× run. Keyboard input arrives via a `Focus`/`KeyboardListener` wrapper
  that `TourView` owns only in walk mode. Scroll does nothing in walk mode.

## 2. Ground & walkmap

- Asset: `tool/materialize_tour_assets.py` additionally extracts the
  `.3wm` mesh's triangles from the quarry glTF into `acr_walkmap.bin`
  (format: `u32 triCount`, then `triCount × 9` little-endian f32 — a flat
  xyz triangle soup with indices resolved at pack time). A few KB;
  committed alongside `acr_points.bin`.
- Solver: `Walkmap` in `encarta_3dtours`: parses those bytes;
  `groundHeightAt(x, z) → double?` does a 2-D point-in-triangle test,
  interpolates Y barycentrically, returns the highest hit, or `null` when
  off the map.
- Movement rule: a proposed step is accepted only if its destination has
  ground; the eye sits at ground + 1.45 (the height the authored anchors
  use). A blocked diagonal step retries as X-only then Z-only, producing
  wall-slide instead of a dead stop.
- Off-map anchors: arriving at an anchor that has no walkmap under it is
  allowed (you stand where the author put you); from there, the first
  accepted step must land on the walkmap, otherwise movement stays blocked.
  Travel to any stop always works.

## 3. Stops & travel

- Stop list: the tour's parsed hotspots in corpus (`.3sc`) order. Hotspots
  with the all-zero default anchor are excluded from travel (they still
  appear in the info layer). Stop count for the panel counter = travelable
  stops.
- Travel: a ~1.2 s ease-in-out glide; position lerps, yaw takes the
  shortest arc; input is locked during the glide; no ground-clamping
  mid-flight (anchors are already eye-level); re-ground on arrival.
- Arrival: the stop's text shows as the narration card and the stop
  becomes current in the panel.
- Triggers: tapping an in-scene hotspot marker, clicking a stop in the
  panel, and next/prev all use the same travel path. First entry into walk
  mode places you instantly at the first travelable stop (no glide from
  the orbit position).

## 4. UI chrome

- Stops panel: collapsible dark side panel listing stop titles (hotspot
  text is short and title-like), current stop highlighted, click to
  travel. Styled with the app's Encarta-era look (Selawik, dark chrome).
- Viewport header row: Overview ↔ Walk toggle, prev/next stop buttons, and
  a "stop N / M" counter.
- Narration card: the existing hotspot label card, restyled to double as
  the arrival narration; dismissible.
- Overview mode is unchanged. Walk mode hides the statue billboards
  (unplaced corpus data reads as sky noise at eye level).

## 5. State, data flow & testing

- Ownership: `ToursPage` owns the mode enum, both cameras, the current
  stop index, and the glide animation (a tween driving camera updates).
  `TourView` stays render + input only: it accepts a `TourCamera` and
  swaps gesture wiring by mode (orbit gestures vs. drag-look + keyboard).
  A `showPoints` flag controls the billboard node.
- Assets: `loadTour` returns one more asset key (`acr_walkmap.bin`);
  `ToursPage` builds the `Walkmap` from it. If the walkmap asset is
  missing, walk mode is disabled and overview still works.
- Unit tests (`encarta_3dtours`): `WalkCamera` matrices and the
  anchor-angle conversion; `Walkmap` height queries (inside, outside,
  overlapping-triangles-highest-wins); glide interpolation as a pure
  function; travelable-stop filtering and ordering.
- Widget tests (reader): panel tap → travel + narration; mode toggle swaps
  input handling; keyboard steps ground-clamp against a fake walkmap;
  off-map movement blocked.
- Manual macOS render check with screenshots, per repo convention.

## Open questions resolved during design

- Free walk vs. viewpoints-only: free walk + viewpoints (user choice).
- Platform: macOS first (user choice).
- Chrome: stops panel + narration (user choice).
- Statue billboards in walk mode: hidden (unplaced corpus data).
