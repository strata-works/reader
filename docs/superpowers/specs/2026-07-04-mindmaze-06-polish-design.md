# MindMaze Phase 6 — Polish Design

Date: 2026-07-04
Status: Approved (brainstormed 2026-07-04)
Repo: `strata/reader` (Flutter pub workspace). Branch: `mindmaze-polish` off `main`.
Predecessors: Phases 1–5b merged (castle decoded, wired into the game, trophy end screen). See
`2026-07-03-mindmaze-05b-castle-wire-design.md`.

## Goal

Turn the functional-but-static MindMaze castle crawl into a polished experience: sound, animated
characters, authentic character banter, an in-context "Learn more" link to the encyclopedia, and a
rewarding lives-based medal end screen. No gameplay-rule changes.

Assets stay on the existing **dev-transcode** flow (art/audio derived locally into the gitignored
quarry build dir, loaded at runtime via `config.derivedDir` / `Image.file`). No app-bundle packaging
this phase — that is explicitly out of scope.

## In scope

1. **Game audio** — background music + room ambience + event SFX, with a session mute toggle.
2. **Multi-frame sprite animation** — cycle the character sprite frames instead of one static frame.
3. **Authentic banter** — greeting on entry (as today) plus tap-the-character to cycle the decoded
   per-character banter lines.
4. **"Learn more"** — a link on a cleared room that opens the correct answer's article.
5. **Lives-based medal tiers** — the end screen shows a gold/silver/bronze reward keyed to lives left.

## Out of scope (deferred)

- Bundling art/audio into the app for clean-checkout runs (keep dev-transcode).
- Per-answer authentic reactions (the decoded banter is a flat monologue pool, not reactions —
  approve/rebuff stay as the authored generic lines from Phase 5b).
- Mute-state persistence across sessions (session-local toggle only).
- Footstep-loop SFX (`foot1-5`) — movement is a discrete door transition, so `dooropen` covers it;
  the walking loops would be noise.
- Animation/audio for the intro/title screens; `INTRO`/`QUESTION` MIDI stingers.

## Architecture

### A. Engine changes (`packages/encarta_mindmaze`, pure Dart)

Two minimal, unit-tested additions. No gameplay behavior changes.

1. **`GameSession.answer(int)` returns an `AnswerOutcome`** enum `{correct, wrong, won, lost}`
   (currently returns `void` and only mutates). The UI reads the returned outcome to fire the right
   SFX/feedback rather than inferring it by diffing snapshots. `won`/`lost` take precedence over
   `correct`/`wrong` when the answer ends the game. Existing callers that ignore the return keep
   working; the engine test suite asserts the outcome for each transition.
2. **`Character` gains `final List<String> banter`** (defaults to `const []`). Carries the decoded
   per-character monologue pool through to the UI. `minimalMaze()` and fixtures set it as needed.

`move(Direction)` is unchanged — the UI initiates moves, so it fires the door SFX directly in its
own handler; no engine signal needed.

### B. Audio layer (app: `app/encarta_reader/lib/src/screens/mindmaze/`)

A small game-audio abstraction so the UI is testable without real playback:

- **`GameAudio` interface** with methods for: `playSfx(GameSfx)`, `setBackground(String? ambienceId)`,
  `setMuted(bool)`, `dispose()`. `GameSfx` enum: `{correct, wrong, door, knock}`.
- **`MindMazeAudio implements GameAudio`** — the real `media_kit` implementation:
  - One **looping background `Player`**. It first tries the room-appropriate `BGLOOP*` MIDI; if the
    `.mid` fails to open (mpv MIDI support is unverified and often needs a soundfont), it
    **transparently falls back to looping a room ambience `.wav`** (`amb*`). Background selection is
    per-room/per-area (simple mapping; a single BGLOOP is acceptable if per-area proves fiddly).
  - A **small pool of one-shot `Player`s** for fire-and-forget SFX: `right`→correct, `wrong`→wrong,
    `dooropen`→door, `knock`→room entry. A tiny pool avoids cutting off an in-flight SFX.
  - `setMuted(true)` pauses/zeroes background and suppresses SFX; `setMuted(false)` resumes.
- **`SilentGameAudio implements GameAudio`** — a no-op fake used in widget tests. Tests may use a
  recording fake that captures the `(GameSfx, background)` calls to assert *which* audio was
  requested on *which* transition — never actual playback.

**Audio file resolution.** A dev-time copy step — a sibling to the art transcode, either extending
`transcode_mindmaze_art.dart` or a new `tool/copy_mindmaze_audio.dart` — reads the MindMaze `.wav`/
`.mid` assets from `quarry/build/encarta.sqlite` (content-addressed hashed paths) and copies them to
friendly names under `<build>/assets_derived/mindmaze_audio/<id>.<ext>`. Runtime resolves
`${config.derivedDir}/mindmaze_audio/<id>.<ext>`; a missing file degrades gracefully to silence
(no crash), mirroring the art placeholder behavior. This is a one-time local dev step, not committed
(output lives under the gitignored quarry build dir).

### C. Sprite animation (`transcode_mindmaze_art.dart` + `mindmaze_art.dart` + `room_view.dart`)

- **Transcode**: extend the art tool's sprite list to emit **all frames** of the multi-frame sets
  (`jester1-4`, `duke1-3`, `secnldy1-2`, `servant1-2`, `suitarm1-2`), each cyan-keyed to transparent
  like the existing single frames. Single-frame sprites (`king1`, `sorceres`, `alchem`, `asiantra`,
  `parrot`, `maninst`) are unchanged.
