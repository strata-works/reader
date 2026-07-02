# MindMaze — Design Spec

**Date:** 2026-07-01
**Status:** Approved (brainstorm) → ready for implementation plan
**Scope:** Recreate the Encarta MindMaze trivia game as a faithful castle-crawl **mode inside the existing Encarta Reader** Flutter app, driven by the authentic recovered question data.

---

## 1. Goal & Decisions

Rebuild MindMaze as a first-person castle crawl: navigate rooms via doors, answer character-posed multiple-choice trivia drawn from the real encyclopedia, with authentic art and audio. Every answer links back to a real article, so the game loops into the reader.

Decisions locked during brainstorming:

- **Target:** MindMaze first (Timeline is a separate, later effort).
- **Fidelity:** Faithful castle recreation (not a modern minimal quiz).
- **Architecture:** A game **mode inside the reader app** — shares the encyclopedia DB and assets; "read more" opens the in-app article.
- **Authenticity policy:** Work with the data we can recover; for elements we cannot recover, investigate alternatives on an as-needed basis and reconstruct faithfully. Reconstructed content is flagged as such in-repo.
- **Data pipeline:** Materialize question data into `encarta.sqlite` via the `quarry` decode pipeline (option a), keyed so answers join the existing `article` table.

---

## 2. Source Data & Recoverability

Source files live at `~/Downloads/encarta/EE/ENCARTA/`:

| Element | Source | Status |
|---|---|---|
| ~2,000+ questions (clue + correct answer + 3 decoys) | `MINDMAZE.DB` (1.4 MB, length-prefixed record format) | Recoverable — needs a new Python parser |
| Answer → article links (each answer carries a RefID) | `MINDMAZE.DB` + `MINDMAZE.IDX` (~8k u32 refid index) | Recoverable — join to existing `article` table |
| 9 area topic pools (~10k article refids total) | `Area0-8.lst` (already extracted, `MINDMAZE.EIT`) | Already extracted |
| Castle art — rooms, doors, 18 wall pics, characters, decor (88 `.dib`) | `MINDMAZE.EIT` | Already extracted; reader has a DIB shim |
| Ambience + music (35 `.wav`, 5 `.mid`) | `MINDMAZE.EIT` | Already extracted; MediaKit plays them |
| Maze layout, character↔room assignment, banter, win/lose rules | Not found in data yet (likely EXE/DLL resources) | Reconstruct as-needed |

### 2.1 `MINDMAZE.DB` record format (observed)

Records are a walkable sequence. Each question record is approximately:

```
[u32 = 0x00000000][u32 clue_len][clue bytes]\t[correct answer][flag byte][article refid u32][00]
    ([len u8][decoy text][article refid u32][00]) x N decoys
```

- The clue is a definition-style prompt (e.g. *"Apparatus on aircraft for aiming and releasing bombs."*).
- Correct answer example: **Bombsight**; decoys: Depth Charge, Guided Missile, Bazooka.
- Each answer (correct + decoys) carries a little-endian u32 article RefID.
- A crude walk found ~2,083 records; exact framing (correct-answer prefix vs decoy length prefix, decoy count) must be nailed down under TDD against the raw bytes.

### 2.2 `MINDMAZE.IDX`

64,304 bytes = 16,076 × u32. Count aligns with ~2,000 questions × ~4 answers, so it is almost certainly an article-refid → question/answer index (enabling "given an article, find questions where it is an answer"). Treated as a validation/optimization aid, **not** a hard dependency — the DB is walkable without it.

---

## 3. Pipeline: Materialize into `encarta.sqlite`

A new `quarry` parser walks `MINDMAZE.DB`/`.IDX` and writes two tables into the existing build DB:

- `mm_question(id INTEGER PK, area INTEGER, clue TEXT, correct_answer_id INTEGER)`
- `mm_answer(id INTEGER PK, question_id INTEGER, text TEXT, article_refid INTEGER, is_correct INTEGER)`

