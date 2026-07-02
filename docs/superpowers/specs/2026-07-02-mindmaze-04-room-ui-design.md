# MindMaze Phase 4 — Playable Room UI Design Spec

**Date:** 2026-07-02
**Status:** Approved (brainstorm) → ready for implementation plan
**Parent design:** `docs/superpowers/specs/2026-07-01-mindmaze-design.md` (§4.2)
**Upstream (all merged):** Phase 1 decode (quarry), Phase 2 `encarta_data` query API, Phase 3 `encarta_mindmaze` game core.

---

## 1. Goal & Decisions

Make MindMaze **visible and playable**: a Flutter `/mindmaze` screen that drives the Phase-3 `GameSession` through the authored `minimalMaze()` — render a room (backdrop + character sprite + clue + answer buttons + lives/score), answer questions, walk through doors, and win or lose. This is the first UI phase.

Decisions locked during brainstorming:

- **Scope: walkable minimal maze (full loop).** The screen drives `GameSession` end-to-end — answer, move room-to-room, and reach a win or lose state — over `minimalMaze()`. (Polished maze map / end-screen art is Phase 5.)
- **Sprite alpha: build-time transcode to PNG.** A one-time tool converts MindMaze art `.dib → assets_derived/mindmaze/<id>.png`; sprites get their cyan color-key turned transparent, backdrops stay opaque. Runtime loads PNGs uniformly — this also sidesteps the `DibShim` corruption of already-BM MindMaze `.dib`.
- **Location: in the app.** The screen lives at `app/encarta_reader/lib/src/screens/mindmaze/`, matching `article/home/search`; the app gains a path dep on `encarta_mindmaze`.
- **State: plain `StatefulWidget`** owning the `GameSession` (imperative `answer`/`move` + `setState`) — no new state library. `Random()` unseeded at runtime; seeded only in tests.

---

## 2. Art Pipeline (build-time transcode)

### 2.1 Transcode tool

`packages/encarta_assets/tool/transcode_mindmaze_art.dart` — a one-time Dart CLI (dev-dep `image: ^4.x` added to `encarta_assets`; tool-only, not a runtime dep).

For each required art id, it resolves the source `.dib` from the asset store (`asset` table: `source='MINDMAZE.EIT'`, `baggage_id=<id>` → `path`, under `<dataDir>/assets/`), decodes it (already a valid 8-bit BMP), and writes `<dataDir>/assets_derived/mindmaze/<id>.png`:

- **Sprites** — `jester1`, `king1`, `sorceres`, `lady1`, `duke1` (one representative frame per character used by `minimalMaze()`): every pixel equal to the sprite's cyan key (palette index 254 / RGB (0,255,255)) → fully transparent; all other pixels opaque.
- **Backdrops** — `atrium`, `bookshlf`, `plnwalls`, `rmofdoor`: opaque straight decode → PNG (no keying).

The tool prints what it wrote and skips ids already present (idempotent). The output dir (`<dataDir>/assets_derived/`) is under the quarry build dir, which is **gitignored** — so the PNGs are **not committed to the reader repo**; a developer runs the tool once locally to populate them, and bundling them into the shipped app is a Phase-6 packaging concern. Nothing in the test suite depends on the real transcoded art (see §7). The tool has a pure, unit-testable core: `Uint8List keyCyanToPng(Uint8List dibBytes, {bool key})` (or equivalent) that does the decode + optional cyan→alpha + PNG encode.

### 2.2 Cyan key definition

A pixel is "cyan key" when its RGB equals (0, 255, 255) (equivalently, palette index 254 in these sprites). The tool keys by RGB value after decode, so it is robust whether the decoder yields indexed or RGB pixels. Backdrops are never keyed.

---

## 3. Runtime Art Loading

`app/.../screens/mindmaze/mindmaze_art.dart` — a small widget/helper that renders MindMaze art by id from the derived PNGs:

```dart
Widget mindMazeArt(AssetConfig config, String id, {BoxFit fit});
```

- Resolves `<config.derivedDir>/mindmaze/<id>.png`; if present → `Image.file(...)`, else a labeled placeholder (a neutral box; never blocks play).
- Does NOT use `EncartaImage`/`DibShim` (those assume raw headerless DIBs and would corrupt the already-BM MindMaze `.dib`; and we load derived PNGs anyway).
- Sprites render with their transparency; backdrops fill their area (`BoxFit.cover` for backdrops, `BoxFit.contain` for sprites).

---

## 4. Data Flow & Adapter

### 4.1 Question adapter

`app/.../screens/mindmaze/question_adapter.dart`:

```dart
// encarta_data model → encarta_mindmaze model
mm.Question toGameQuestion(data.MindMazeQuestion q);
```

Maps `MindMazeQuestion(id, area, clue, answers)` → `Question(id, area, clue, choices)`, each `MindMazeAnswer(ordinal, text, articleRefid, isCorrect)` → `AnswerChoice(text, articleRefid, isCorrect)`. Choice order preserved (the `QuestionPicker` shuffles later).

### 4.2 Page loader

`MindMazePage` (`@RoutePage`), route `/mindmaze`:

1. Reads `AppScope` for `db` + `assets`.
2. Loads pools for the areas `minimalMaze()` uses: `db.mindmazeQuestions(0)` and `db.mindmazeQuestions(1)`, each mapped via `toGameQuestion` → `Map<int, List<mm.Question>>`.
3. Constructs `GameSession(maze: minimalMaze(), pools: pools, config: const GameConfig(), random: Random())`.
4. Renders `RoomView(session: session, config: assets.config)`.
5. `FutureBuilder` with `hasError`/degradation handling (matching the other pages): DB null or empty pools → a degradation widget explaining the game data is unavailable. (The engine's construction guard throws if a room's area has no posable question; the loader surfaces that as the degradation widget rather than a crash.)