- **`mindmaze_art`**: replace the set→single-frame map with a set→**ordered frame-id list**
  (`framesFor(spriteSetId) -> List<String>`), longest-run first. Keep `mindMazeArt(config, id, fit)`
  as the per-frame loader.
- **`RoomView`**: for the current room's character, cycle its frame list on a ~400ms periodic timer
  (or `AnimationController` with an index), rendering the current frame. Sets with a single frame
  render statically (no timer). The timer is created/reset on room entry and disposed with the state.
- **Test guard (carried from Phase 4):** never pump a real `Image.file` in `flutter_test` (async
  codec hangs ~10 min). Widget tests assert the returned widget **type** and that the frame index
  advances against a fake clock / by driving the animation logic directly — not real image decode.

### D. Banter — tap to chatter (`castle_adapter.dart` + `room_view.dart`)

- `castle_adapter.dart` fills the new engine `Character.banter` from `MindMazeCharacter.banter`
  (already parsed from `banter_json` in `encarta_data` but currently unused).
- Room entry still shows the greeting via `lastCharacterLine` (unchanged engine behavior).
- `RoomView` holds a UI-only banter index. **Tapping the character sprite** advances the index and
  displays the next line from `room.character.banter` (wrapping). If a character has no banter, the
  sprite is not interactive (still shows greeting). This is pure presentation — no engine state.

### E. Learn more (`mindmaze_page.dart` + `room_view.dart`)

- `MindMazePage` (which has navigator/`AppScope` access) passes an **`onOpenArticle(int refid)`**
  callback into `RoomView`. `RoomView` never reaches into the navigator itself — keeps it decoupled
  and testable (tests pass a spy callback).
- When a room is **cleared** (question solved), `RoomView` shows a **"Learn more"** button that calls
  `onOpenArticle(correctChoice.articleRefid)`, opening the answer's article via the existing
  `openArticle(refid)` → `/article/:refid` route. Every `AnswerChoice` already carries `articleRefid`.

### F. Medal tiers (`end_screen.dart`)

- `MindMazeEndScreen` keys a **tier off lives remaining at win**:
  - 3 lives → **gold**, art `trophy`, rank "Master Scholar Of MindMaze" (the authentic top rank).
  - 2 lives → **silver**, art `medal`, authored rank (e.g. "Scholar Of MindMaze").
  - 1 life → **bronze**, art `ribbon`, authored rank (e.g. "Apprentice Of MindMaze").
- Shows tier art + rank label + score + "Play again" (existing). Rank labels are authored reader-side
  (not persisted in the DB), consistent with Phase 5b. Lives-remaining is read from the final
  `GameSnapshot`.

## Data & assets (all already present in `quarry/build/encarta.sqlite`, `source='MINDMAZE.EIT'`)

- **Audio**: 5 `.mid` (`BGLOOP1-3`, `INTRO`, `QUESTION`), 23 `amb*` ambience `.wav`, SFX `.wav`
  (`right`, `wrong`, `dooropen`, `knock`, `birds`, `foot1-5`, `match1-2`). Phase 6 uses
  `BGLOOP*`/`amb*`/`right`/`wrong`/`dooropen`/`knock`.
- **Sprite frames**: `.dib` sets `jester1-4`, `duke1-3`, `secnldy1-2`, `servant1-2`, `suitarm1-2`
  (multi-frame) plus the existing single frames.
- **Medal art**: `trophy`, `medal`, `ribbon` (`.dib`).
- **Banter**: `mm_character.banter_json`, parsed into `MindMazeCharacter.banter` in `encarta_data`.

## Testing & delivery

- **Subagent-driven TDD**, one task per feature slice, each with its own quality review — the same
  discipline as Phases 4/5b. Tasks (approx):
  - **T1** Engine: `answer()` returns `AnswerOutcome`; `Character.banter` field. (`encarta_mindmaze`)
  - **T2** Audio service: `GameAudio`/`GameSfx` + `MindMazeAudio` (media_kit) + `SilentGameAudio`
    fake; dev audio-copy step; runtime path + graceful-missing degradation.
  - **T3** Audio wiring in `RoomView`: outcome→SFX, move→door, entry→knock, background per room,
    mute toggle in the HUD.
  - **T4** Sprite animation: multi-frame transcode + `framesFor` + `RoomView` frame cycling.
  - **T5** Banter: adapter fills `Character.banter`; tap-to-chatter UI.
  - **T6** Learn more: `onOpenArticle` callback + cleared-room "Learn more" button.
  - **T7** Medal tiers: lives-based end-screen art + rank.
  - **T8** Gate: run dev transcode + audio copy, final whole-branch review, **manual macOS live
    play-through**, PR to reader `main`.
- **Gates**: `encarta_mindmaze` and `encarta_data` `dart test` green; app `flutter test` green; macOS
  build. Final whole-branch opus review. Manual live play-through confirming audio, animation, banter
  tap, Learn-more navigation, and each medal tier — before opening the PR.

## Risks & mitigations

- **`.mid` playback via mpv/media_kit is unverified** → background player falls back to looping an
  ambience `.wav` if the MIDI fails to open. Background audio is always present either way.
- **`Image.file` hang in `flutter_test`** (known from Phase 4/5b) → assert widget type; never pump a
  real image; drive animation logic directly.
- **media_kit `Player` is hard to unit-test** → the `GameAudio` interface + `SilentGameAudio`/recording
  fake keep all UI tests off real playback; the real impl is exercised only in the manual play-through.
- **Multi-frame transcode volume** → only the listed multi-frame sets are added; degrade to the
  existing single frame if extra frames are absent.
