# MindMaze Phase 5b — Wire the Authentic Castle into the Game

**Date:** 2026-07-03
**Status:** Approved
**Repo:** `strata-works/reader` (Flutter pub workspace)
**Base branch:** `main` (contains merged Phases 2–4 + Android/iOS platform work)
**Delivery:** commit-via-PR → new reader PR (branch `mindmaze-castle-wire`)

## Context

Phase 5a (quarry PR#2) decoded the authentic MindMaze castle out of `ENCARTA.EXE`
and materialized it into `encarta.sqlite` as three tables:

- `mm_room(id, area, backdrop_id, character_id, is_goal)` — **11 rooms**
- `mm_door(room_id, direction, target_room_id)` — **20 directed edges**
- `mm_character(id, sprite_set, greeting, banter_json)` — **11 characters** with authentic banter

The castle is connected from `atrium` (area 0, start) to `throne` (`is_goal=1`, area 6)
along an authored spine (Phase 5a took the authored-connectivity fallback because the
original door graph is code-entangled in `CMaze`; **content** — rooms, characters, banter,
backdrops — is authentic, **connectivity** is authored/flagged). All 7 room areas (0–6)
have 679–1155 questions each, so `GameSession` construction succeeds for every room.

Phase 4 (merged) shipped a playable room UI driving `minimalMaze()` — an authored 5-room
castle over areas {0,1}. Phase 5b replaces that placeholder with the real decoded castle
and adds the end-screen.

**This phase is reader-side only.** It consumes the already-built `encarta.sqlite`; it does
not reopen the quarry decode.

## Goals

1. Query the decoded castle (`mm_room`/`mm_door`/`mm_character`) through the data-API.
2. Adapt the castle rows into an engine `MazeGraph` and drive `GameSession` with it,
   replacing `minimalMaze()` in the live page.
3. Load question pools for every area the real castle uses (0–6), not the hardwired {0,1}.
4. Add an end-screen on win: `end`/`trophy` art + the authentic rank text.
5. Transcode the additional art (all 7 backdrops, one frame per 11 sprite sets, `end1`, `trophy`).

## Non-Goals (deferred to Phase 6)

- Ambient audio (`.wav`/`.mid` via MediaKit).
- Multi-frame sprite animation (`jester1..4`, `duke1..3`, `end1..6` sequence).
- Banter variety beyond the primary greeting.
- "Learn more" → open the answer's article in the reader.
- Persisting the story/win text in quarry (authored reader-side instead — see below).

## Design

Architecture mirrors the established layering (Phases 2–4): the **data-API returns data
models**, the **app adapts them to engine types**. No new architectural pattern.

### 1. Data layer — `packages/encarta_data`

Follow the `mm_question` pattern exactly:

- **`lib/src/tables.drift`** — add `mm_room`, `mm_door`, `mm_character` declarations matching
  the quarry DDL (types and nullability as in `encarta.sqlite`).
- **`lib/src/queries.drift`** — add named queries `mindmazeRooms`, `mindmazeDoors`,
  `mindmazeCharacters` (plain `SELECT *`-style, ordered by id for determinism).
- **`lib/src/mindmaze_castle.dart`** (new) — data models: `MindMazeCastle`
  (`List<MindMazeRoom> rooms`, `List<MindMazeDoor> doors`, `List<MindMazeCharacter> characters`),
  `MindMazeRoom(id, area, backdropId, characterId, isGoal)`,
  `MindMazeDoor(roomId, direction, targetRoomId)`,
  `MindMazeCharacter(id, spriteSet, greeting, banter)` — `banter` is `banter_json` parsed
  to `List<String>` (parse in the mapping method, not the model).
- **`lib/src/encarta_db.dart`** — `Future<MindMazeCastle> mindmazeCastle()` running the three
  queries and assembling the model.
- Regenerate `database.g.dart` via `dart run build_runner build`.
  **`dart test` is the real gate** — `dart analyze` excludes `*.g.dart`, so drift regen bugs
  only surface under test (the Phase 2 drift note).

### 2. Adapter — app layer (`app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart`, new)

`MazeGraph castleToMaze(MindMazeCastle castle)`:

- Build engine `Character` per `MindMazeCharacter`: `greeting` = the authentic decoded greeting;
  `spriteSetId` = `spriteSet`; `approve`/`rebuff` = a small **authored generic** feedback set
  (documented as authored — the decoded banter is a flat monologue pool with no per-answer
  reactions; the original gave generic right/wrong cues). Extra `banter` lines are unused in
  5b (surfacing them is Phase 6 variety).
- Build engine `Room` per `MindMazeRoom` (id, area, backdropId, resident character, doors);
  `Door` per `MindMazeDoor`.
- `goalRoomId` = the room with `isGoal == true`. `startRoomId` = `'atrium'` (documented decode
  convention — the authored spine always emits `atrium` as the entry; `is_start` is a candidate
  for a future quarry pass). **Validate:** if there is no goal room or no `atrium`, throw so the
  page degrades gracefully (see below) rather than building a broken maze.
- Comment noting connectivity is the Phase 5a authored spine; content is authentic.

### 3. Pools + Page

- **`mindmaze_pools.dart`** — `buildMindMazePools` already takes an `areas` list; the caller
  now derives it from the castle's distinct room areas instead of defaulting to `[0,1]`.
  Remove the stale "minimalMaze uses {0,1}" coupling comment.
- **`mindmaze_page.dart`** — load the castle via `db.mindmazeCastle()`, `castleToMaze` it,
  derive `areas` from `maze.rooms`, load pools for those areas, build the `GameSession` over the
  real maze. If `mindmazeCastle()` throws or the adapter validation fails (e.g. an old
  `encarta.sqlite` without castle tables), fall through the existing graceful-degradation path
  ("MindMaze could not start." — never a red screen).

### 4. End screen (`room_view.dart`)

Enhance the **won** overlay into an end-screen:

- `end1` art as the overlay backdrop + the `trophy` image + the authored authentic rank text
  **"Master Scholar Of MindMaze"** + a short win blurb + final score + **Play again**.
- The **lost** overlay is unchanged.
- Art is loaded via the existing `mindMazeArt` (derived-PNG loader with labeled placeholder
  fallback). In widget tests, assert the returned **widget type** — never pump a real
  `Image.file` (the Phase 4 async-codec-hang gotcha).
- Wrap the dialog panel content in a scroll view: some authentic greetings are full paragraphs
  and would overflow the fixed panel.

### 5. Art transcode

- **`tool/transcode_mindmaze_art.dart`** — extend `_backdrops` to all 7 room backdrops
  (`atrium`, `dunrm`, `walltre1`, `walltre2`, `bookshlf`, `plnwalls`, `rmofdoor`); extend
  `_sprites` to one representative frame per 11 sprite sets; add `end1` and `trophy` (opaque).
- **`mindmaze_art.dart`** — update the `spriteFrameFor` map for all 11 sprite sets. Several sets
  are numbered-only, so the representative frame differs from the bare set id:
  `suitarm`→`suitarm1`, `secnldy`→`secnldy1`, `servant`→`servant1`, `duke`→`duke1`,
  `king`→`king1`, `jester`→`jester1`; bare-id sets (`alchem`, `asiantra`, `parrot`, `maninst`,
  `sorceres`) map to themselves.
- The one-time local transcode run (`dart run tool/transcode_mindmaze_art.dart`) writes PNGs
  under the gitignored quarry build dir — not committed; packaging is Phase 6.

## Testing (subagent-driven TDD)

- **data-API** (`packages/encarta_data/test`): seed an in-memory drift db with sample
  room/door/character rows → `mindmazeCastle()` returns the expected `MindMazeCastle`
  (banter parsed, isGoal mapped).
- **adapter** (`app/.../test/mindmaze`): `castleToMaze` structural test — rooms and doors wired,
  `startRoomId`/`goalRoomId` correct, greeting mapped, generic approve/rebuff present; validation
  throws when goal or atrium is missing.
- **pools**: area-derivation test — areas come from the maze rooms, pools built for each.
- **end-screen** (`room_view` widget test): won state renders the trophy/rank-text/end-art
  widget **type** + Play again; asserting types, not real image decode.

## Risks / Assumptions

- **`startRoomId = 'atrium'`** is a decode convention, not a DB flag. Validated at adapter;
  documented as a future `is_start` candidate.
- **Old `encarta.sqlite`** without castle tables → `mindmazeCastle()` fails → graceful
  degradation (existing error text).
- **Drift regen** correctness is only caught by `dart test`, not `dart analyze`.
- **Connectivity provenance:** authored spine (Phase 5a flag) — carried as a code comment,
  not surfaced in-game.