Keyed so `mm_answer.article_refid` joins the existing `article` table. `area` is derived by joining answer refids against the `Area0-8.lst` pools (and/or the IDX), so each question is placed in a castle wing.

The decode is deterministic and byte-checkable against the raw file — the same shape as the existing decode passes. It runs as an added step in the corpus build.

---

## 4. Package Architecture

Mirrors the existing pub-workspace split (`encarta_data` / `encarta_render` / `encarta_assets` / `app/encarta_reader`):

- **`packages/encarta_mindmaze`** (new) — pure game logic & model, **no Flutter deps** (headless-testable): maze graph, room/character definitions, question selection, scoring, win/lose state machine. Reads questions through a thin data interface.
- **`packages/encarta_data`** (extend) — add query methods: `mindmazeQuestions(area)`, `answersFor(questionId)`, `questionsWhereArticleIsAnswer(refid)`. All SQL stays here.
- **`app/encarta_reader`** (extend) — new `/mindmaze` route branch (title → atrium → room screens) wired into the existing router/history. Reuses `encarta_assets` for `.dib`/audio; "read more" pushes the existing article route.

No new stack, no new data store, no duplication of asset or DB logic.

### 4.1 Game model (`encarta_mindmaze`)

- **`MazeGraph`** — nodes = rooms, edges = direction-labeled doors (left/right/tower/north/south). Built from a **declarative maze definition** (a data file authored during reconstruction, seeded by the 9 areas + the room/door art we actually have).
- **`Room`** — backdrop `.dib`, assigned `Character`, ambient loop, exits.
- **`Character`** — sprite set (e.g. `jester1-4` mood/animation frames), greeting + approve/rebuff banter (reconstructed), difficulty weighting.
- **`QuestionPicker`** — pulls an unseen `mm_question` for the room's area; maps correct + 3 decoys onto answer choices.
- **`GameSession`** — current room, score, lives, seen-questions, trophies; `answer(choice)` → transition (advance / rebuff / win / lose). Pure function of state.

### 4.2 Rendering & audio (app layer)

- **Room view** — layered `.dib` composition (ceiling/floor/walls, decor, character sprite), `dialog.dib` panel with clue + answer buttons, door affordances.
- **Audio** — MediaKit: per-area ambient `.wav` loop + `.mid` bed; SFX on correct/wrong.
- **Transitions** — door-open animation between rooms; end-screen sequence (`end1-6.dib`) on win; trophy/medal/ribbon display.

#### Image format (verified against the real files)

The MindMaze `.dib` assets are **already complete 8-bit paletted BMPs** on disk — they begin with a valid `"BM"` `BITMAPFILEHEADER` (`bfOffBits` = 1078 = 14 + 40 header + 1024-byte 256-color palette; `bfSize` matches file size). Verified: PIL opens them directly as `BMP` (mode `P`). Consequences:

- **Decode directly** via `Image.memory(bytes)`. Do **NOT** run them through the reader's `DibShim.toBmp` — that shim *prepends* a 14-byte header for raw headerless DIBs, so applying it here would double-header and corrupt the image. (This differs from the shim's original use case; MindMaze art needs its own resolve path or a shim guard that skips files already starting with `"BM"`.)
- **Backdrops / decor** (e.g. `atrium`, `dialog`, doors) are full-frame, opaque → decode and render as-is. No transparency needed.
- **Character sprites** (e.g. `jester*`, `king1`, `duke*`, `lady1`, `sorceres`, `alchem`, `parrot`, `servant*`) use a **cyan color-key**: **palette index 254 = RGB (0, 255, 255)**, occupying 55–71% of each sprite (all four corners + border). 8-bit BMP has no alpha, so to composite a character over a room backdrop we must convert the keyed color to transparency. Approach: transcode sprites to PNG-with-alpha in the derived-assets pipeline (preferred — keeps runtime simple and matches the existing `assets_derived` convention), or key the color at load time. Whether other palette indices ever collide with true cyan in sprite content must be spot-checked during implementation.