### 4.3 Entry point

A "Play MindMaze" affordance on the Home portal (`home_view.dart`) that navigates to `/mindmaze`, plus registering `MindMazeRoute` in `app_router.dart`.

---

## 5. Room Screen (`RoomView`)

A `StatefulWidget` owning the `GameSession`. Renders `session.snapshot`:

- **HUD (top):** lives (e.g. heart icons = `snapshot.lives`), `Score <n>`, and the current room's display name / character name.
- **Scene (center):** the room backdrop (`mindMazeArt(config, room.backdropId)`) filling the area, with the character sprite (`mindMazeArt(config, spriteFrameFor(room.character.spriteSetId))`) composited over it in a `Stack`.
- **Dialog panel (bottom):**
  - `snapshot.lastCharacterLine` (greeting / approve / rebuff) when present.
  - If `snapshot.currentQuestion != null`: the clue text + one button per `choice` (`snapshot.currentQuestion.choices`) → `onTap: session.answer(i)`.
  - If the room is cleared (`currentQuestion == null`, `currentRoomCleared == true`): a door button per exit of the current room (`maze.room(currentRoomId).doors`), labeled by `Direction` → `onTap: session.move(door.direction)`.
- **Overlays:** `status == won` → win overlay (final score + "Play again"); `status == lost` → lose overlay ("Try again"). "Play again"/"Try again" rebuild a fresh `GameSession` from the already-loaded pools.

`spriteFrameFor(spriteSetId)` maps a set id to the representative transcoded frame (e.g. `'jester' → 'jester1'`, `'king' → 'king1'`, `'sorceres' → 'sorceres'`, `'lady' → 'lady1'`, `'duke' → 'duke1'`).

Every interaction calls the session method then `setState(() {})`; the whole view re-derives from the new `snapshot` (single source of truth). No animation/audio in this phase (Phase 6).

---

## 6. Files

- Create: `packages/encarta_assets/tool/transcode_mindmaze_art.dart` (+ its testable core).
- Modify: `packages/encarta_assets/pubspec.yaml` (dev-dep `image`).
- Generated (NOT committed): `<dataDir>/assets_derived/mindmaze/*.png` — produced by running the transcode tool into the gitignored quarry build dir. Shipping them with the packaged app is Phase 6. Tests do not depend on them.
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart`
- Create: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart`
- Create: `app/encarta_reader/lib/src/screens/mindmaze/question_adapter.dart`
- Modify: `app/encarta_reader/lib/src/nav/app_router.dart` (+ regenerate `app_router.gr.dart`)
- Modify: `app/encarta_reader/lib/src/screens/home/home_view.dart` (entry point)
- Modify: `app/encarta_reader/pubspec.yaml` (path dep `encarta_mindmaze`)
- Tests under `packages/encarta_assets/test/` and `app/encarta_reader/test/`.

---

## 7. Testing

- **Transcode core** (`encarta_assets`, unit): a synthetic small 8-bit BMP with a block of cyan → the encoded PNG is transparent exactly on the cyan pixels and opaque elsewhere; a non-keyed backdrop stays fully opaque. Tests the pure `keyCyanToPng` function (no filesystem).
- **Question adapter** (app, unit): `toGameQuestion` maps id/area/clue and every choice's `text`/`articleRefid`/`isCorrect`/order.
- **`RoomView` widget tests** (app; construct a `GameSession` directly with synthetic pools + `minimalMaze()` + seeded `Random`, no DB):
  - renders the clue and one button per choice;
  - tapping the correct choice clears the room → door buttons appear (answer buttons gone);
  - tapping a wrong choice removes a heart and re-poses a question;
  - walking `start → … → goal` and answering the goal correctly → win overlay shown;
  - draining lives → lose overlay shown; "Play again"/"Try again" returns to a fresh playing state.
- **Art loader** (app, widget): missing derived PNG → placeholder; present PNG → an `Image`.
- **`MindMazePage` loader** (app, widget, against the `encarta_data` fixture DB): builds pools + a session and shows the room; with empty/absent questions → the degradation widget (no crash).
- Full app suite stays green; `flutter analyze` clean; the macOS app still builds.

---

## 8. Constraints

- **Reuse, don't fight, existing infra:** `AppScope` for `db`/`assets`; `AssetConfig.derivedDir` for art; auto_route for the route; the app's degradation-widget pattern for failures.
- **No `DibShim`/`EncartaImage` for MindMaze art** (already-BM `.dib`); load derived PNGs directly.
- **No new runtime dependency** beyond the `encarta_mindmaze` path dep; `image` is a dev-dep of `encarta_assets` (tool only).
- **Engine is authoritative:** all game rules/state live in `GameSession`; the UI only renders `GameSnapshot` and forwards `answer`/`move`. No game logic in widgets.
- **Graceful degradation:** art miss → placeholder; data miss → degradation widget; never a red screen.

---

## 9. Out of Scope (later phases)

- Polished maze map / navigation UX, transitions, end-screen art (`end1-6`) — Phase 5.
- Audio (ambient `.wav` / `.mid`), sprite animation frames, banter variety, trophies/medals — Phase 6.
- "Learn more" → open the answer's article in the reader (the `articleRefid` is carried through `AnswerChoice`) — a later wiring.
- The full 9-wing castle content — a later authoring effort (the engine + this UI already generalize to any `MazeGraph`).
- Multi-frame sprite sets (only one frame per character is transcoded now).
