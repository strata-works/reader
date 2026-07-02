# MindMaze Phase 3 — Game Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/encarta_mindmaze` — a pure-Dart, headless game core (domain model + `QuestionPicker` + `GameSession` state machine + a minimal authored maze) implementing the lives+retry, reach-goal MindMaze loop.

**Architecture:** A new plain-Dart pub-workspace member with zero Flutter/sqlite/`encarta_data` deps (mirrors `encarta_render`'s isolation). It defines its own value types; the app maps `encarta_data`'s `MindMazeQuestion → Question` and injects in-memory pools. All logic is synchronous and deterministic given an injected `Random`.

**Tech Stack:** Dart, `package:test`. Package dir: `reader/packages/encarta_mindmaze` (member of the `encarta_reader_workspace` pub workspace).

## Global Constraints

- **Pure Dart, zero runtime deps.** No `flutter`, `drift`, `sqlite3`, `encarta_data`, or any new external dependency — dev-deps are only `test` + `lints` (spec §8).
- **No I/O, no async in the core.** Every `GameSession` transition is a synchronous, pure function of state + input + the injected `Random` (spec §1, §8).
- **Determinism:** all randomness (question selection, choice shuffling, banter pick) goes through one injected `Random`; seed it in tests (spec §1, §7).
- **Never soft-lock:** when an area's question pool is exhausted, reset the seen-scope and reuse rather than stalling (spec §4, §8).
- **Own domain types:** the core does NOT import `encarta_data`; it defines `Question`/`AnswerChoice` itself (spec §1, §3).
- **Rules:** correct answer clears the room (+`pointsPerCorrect`) and lets you `move`; wrong answer costs a life and re-poses a fresh unseen question (retry) unless lives hit 0 (lost). Win = answer the **goal room's** question correctly; Lose = 0 lives (spec §1, §5). Defaults: `startingLives=3`, `pointsPerCorrect=100`.
- **Authored content flagged** as reconstructed (banter, maze layout) via file-level comments (spec §6, §8).
- **Analysis:** `dart analyze` must be clean under `strict-casts`/`strict-raw-types`.
- **Commands run from** `reader/packages/encarta_mindmaze` unless noted; `dart pub get` runs from the reader workspace root.

---

### Task 1: Scaffold the `encarta_mindmaze` package

**Files:**
- Create: `packages/encarta_mindmaze/pubspec.yaml`
- Create: `packages/encarta_mindmaze/analysis_options.yaml`
- Create: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart`
- Create: `packages/encarta_mindmaze/test/scaffold_test.dart`
- Modify: `pubspec.yaml` (workspace root — append the member path)

**Interfaces:**
- Produces: `const String kEncartaMindmazeLibrary` (barrel sentinel).

- [ ] **Step 1: Create the package files**

`packages/encarta_mindmaze/pubspec.yaml`:

```yaml
name: encarta_mindmaze
description: >-
  Pure-Dart, headless game core for MindMaze — domain model + GameSession state
  machine. No Flutter, no sqlite, no encarta_data.
publish_to: none
version: 0.1.0
resolution: workspace

environment:
  sdk: '>=3.12.0-0 <4.0.0'

dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```

`packages/encarta_mindmaze/analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
```

`packages/encarta_mindmaze/lib/encarta_mindmaze.dart`:

```dart
/// Pure-Dart, headless game core for MindMaze: domain model + GameSession
/// state machine. No Flutter, no I/O — logic only.
library;

/// Sentinel proving the package compiles and is wired into the workspace.
/// Real exports are added as each unit lands.
const String kEncartaMindmazeLibrary = 'encarta_mindmaze';
```

`packages/encarta_mindmaze/test/scaffold_test.dart`:

```dart
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

void main() {
  test('barrel is importable and wired into the workspace', () {
    expect(kEncartaMindmazeLibrary, 'encarta_mindmaze');
  });
}
```

- [ ] **Step 2: Register the member in the workspace root**

In the root `pubspec.yaml`, append the new member to the `workspace:` list (after `app/encarta_reader`):

```yaml
  - packages/encarta_mindmaze
```

- [ ] **Step 3: Resolve and run the sentinel test**

Run (from the reader workspace root): `dart pub get`
Expected: resolves with `encarta_mindmaze` as a workspace member, no errors.

Run (from `packages/encarta_mindmaze`): `dart test`
Expected: PASS (1 test).

- [ ] **Step 4: Verify analysis is clean**

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_mindmaze pubspec.yaml
git commit -m "feat(mindmaze): scaffold encarta_mindmaze pure-Dart game-core package"
```

---

### Task 2: Question domain types

**Files:**
- Create: `packages/encarta_mindmaze/lib/src/question.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` (export)
- Test: `packages/encarta_mindmaze/test/question_test.dart`

**Interfaces:**
- Produces:
  - `AnswerChoice({required String text, required int articleRefid, required bool isCorrect})` — value type.
  - `Question({required int id, required int? area, required String clue, required List<AnswerChoice> choices})` — value type (list-aware `==`).

- [ ] **Step 1: Write the failing test**

`packages/encarta_mindmaze/test/question_test.dart`:

```dart
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

void main() {
  const choices = [
    AnswerChoice(text: 'Right', articleRefid: 1, isCorrect: true),
    AnswerChoice(text: 'Wrong', articleRefid: 2, isCorrect: false),
  ];

  test('AnswerChoice has value equality', () {
    const a = AnswerChoice(text: 'X', articleRefid: 1, isCorrect: true);
    const b = AnswerChoice(text: 'X', articleRefid: 1, isCorrect: true);
    const c = AnswerChoice(text: 'X', articleRefid: 1, isCorrect: false);
    expect(a, equals(b));
    expect(a, isNot(equals(c)));
  });

  test('Question equality compares choices element-wise', () {
    const q1 = Question(id: 1, area: 0, clue: 'c', choices: choices);
    const q2 = Question(id: 1, area: 0, clue: 'c', choices: choices);
    const q3 = Question(id: 1, area: 0, clue: 'c', choices: [
      AnswerChoice(text: 'Different', articleRefid: 1, isCorrect: true),
    ]);
    expect(q1, equals(q2));
    expect(q1, isNot(equals(q3)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/question_test.dart`
Expected: FAIL — `AnswerChoice`/`Question` are undefined.

- [ ] **Step 3: Implement**

`packages/encarta_mindmaze/lib/src/question.dart`:

```dart
/// One answer choice. Exactly one choice in a question is correct.
/// [articleRefid] joins article.refid for a later "learn more".
class AnswerChoice {
  const AnswerChoice({
    required this.text,
    required this.articleRefid,
    required this.isCorrect,
  });

  final String text;
  final int articleRefid;
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      other is AnswerChoice &&
      other.text == text &&
      other.articleRefid == articleRefid &&
      other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(text, articleRefid, isCorrect);
}

bool _choicesEqual(List<AnswerChoice> a, List<AnswerChoice> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A MindMaze question: a clue and its answer [choices] as presented
/// (already in display order). [id] is mm_question.id (the "seen" dedup key);
/// [area] is the castle wing 0–8, or null.
class Question {
  const Question({
    required this.id,
    required this.area,
    required this.clue,
    required this.choices,
  });

  final int id;
  final int? area;
  final String clue;
  final List<AnswerChoice> choices;

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.id == id &&
      other.area == area &&
      other.clue == clue &&
      _choicesEqual(other.choices, choices);

  @override
  int get hashCode => Object.hash(id, area, clue, choices.length);
}
```

- [ ] **Step 4: Export from the barrel**

In `lib/encarta_mindmaze.dart`, add below the sentinel:

```dart
export 'src/question.dart' show AnswerChoice, Question;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/question_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/question.dart lib/encarta_mindmaze.dart test/question_test.dart
git commit -m "feat(mindmaze): Question/AnswerChoice domain types"
```

---

### Task 3: Maze domain types

**Files:**
- Create: `packages/encarta_mindmaze/lib/src/maze.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` (export)
- Test: `packages/encarta_mindmaze/test/maze_test.dart`

**Interfaces:**
- Produces:
  - `enum Direction { left, right, tower, north, south }`
  - `Door({required Direction direction, required String targetRoomId})`
  - `Character({required String id, required String spriteSetId, required String greeting, required List<String> approve, required List<String> rebuff})`
  - `Room({required String id, required int area, required String backdropId, required Character character, required List<Door> doors})`
  - `MazeGraph({required Map<String, Room> rooms, required String startRoomId, required String goalRoomId})` with `Room room(String id)` (throws if absent) and `Room? doorTarget(String roomId, Direction d)`.

- [ ] **Step 1: Write the failing test**

`packages/encarta_mindmaze/test/maze_test.dart`:

```dart
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

const _char = Character(
  id: 'jester', spriteSetId: 'jester',
  greeting: 'hi', approve: ['nice'], rebuff: ['no'],
);

MazeGraph _twoRoomMaze() => MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'b',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.right, targetRoomId: 'b')]),
        'b': const Room(id: 'b', area: 1, backdropId: 'bookshlf', character: _char, doors: []),
      },
    );

void main() {
  test('room() returns the room, throws for an unknown id', () {
    final m = _twoRoomMaze();
    expect(m.room('a').area, 0);
    expect(() => m.room('nope'), throwsArgumentError);
  });

  test('doorTarget resolves a door and returns null for a missing door/room', () {
    final m = _twoRoomMaze();
    expect(m.doorTarget('a', Direction.right)!.id, 'b');
    expect(m.doorTarget('a', Direction.left), isNull);   // no such door
    expect(m.doorTarget('nope', Direction.right), isNull); // no such room
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/maze_test.dart`
Expected: FAIL — maze types undefined.

- [ ] **Step 3: Implement**

`packages/encarta_mindmaze/lib/src/maze.dart`:

```dart
/// Door directions (mirrors the recovered MindMaze door art: doorlt/doorrt/
/// doortow/ndoor/sdoor).
enum Direction { left, right, tower, north, south }

/// A one-way navigation edge from a room to [targetRoomId] via [direction].
class Door {
  const Door({required this.direction, required this.targetRoomId});
  final Direction direction;
  final String targetRoomId;
}

/// A castle character posing questions in a room. [spriteSetId] names the art
/// set (e.g. 'jester' → jester1..4). Banter lines are authored (reconstructed).
class Character {
  const Character({
    required this.id,
    required this.spriteSetId,
    required this.greeting,
    required this.approve,
    required this.rebuff,
  });
  final String id;
  final String spriteSetId;
  final String greeting;
  final List<String> approve;
  final List<String> rebuff;
}

/// A maze room: its question-pool [area], backdrop art, resident [character],
/// and outgoing [doors].
class Room {
  const Room({
    required this.id,
    required this.area,
    required this.backdropId,
    required this.character,
    required this.doors,
  });
  final String id;
  final int area;
  final String backdropId;
  final Character character;
  final List<Door> doors;
}

/// The castle graph: [rooms] keyed by id, with a [startRoomId] and [goalRoomId].
class MazeGraph {
  const MazeGraph({
    required this.rooms,
    required this.startRoomId,
    required this.goalRoomId,
  });
  final Map<String, Room> rooms;
  final String startRoomId;
  final String goalRoomId;

  /// The room for [id]; throws [ArgumentError] if it is not in the graph.
  Room room(String id) {
    final r = rooms[id];
    if (r == null) throw ArgumentError('no such room: $id');
    return r;
  }

  /// The room reached from [roomId] via a door in [d], or null if there is no
  /// such room or no such door.
  Room? doorTarget(String roomId, Direction d) {
    final r = rooms[roomId];
    if (r == null) return null;
    for (final door in r.doors) {
      if (door.direction == d) return rooms[door.targetRoomId];
    }
    return null;
  }
}
```

- [ ] **Step 4: Export from the barrel**

In `lib/encarta_mindmaze.dart`, add:

```dart
export 'src/maze.dart' show Direction, Door, Character, Room, MazeGraph;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/maze_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/maze.dart lib/encarta_mindmaze.dart test/maze_test.dart
git commit -m "feat(mindmaze): maze domain types (Direction/Door/Character/Room/MazeGraph)"
```

---

### Task 4: QuestionPicker

**Files:**
- Create: `packages/encarta_mindmaze/lib/src/question_picker.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` (export)
- Test: `packages/encarta_mindmaze/test/question_picker_test.dart`

**Interfaces:**
- Consumes: `Question`/`AnswerChoice` (Task 2).
- Produces: `QuestionPicker(Map<int, List<Question>> pools, Random random)` with `Question? pick(int area, Set<int> seen)`.

- [ ] **Step 1: Write the failing test**

`packages/encarta_mindmaze/test/question_picker_test.dart`:

```dart
import 'dart:math';

import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

Question _q(int id, {bool withCorrect = true}) => Question(
      id: id, area: 0, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'a', articleRefid: id * 10, isCorrect: withCorrect),
        const AnswerChoice(text: 'b', articleRefid: 1, isCorrect: false),
        const AnswerChoice(text: 'c', articleRefid: 2, isCorrect: false),
        const AnswerChoice(text: 'd', articleRefid: 3, isCorrect: false),
      ],
    );

void main() {
  test('picks only unseen questions until the pool is exhausted, then resets', () {
    final picker = QuestionPicker({0: [_q(1), _q(2), _q(3)]}, Random(1));
    final seen = <int>{};
    for (var i = 0; i < 3; i++) {
      final q = picker.pick(0, seen)!;
      expect(seen.contains(q.id), isFalse); // fresh each time
      seen.add(q.id);
    }
    expect(seen, {1, 2, 3});
    // Pool exhausted → reset, still returns a valid question (no soft-lock).
    final again = picker.pick(0, seen);
    expect(again, isNotNull);
  });

  test('shuffled choices always contain exactly one correct answer', () {
    final picker = QuestionPicker({0: [_q(1)]}, Random(7));
    final q = picker.pick(0, {})!;
    expect(q.choices.where((c) => c.isCorrect).length, 1);
    expect(q.choices, hasLength(4));
  });

  test('skips a malformed (no-correct) question; null for empty/absent area', () {
    final picker = QuestionPicker({0: [_q(1, withCorrect: false)], 1: []}, Random(1));
    expect(picker.pick(0, {}), isNull); // only question has no correct choice
    expect(picker.pick(1, {}), isNull); // empty pool
    expect(picker.pick(9, {}), isNull); // absent area
  });

  test('is deterministic under a fixed seed', () {
    List<int> run() {
      final p = QuestionPicker({0: [_q(1), _q(2), _q(3), _q(4)]}, Random(42));
      final seen = <int>{};
      final ids = <int>[];
      for (var i = 0; i < 4; i++) {
        final q = p.pick(0, seen)!;
        ids.add(q.id);
        seen.add(q.id);
      }
      return ids;
    }
    expect(run(), run());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/question_picker_test.dart`
Expected: FAIL — `QuestionPicker` undefined.

- [ ] **Step 3: Implement**

`packages/encarta_mindmaze/lib/src/question_picker.dart`:

```dart
import 'dart:math';

import 'question.dart';

/// Selects an unseen question for a room's area and shuffles its choices.
/// Pure given the injected [Random]; never soft-locks (resets when exhausted).
class QuestionPicker {
  QuestionPicker(this._pools, this._random);

  final Map<int, List<Question>> _pools;
  final Random _random;

  /// A question from [area] whose id is not in [seen], with freshly shuffled
  /// choices. If every valid question in the area is already seen, reuses the
  /// full valid pool (so play never stalls). Returns null only when the area
  /// has no question with exactly one correct choice.
  Question? pick(int area, Set<int> seen) {
    final pool = _pools[area];
    if (pool == null || pool.isEmpty) return null;
    final valid = pool.where(_hasOneCorrect).toList();
    if (valid.isEmpty) return null;
    var candidates = valid.where((q) => !seen.contains(q.id)).toList();
    if (candidates.isEmpty) candidates = valid; // reset: reuse full pool
    final chosen = candidates[_random.nextInt(candidates.length)];
    return _withShuffledChoices(chosen);
  }

  bool _hasOneCorrect(Question q) =>
      q.choices.where((c) => c.isCorrect).length == 1;

  Question _withShuffledChoices(Question q) {
    final shuffled = [...q.choices]..shuffle(_random);
    return Question(id: q.id, area: q.area, clue: q.clue, choices: shuffled);
  }
}
```

- [ ] **Step 4: Export from the barrel**

In `lib/encarta_mindmaze.dart`, add:

```dart
export 'src/question_picker.dart' show QuestionPicker;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/question_picker_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/question_picker.dart lib/encarta_mindmaze.dart test/question_picker_test.dart
git commit -m "feat(mindmaze): QuestionPicker (unseen selection + choice shuffle)"
```

---

### Task 5: GameConfig + GameSession state machine

**Files:**
- Create: `packages/encarta_mindmaze/lib/src/game_config.dart`
- Create: `packages/encarta_mindmaze/lib/src/game_session.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` (exports)
- Test: `packages/encarta_mindmaze/test/game_session_test.dart`

**Interfaces:**
- Consumes: `Question`, `MazeGraph`/`Room`/`Direction`/`Character` (Tasks 2–3), `QuestionPicker` (Task 4).
- Produces:
  - `GameConfig({int startingLives = 3, int pointsPerCorrect = 100})`.
  - `enum GameStatus { playing, won, lost }`.
  - `GameSnapshot` (immutable view: `currentRoomId`, `lives`, `score`, `currentQuestion` (`Question?`), `currentRoomCleared` (bool), `status`, `clearedRooms` (`Set<String>`), `lastCharacterLine` (`String?`)) with value equality.
  - `GameSession({required MazeGraph maze, required Map<int, List<Question>> pools, required GameConfig config, required Random random})` with `GameSnapshot get snapshot`, `void answer(int choiceIndex)`, `void move(Direction direction)`.

- [ ] **Step 1: Write the failing test**

`packages/encarta_mindmaze/test/game_session_test.dart`:

```dart
import 'dart:math';

import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

const _char = Character(
  id: 'c', spriteSetId: 'c',
  greeting: 'greet', approve: ['approve'], rebuff: ['rebuff'],
);

// start 'a' (area 0) --right--> goal 'b' (area 1)
MazeGraph _maze() => MazeGraph(
      startRoomId: 'a',
      goalRoomId: 'b',
      rooms: {
        'a': const Room(id: 'a', area: 0, backdropId: 'atrium', character: _char,
            doors: [Door(direction: Direction.right, targetRoomId: 'b')]),
        'b': const Room(id: 'b', area: 1, backdropId: 'bookshlf', character: _char,
            doors: [Door(direction: Direction.left, targetRoomId: 'a')]),
      },
    );

Question _q(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _pools() => {
      0: [_q(1, 0), _q(2, 0), _q(3, 0)],
      1: [_q(11, 1), _q(12, 1), _q(13, 1)],
    };

GameSession _session({GameConfig config = const GameConfig()}) =>
    GameSession(maze: _maze(), pools: _pools(), config: config, random: Random(1));

int _correctIndex(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect);
int _wrongIndex(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => !c.isCorrect);

void main() {
  test('starts in the start room with a question and a greeting', () {
    final s = _session();
    expect(s.snapshot.currentRoomId, 'a');
    expect(s.snapshot.currentQuestion, isNotNull);
    expect(s.snapshot.lives, 3);
    expect(s.snapshot.status, GameStatus.playing);
    expect(s.snapshot.lastCharacterLine, 'greet');
  });

  test('correct answer clears the room, adds score, and posts an approve line', () {
    final s = _session();
    s.answer(_correctIndex(s));
    expect(s.snapshot.currentRoomCleared, isTrue);
    expect(s.snapshot.score, 100);
    expect(s.snapshot.currentQuestion, isNull);
    expect(s.snapshot.lastCharacterLine, 'approve');
    expect(s.snapshot.status, GameStatus.playing); // 'a' is not the goal
  });

  test('wrong answer costs a life, posts a rebuff, and re-poses a fresh question', () {
    final s = _session();
    final firstId = s.snapshot.currentQuestion!.id;
    s.answer(_wrongIndex(s));
    expect(s.snapshot.lives, 2);
    expect(s.snapshot.lastCharacterLine, 'rebuff');
    expect(s.snapshot.currentQuestion, isNotNull);
    expect(s.snapshot.currentQuestion!.id, isNot(firstId)); // retry = different question
    expect(s.snapshot.currentRoomCleared, isFalse);
  });

  test('running out of lives ends the game as lost', () {
    final s = _session(config: const GameConfig(startingLives: 1));
    s.answer(_wrongIndex(s));
    expect(s.snapshot.lives, 0);
    expect(s.snapshot.status, GameStatus.lost);
    // further input is a no-op
    s.answer(0);
    s.move(Direction.right);
    expect(s.snapshot.status, GameStatus.lost);
  });

  test('move is blocked until the room is cleared', () {
    final s = _session();
    s.move(Direction.right); // room 'a' not cleared yet
    expect(s.snapshot.currentRoomId, 'a');
    s.answer(_correctIndex(s));
    s.move(Direction.right); // now allowed
    expect(s.snapshot.currentRoomId, 'b');
    expect(s.snapshot.currentQuestion, isNotNull); // goal room poses its question
  });

  test('clearing the goal room wins the game', () {
    final s = _session();
    s.answer(_correctIndex(s)); // clear 'a'
    s.move(Direction.right);    // enter goal 'b'
    expect(s.snapshot.status, GameStatus.playing); // walking in does not win
    s.answer(_correctIndex(s)); // answer the goal's question
    expect(s.snapshot.status, GameStatus.won);
    expect(s.snapshot.score, 200);
  });

  test('snapshot has value equality on a stable state', () {
    final s = _session();
    expect(s.snapshot, equals(s.snapshot));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/game_session_test.dart`
Expected: FAIL — `GameSession`/`GameConfig`/`GameSnapshot` undefined.

- [ ] **Step 3: Implement GameConfig**

`packages/encarta_mindmaze/lib/src/game_config.dart`:

```dart
/// Tunable game rules.
class GameConfig {
  const GameConfig({this.startingLives = 3, this.pointsPerCorrect = 100});
  final int startingLives;
  final int pointsPerCorrect;
}
```

- [ ] **Step 4: Implement GameSession + GameSnapshot**

`packages/encarta_mindmaze/lib/src/game_session.dart`:

```dart
import 'dart:math';

import 'game_config.dart';
import 'maze.dart';
import 'question.dart';
import 'question_picker.dart';

/// The high-level game state.
enum GameStatus { playing, won, lost }

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// An immutable view of the session for the UI to render / tests to assert.
class GameSnapshot {
  const GameSnapshot({
    required this.currentRoomId,
    required this.lives,
    required this.score,
    required this.currentQuestion,
    required this.currentRoomCleared,
    required this.status,
    required this.clearedRooms,
    required this.lastCharacterLine,
  });

  final String currentRoomId;
  final int lives;
  final int score;
  final Question? currentQuestion; // null once the room is cleared
  final bool currentRoomCleared;
  final GameStatus status;
  final Set<String> clearedRooms;
  final String? lastCharacterLine;

  @override
  bool operator ==(Object other) =>
      other is GameSnapshot &&
      other.currentRoomId == currentRoomId &&
      other.lives == lives &&
      other.score == score &&
      other.currentQuestion == currentQuestion &&
      other.currentRoomCleared == currentRoomCleared &&
      other.status == status &&
      _setEquals(other.clearedRooms, clearedRooms) &&
      other.lastCharacterLine == lastCharacterLine;

  @override
  int get hashCode => Object.hash(currentRoomId, lives, score, currentQuestion,
      currentRoomCleared, status, clearedRooms.length, lastCharacterLine);
}

/// The MindMaze game loop: lives + retry, reach & clear the goal room to win.
/// Pure and synchronous — every transition is a function of state + input +
/// the injected [Random].
class GameSession {
  GameSession({
    required MazeGraph maze,
    required Map<int, List<Question>> pools,
    required GameConfig config,
    required Random random,
  })  : _maze = maze,
        _config = config,
        _random = random,
        _picker = QuestionPicker(pools, random) {
    _lives = config.startingLives;
    _enterRoom(maze.startRoomId, greet: true);
  }

  final MazeGraph _maze;
  final GameConfig _config;
  final Random _random;
  final QuestionPicker _picker;

  late String _currentRoomId;
  late int _lives;
  int _score = 0;
  final Set<int> _seen = <int>{};
  final Set<String> _cleared = <String>{};
  Question? _currentQuestion;
  GameStatus _status = GameStatus.playing;
  String? _lastLine;

  GameSnapshot get snapshot => GameSnapshot(
        currentRoomId: _currentRoomId,
        lives: _lives,
        score: _score,
        currentQuestion: _currentQuestion,
        currentRoomCleared: _cleared.contains(_currentRoomId),
        status: _status,
        clearedRooms: Set<String>.unmodifiable(_cleared),
        lastCharacterLine: _lastLine,
      );

  /// Answer the current question by its index into `snapshot.currentQuestion.choices`.
  void answer(int choiceIndex) {
    if (_status != GameStatus.playing) return;
    final q = _currentQuestion;
    if (q == null) return; // room already cleared, nothing to answer
    if (choiceIndex < 0 || choiceIndex >= q.choices.length) return;
    final room = _maze.room(_currentRoomId);
    if (q.choices[choiceIndex].isCorrect) {
      _cleared.add(_currentRoomId);
      _score += _config.pointsPerCorrect;
      _currentQuestion = null;
      _lastLine = _line(room.character.approve);
      if (_currentRoomId == _maze.goalRoomId) _status = GameStatus.won;
    } else {
      _lives -= 1;
      _lastLine = _line(room.character.rebuff);
      if (_lives <= 0) {
        _lives = 0;
        _status = GameStatus.lost;
      } else {
        _poseQuestion(room); // retry with a fresh unseen question
      }
    }
  }

  /// Move through the door in [direction]; only allowed once the current room
  /// is cleared. Entering the goal room poses its question — winning happens in
  /// [answer], never on the move itself.
  void move(Direction direction) {
    if (_status != GameStatus.playing) return;
    if (!_cleared.contains(_currentRoomId)) return;
    final target = _maze.doorTarget(_currentRoomId, direction);
    if (target == null) return;
    _enterRoom(target.id);
  }

  void _enterRoom(String roomId, {bool greet = false}) {
    _currentRoomId = roomId;
    final room = _maze.room(roomId);
    if (greet) _lastLine = room.character.greeting;
    if (_cleared.contains(roomId)) {
      _currentQuestion = null;
      return;
    }
    _poseQuestion(room);
  }

  void _poseQuestion(Room room) {
    final q = _picker.pick(room.area, _seen);
    _currentQuestion = q;
    if (q != null) _seen.add(q.id);
  }

  String? _line(List<String> lines) =>
      lines.isEmpty ? null : lines[_random.nextInt(lines.length)];
}
```

- [ ] **Step 5: Export from the barrel**

In `lib/encarta_mindmaze.dart`, add:

```dart
export 'src/game_config.dart' show GameConfig;
export 'src/game_session.dart' show GameSession, GameStatus, GameSnapshot;
```

- [ ] **Step 6: Run test to verify it passes**

Run: `dart test test/game_session_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/src/game_config.dart lib/src/game_session.dart lib/encarta_mindmaze.dart test/game_session_test.dart
git commit -m "feat(mindmaze): GameSession state machine + GameConfig/GameSnapshot"
```

---

### Task 6: Minimal maze + full-playthrough integration tests

**Files:**
- Create: `packages/encarta_mindmaze/lib/src/minimal_maze.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` (export)
- Test: `packages/encarta_mindmaze/test/minimal_maze_test.dart`

**Interfaces:**
- Consumes: all prior types.
- Produces: `MazeGraph minimalMaze()` — a 5-room authored castle (areas 0 and 1), start `atrium`, goal `throne`, with at least one branch.

- [ ] **Step 1: Write the failing test**

`packages/encarta_mindmaze/test/minimal_maze_test.dart`:

```dart
import 'dart:math';

import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:test/test.dart';

// Synthetic pools big enough for a playthrough that never repeats a question.
Question _q(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _pools() => {
      0: [for (var i = 0; i < 10; i++) _q(i, 0)],
      1: [for (var i = 10; i < 20; i++) _q(i, 1)],
    };

Set<String> _reachable(MazeGraph m) {
  final seen = <String>{};
  final stack = [m.startRoomId];
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!seen.add(id)) continue;
    for (final d in m.room(id).doors) {
      stack.add(d.targetRoomId);
    }
  }
  return seen;
}

int _correct(GameSession s) =>
    s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect);

void main() {
  test('graph invariants: start/goal exist, doors resolve, no orphan rooms', () {
    final m = minimalMaze();
    expect(m.rooms.containsKey(m.startRoomId), isTrue);
    expect(m.rooms.containsKey(m.goalRoomId), isTrue);
    for (final room in m.rooms.values) {
      for (final door in room.doors) {
        expect(m.rooms.containsKey(door.targetRoomId), isTrue,
            reason: '${room.id} -> ${door.targetRoomId} must resolve');
      }
      expect(room.area == 0 || room.area == 1, isTrue);
    }
    expect(_reachable(m), equals(m.rooms.keys.toSet())); // every room reachable
  });

  test('a full correct playthrough reaches and clears the goal → won', () {
    final s = GameSession(
      maze: minimalMaze(), pools: _pools(),
      config: const GameConfig(), random: Random(3),
    );
    // Greedy: answer correctly, then step toward the goal via the first door
    // whose target is not yet cleared; bounded to avoid an infinite loop.
    for (var step = 0; step < 50 && s.snapshot.status == GameStatus.playing; step++) {
      if (s.snapshot.currentQuestion != null) {
        s.answer(_correct(s));
      } else {
        final room = minimalMaze().room(s.snapshot.currentRoomId);
        final next = room.doors.firstWhere(
          (d) => !s.snapshot.clearedRooms.contains(d.targetRoomId),
          orElse: () => room.doors.first,
        );
        s.move(next.direction);
      }
    }
    expect(s.snapshot.status, GameStatus.won);
  });

  test('always answering wrong ends in a loss', () {
    final s = GameSession(
      maze: minimalMaze(), pools: _pools(),
      config: const GameConfig(), random: Random(5),
    );
    for (var step = 0; step < 50 && s.snapshot.status == GameStatus.playing; step++) {
      final wrong = s.snapshot.currentQuestion!.choices.indexWhere((c) => !c.isCorrect);
      s.answer(wrong);
    }
    expect(s.snapshot.status, GameStatus.lost);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/minimal_maze_test.dart`
Expected: FAIL — `minimalMaze` undefined.

- [ ] **Step 3: Implement the minimal maze**

`packages/encarta_mindmaze/lib/src/minimal_maze.dart`:

```dart
import 'maze.dart';

// AUTHORED / RECONSTRUCTED CONTENT (not original Encarta data): this small
// castle, its room→character assignments, and all banter lines are hand-authored
// to exercise and showcase the engine. Backdrop/sprite ids reference real
// extracted MINDMAZE.EIT art names. The full 9-wing castle is a later effort.

const _jester = Character(
  id: 'jester', spriteSetId: 'jester',
  greeting: "Welcome, seeker! Answer true and the castle opens to you.",
  approve: ['Ha! Sharp as a tack.', 'The doors swing wide for a clever mind.'],
  rebuff: ['Tsk — think again, wanderer.', 'The stones themselves wince at that.'],
);

const _king = Character(
  id: 'king', spriteSetId: 'king',
  greeting: 'Prove your learning before my throne-ward halls.',
  approve: ['Well reasoned. Proceed.', 'A worthy answer.'],
  rebuff: ['A king expects better.', 'No. Try once more.'],
);

const _sorceres = Character(
  id: 'sorceres', spriteSetId: 'sorceres',
  greeting: 'The gallery guards its secrets. Do you know them?',
  approve: ['The runes glow in your favor.', 'Correct — the way clears.'],
  rebuff: ['The mist thickens against you.', 'Not so. Look deeper.'],
);

const _lady = Character(
  id: 'lady', spriteSetId: 'lady',
  greeting: 'One question stands between you and the tower stair.',
  approve: ['Gracefully done.', 'You may pass.'],
  rebuff: ['I fear not.', 'Consider again.'],
);

const _duke = Character(
  id: 'duke', spriteSetId: 'duke',
  greeting: 'The final test, here at the throne. Answer, and the castle is yours.',
  approve: ['The crown is won!', 'You have bested the maze.'],
  rebuff: ['So close — but no.', 'The throne is not yet yours.'],
);

/// A 5-room authored castle for testing + Phase 4. Start = atrium, goal = throne.
/// Layout (branch at the atrium):
///   atrium(0) --right--> library(1) --right--> hall(1) --tower--> throne(1, GOAL)
///   atrium(0) --tower--> gallery(0) --north--> hall(1)
MazeGraph minimalMaze() => const MazeGraph(
      startRoomId: 'atrium',
      goalRoomId: 'throne',
      rooms: {
        'atrium': Room(
          id: 'atrium', area: 0, backdropId: 'atrium', character: _jester,
          doors: [
            Door(direction: Direction.right, targetRoomId: 'library'),
            Door(direction: Direction.tower, targetRoomId: 'gallery'),
          ],
        ),
        'library': Room(
          id: 'library', area: 1, backdropId: 'bookshlf', character: _king,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'atrium'),
            Door(direction: Direction.right, targetRoomId: 'hall'),
          ],
        ),
        'gallery': Room(
          id: 'gallery', area: 0, backdropId: 'plnwalls', character: _sorceres,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'atrium'),
            Door(direction: Direction.north, targetRoomId: 'hall'),
          ],
        ),
        'hall': Room(
          id: 'hall', area: 1, backdropId: 'rmofdoor', character: _lady,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'library'),
            Door(direction: Direction.tower, targetRoomId: 'throne'),
          ],
        ),
        'throne': Room(
          id: 'throne', area: 1, backdropId: 'atrium', character: _duke,
          doors: [
            Door(direction: Direction.south, targetRoomId: 'hall'),
          ],
        ),
      },
    );
```

- [ ] **Step 4: Export from the barrel**

In `lib/encarta_mindmaze.dart`, add:

```dart
export 'src/minimal_maze.dart' show minimalMaze;
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `dart test test/minimal_maze_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the full package suite + analyze (no regressions)**

Run: `dart test`
Expected: all package tests pass (question, maze, picker, session, minimal-maze, scaffold).

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/src/minimal_maze.dart lib/encarta_mindmaze.dart test/minimal_maze_test.dart
git commit -m "feat(mindmaze): minimal authored maze + full-playthrough integration tests"
```

---

## Self-Review

**Spec coverage (against `2026-07-02-mindmaze-03-game-core-design.md`):**
- Pure-Dart package, zero Flutter/sqlite/encarta_data deps → Task 1 (pubspec has no runtime deps). ✓
- Own `Question`/`AnswerChoice` types → Task 2. ✓
- Maze model (`Direction`/`Door`/`Character`/`Room`/`MazeGraph` + `room()`/`doorTarget()`) → Task 3. ✓
- `QuestionPicker` (unseen selection, shuffle, reset-on-exhaust, skip-malformed, deterministic) → Task 4. ✓
- `GameConfig` + `GameStatus` + `GameSnapshot` (value equality) + `GameSession` (answer/move state machine, lives+retry, win on goal-clear, lose at 0 lives) → Task 5. ✓
- Minimal authored maze (5 rooms, 2 wings, branch, flagged reconstructed) + graph invariants + full win/lose playthroughs → Task 6. ✓
- Determinism via injected `Random`; never soft-locks → Tasks 4–5 (reset-on-exhaust) + seeded tests. ✓
- Authored content flagged reconstructed → Task 6 file-level comment. ✓

**Placeholder scan:** No TBD/TODO; every code step is complete. ✓

**Type consistency:** `Question`/`AnswerChoice` fields, `MazeGraph.room`/`doorTarget`, `QuestionPicker.pick(int, Set<int>)`, `GameSession({maze, pools, config, random})` + `answer`/`move`/`snapshot`, and `GameSnapshot` field names are used identically across Tasks 2→6; the barrel export list grows monotonically and matches each task's produced types. ✓

**Out of scope (later phases):** Flutter UI / sprite / audio (Phase 4+); full 9-wing castle content; DB loading (app maps `MindMazeQuestion → Question`); trophies/timers/hints; "learn more" navigation (the `articleRefid` is carried for later). ✓