---

## 5. Reconstruction Plan (recover-first, reconstruct-if-needed)

Each unknown is tackled only when its phase arrives:

1. **Maze layout & door graph** — Attempt recovery from `MINDMAZE.IDX`/EXE resources first. If not cleanly recoverable, author a faithful maze: 9 areas → 9 wings, rooms seeded by the actual room/door `.dib` art, sized to each area's topic-pool depth. Layout lives in a data file (revisable without code changes).
2. **Character↔room assignment & difficulty** — Reconstruct from documented MindMaze behavior; assign recovered character sprites to rooms; weight difficulty by area.
3. **Character banter (greet/approve/rebuff)** — Not in `MINDMAZE.DB`. Recover from EXE/DLL string resources if present; otherwise author in-character lines. Kept in an editable data file, clearly marked authored-vs-original.
4. **Win/lose rules & scoring** — Reconstruct classic rules (lives, score, trophies, final room). Encoded in `GameSession`, tunable.

All reconstructed content is flagged in-repo as reconstructed (not original) so authenticity is auditable.

---

## 6. Testing (matches the reader's strict TDD)

- **`encarta_mindmaze`** — headless unit tests: `GameSession` transitions (correct/wrong/win/lose), `QuestionPicker` (no repeats, valid decoys), `MazeGraph` (connectivity, no orphan rooms).
- **`quarry` parser** — fixture test parsing a slice of `MINDMAZE.DB` with exact record assertions; framing round-trip check; ~2k question count assertion.
- **`encarta_data`** — query tests over a small fixture DB (like existing `encarta_data/test` fixtures).
- **app** — widget/smoke test for the room screen and the "read more → article" hop.

---

## 7. Risks

- **Sprite transparency** — character sprites are opaque 8-bit BMPs with a cyan (index 254 / RGB 0,255,255) color-key; they need cyan→alpha conversion (build-time PNG transcode, preferred) before they composite over backdrops. Confirmed against `jester*`, `king1`, `parrot`, `sorceres`. Verify no sprite legitimately uses that exact cyan in its artwork.
- **DIB shim mismatch** — MindMaze `.dib` are already complete BMPs; the reader's `DibShim.toBmp` (built for raw headerless DIBs) would double-header them. MindMaze must decode directly / guard the shim on a leading `"BM"`. Also worth confirming the reader's existing article-`.dib` path isn't relying on the shim for files that already carry a `"BM"` header.
- **MIDI playback** in MediaKit may be unreliable cross-platform → fallback: transcode the 5 `.mid` at build time, or ship ambient-only.
- **`.DB` framing edge cases** — correct-answer vs decoy prefix bytes and decoy count must be pinned under parser TDD (the ~2,083 count is approximate).
- **`.IDX` semantics** — used as validation/optimization only, not a hard dependency.
- **Faithful-layout uncertainty** — mitigated by keeping maze/banter data-driven and revisable.

---

## 8. Phasing (each phase independently shippable & testable)

1. **Decode** — quarry parser → `mm_question`/`mm_answer` in `encarta.sqlite` (+ tests). Unblocks everything; verifiable in isolation.
2. **Data API** — `encarta_data` query methods (+ tests).
3. **Game core** — `encarta_mindmaze` model/state machine, headless (+ tests).
4. **Playable room** — single-room app screen: backdrop + character sprite (with cyan→alpha keying) + question + answer, "read more" hop. Includes the sprite-transparency transcode (or load-time keying) since the first character appears here.
5. **Maze & progression** — full graph, doors, scoring, win/lose, end screens.
6. **Polish** — audio, animations, banter, trophies.

Phases 1–3 carry zero UI risk and lock in the authentic data; the castle experience builds on a proven core.
