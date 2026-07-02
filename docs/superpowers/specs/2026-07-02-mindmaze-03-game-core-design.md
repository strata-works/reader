# MindMaze Phase 3 — Game Core Design Spec

**Date:** 2026-07-02
**Status:** Approved (brainstorm) → ready for implementation plan
**Parent design:** `docs/superpowers/specs/2026-07-01-mindmaze-design.md` (§4.1, §5)
**Upstream:** Phase 1 decode (merged, quarry) + Phase 2 data API (`EncartaDb.mindmazeQuestions`/`mindmazeQuestionCount`, merged, reader).

---

## 1. Goal & Decisions

Build `encarta_mindmaze`: the pure-Dart, headless game core for MindMaze — the maze model plus the `GameSession` state machine that drives play. No UI (Phase 4+), no I/O. It turns loaded question pools + an authored maze into a playable, testable game loop.

Decisions locked during brainstorming:

- **Scope: engine + minimal maze.** Build the content-driven core (`MazeGraph`, `Room`, `Character`, `QuestionPicker`, `GameSession`) plus a small hand-authored maze definition sufficient to test the full loop and drive Phase 4's first room. Authoring the full 9-wing castle is a later, separate effort.
- **Rules: lives + retry, reach goal.** Correct answer clears a room and lets you move on; a wrong answer costs a life and re-poses a fresh question (retry) until correct or lives hit 0. Win = reach & clear the goal room; Lose = 0 lives. (Tunable via config.)
- **Package purity:** `encarta_mindmaze` has **zero Flutter/sqlite/`encarta_data` deps** (mirrors `encarta_render`'s strict isolation). It defines its **own** domain types; the app maps `encarta_data`'s `MindMazeQuestion → Question` when constructing a session.
- **No I/O in the core:** the app loads pools via `EncartaDb.mindmazeQuestions(area)` and injects them. The core is synchronous, pure logic.
- **Determinism:** an injected `Random` (seeded in tests) drives question selection and answer-choice shuffling.

---

## 2. Package & Boundaries

- **New pub-workspace member:** `packages/encarta_mindmaze` (added to the root `pubspec.yaml` workspace list). Plain Dart package; dev-dep on `test` and `lints` only. No `flutter`, no `drift`, no `sqlite3`, no `encarta_data`.
- **What it does:** holds the game's domain model and the `GameSession` state machine.
- **How it's used:** the app constructs a `GameSession` from (a) a `MazeGraph`, (b) `Map<int, List<Question>>` area→pool, (c) a `GameConfig`, (d) a `Random`. It then calls `answer(...)` / `move(...)` and renders the exposed immutable snapshot.
- **What it depends on:** Dart core only.

### File structure (`lib/`)

- `lib/encarta_mindmaze.dart` — barrel export.
- `lib/src/question.dart` — `Question`, `AnswerChoice`.
- `lib/src/maze.dart` — `Direction`, `Door`, `Room`, `Character`, `MazeGraph`.
- `lib/src/question_picker.dart` — `QuestionPicker` (unseen-question selection + choice shuffling).
- `lib/src/game_config.dart` — `GameConfig` (lives, points-per-correct).
- `lib/src/game_session.dart` — `GameSession` + `GameStatus` + the snapshot.
- `lib/src/minimal_maze.dart` — the hand-authored minimal `MazeGraph` + characters/banter (flagged reconstructed).

---

## 3. Domain Model

### 3.1 Question (`question.dart`)

```dart
class AnswerChoice {
  final String text;
  final int articleRefid;   // joins article.refid (for a later "learn more")
  final bool isCorrect;
  const AnswerChoice({required this.text, required this.articleRefid, required this.isCorrect});
}

class Question {
  final int id;                       // mm_question.id (dedup key for "seen")
  final int? area;                    // castle wing 0–8, or null
  final String clue;
  final List<AnswerChoice> choices;   // as presented (already shuffled), exactly one isCorrect
  const Question({required this.id, required this.area, required this.clue, required this.choices});
}
```

The app builds `Question`s from `encarta_data`'s `MindMazeQuestion` (map `answers → choices`). The core treats `choices` as display order.

### 3.2 Maze (`maze.dart`)

```dart
enum Direction { left, right, tower, north, south }

class Door {
  final Direction direction;
  final String targetRoomId;
  const Door({required this.direction, required this.targetRoomId});
}

class Character {
  final String id;
  final String spriteSetId;           // e.g. 'jester' → jester1..4 art
  final String greeting;              // authored (reconstructed)
  final List<String> approve;         // authored approving lines
  final List<String> rebuff;          // authored rebuff lines
  const Character({required this.id, required this.spriteSetId,
    required this.greeting, required this.approve, required this.rebuff});
}

class Room {
  final String id;
  final int area;                     // → which question pool
  final String backdropId;            // .dib art id
  final Character character;
  final List<Door> doors;
  const Room({required this.id, required this.area, required this.backdropId,
    required this.character, required this.doors});
}

class MazeGraph {
  final Map<String, Room> rooms;
  final String startRoomId;
  final String goalRoomId;
  const MazeGraph({required this.rooms, required this.startRoomId, required this.goalRoomId});

  Room room(String id) => rooms[id]!;
  Room? doorTarget(String roomId, Direction d);  // resolve a door, or null
}
```

Authored content (`minimal_maze.dart`) is marked in-file as reconstructed, not original.

---

## 4. QuestionPicker (`question_picker.dart`)

Selects an unseen question for a room's area and shuffles its choices. Pure given an injected `Random`.

```dart
class QuestionPicker {
  QuestionPicker(this._pools, this._random);
  final Map<int, List<Question>> _pools;   // area → available questions (choices unshuffled or as-loaded)
  final Random _random;

  /// Returns a question from [area] not in [seen], with choices freshly shuffled.
  /// If every question in the area is already seen, resets (reuses the full pool)
  /// so play never soft-locks. Returns null only if the area has no questions.
  Question? pick(int area, Set<int> seen);
}
```

- Shuffle produces a new `choices` list; exactly one `isCorrect` preserved.
- Deterministic under a seeded `Random`.
- Guards a malformed question (no correct choice) by skipping it.

---

## 5. GameSession State Machine (`game_session.dart`)

```dart
enum GameStatus { playing, won, lost }

class GameSnapshot {                 // immutable view for the UI
  final String currentRoomId;
  final int lives;
  final int score;
  final Question? currentQuestion;   // null once room cleared, until moving
  final bool currentRoomCleared;
  final GameStatus status;
  final Set<String> clearedRooms;
  final String? lastCharacterLine;   // greeting / approve / rebuff to show
  // const constructor + value equality
}

class GameSession {
  GameSession({
    required MazeGraph maze,
    required Map<int, List<Question>> pools,
    required GameConfig config,
    required Random random,
  });

  GameSnapshot get snapshot;

  /// Answer the current question by its choice index (into snapshot.currentQuestion.choices).
  /// Correct → clear room, add score, surface an approve line; if the cleared room is the
  ///   goal room → status=won.
  /// Wrong → lose a life, surface a rebuff line; if lives==0 → lost, else re-pick a fresh
  ///   unseen question for the room (retry). No-op if status != playing or room already cleared.
  void answer(int choiceIndex);

  /// Move through a door. Allowed only when the current room is cleared and status==playing.
  /// Enters the target room and poses its question if uncleared (the goal room is entered
  /// uncleared like any other — it is won only by answering its question correctly, in
  /// [answer]). No-op if the room isn't cleared / no such door.
  void move(Direction direction);
}
```

**Transitions (all pure functions of state + input + injected RNG):**

| From | Input | Effect |
|---|---|---|
| playing, uncleared room, question posed | `answer(correct)` | room cleared; `score += config.pointsPerCorrect`; `currentQuestion=null`; approve line; **if cleared room == `goalRoom` → `status=won`** |
| playing, question posed, `lives>1` | `answer(wrong)` | `lives-=1`; rebuff line; re-pick fresh unseen question (retry) |
| playing, question posed, `lives==1` | `answer(wrong)` | `lives=0`; `status=lost`; rebuff line |
| playing, current room cleared | `move(valid door)` | enter target; if uncleared, pose its question (never wins on move) |
| playing, current room NOT cleared | `move(...)` | no-op (can't leave until cleared) |
| won/lost | any | no-op |

- **Start:** session begins in `startRoom`, its question posed.
- **Goal clearing:** entering the goal room poses its question like any room; answering it correctly clears it → `won`. (So the goal room is a real final challenge, not a free walk-in.)
- **Win = clear the goal room. Lose = lives reach 0.**

### GameConfig (`game_config.dart`)

```dart
class GameConfig {
  final int startingLives;       // default 3
  final int pointsPerCorrect;    // default 100
  const GameConfig({this.startingLives = 3, this.pointsPerCorrect = 100});
}
```

---

## 6. Minimal Maze (`minimal_maze.dart`)

A hand-authored `MazeGraph` for testing + Phase 4:

- ~4–5 rooms across 1–2 wings, connected `start → … → goal` (at least one branch so `move(direction)` has real choices).
- Each room: a real `backdropId` and `Character` drawn from the extracted art names (e.g. `atrium`, `bookshlf`; characters `jester`, `king`, `sorceres`).
- Authored banter (greeting/approve/rebuff) per character — short, in-character, **flagged reconstructed** in a file-level comment.
- Exposed as `MazeGraph minimalMaze()`.

This is content, not engine; the engine is fully generic over any `MazeGraph`.

---

## 7. Testing (headless, seeded RNG)

- **MazeGraph** (`minimal_maze` + graph invariants): `startRoomId`/`goalRoomId` exist in `rooms`; every door's `targetRoomId` resolves; no orphan rooms (all reachable from start); every room's `area` is a key some test pool provides.
- **QuestionPicker:** returns only unseen questions until the area pool is exhausted, then resets (no soft-lock); deterministic under a fixed seed; shuffled `choices` always contain exactly one `isCorrect`; skips a malformed (no-correct) question; returns null for an empty area.
- **GameSession:**
  - correct answer → room cleared, score += points, approve line surfaced, `currentQuestion` null.
  - wrong answer with lives>1 → life lost, rebuff surfaced, a fresh (different) question re-posed.
  - wrong answer at 1 life → `status == lost`.
  - `move` before clearing → no-op; `move` through a valid door after clearing → enters target and poses its question.
  - **Full win playthrough:** answer correctly through `start → … → goal`, clear goal → `status == won`.
  - **Full lose path:** exhaust lives → `status == lost`.
  - `answer`/`move` are no-ops once `won`/`lost`.
- Tests use small synthetic pools + the minimal maze; a fixed `Random(seed)` makes selection/shuffle deterministic.

---

## 8. Error Handling & Constraints

- **Pure/synchronous:** no `Future`s, no I/O, no Flutter. Every transition is deterministic given the injected `Random`.
- **Never soft-lock:** exhausted pool resets `seen` for that area rather than stalling.
- **Snapshots are immutable** with value equality (so the UI can diff and tests can assert whole states).
- **No new external dependencies** beyond `test`/`lints` dev-deps.
- **Authored content flagged** as reconstructed (banter, maze layout), per the parent design's authenticity rule.

---

## 9. Out of Scope (later phases)

- Any Flutter UI, rendering, sprite/`.dib` display, audio — Phase 4+.
- The full 9-wing castle content (all rooms, character assignments, complete banter) — a later authoring effort building on this engine.
- Loading questions from the DB in the core — the app does that via Phase 2 and injects pools.
- Trophies/medals detail, timers, hints — not in this cut (the snapshot leaves room to add them later; `trophies` deferred).
- Reverse-lookup / "learn more" navigation into the reader — a Phase 4+ wiring concern (the `articleRefid` is carried on `AnswerChoice` for when it's needed).
