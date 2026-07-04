# MindMaze Phase 6 — Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add audio, animated sprites, authentic tap-to-chatter banter, a "Learn more" article link, and lives-based medal tiers to the MindMaze castle crawl — no gameplay-rule changes.

**Architecture:** Two tiny pure-engine additions (`answer()` returns an `AnswerOutcome?`; `Character` gains a `banter` list) drive a Flutter presentation layer: a `GameAudio` interface (real `media_kit` impl + silent fake) wired into `RoomView`, a frame-cycling sprite animator, a tappable character, a cleared-room "Learn more" button, and a tiered end screen. Assets stay on the existing dev-transcode flow.

**Tech Stack:** Dart (`encarta_mindmaze` pure package), Flutter (`encarta_reader` app), `media_kit` for audio, `package:image` (dev transcode tool), `sqlite3` (dev tools), `flutter_test` / `dart test`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-04-mindmaze-06-polish-design.md`. Branch: `mindmaze-polish` off `main` (already created).
- **Assets stay dev-transcode.** No app-bundle packaging. Art/audio derive into the gitignored `quarry/build/assets_derived/…` and load at runtime via `config.derivedDir`. Never commit derived binaries.
- **Never pump a real `Image.file` in `flutter_test`** — the async codec hangs ~10 min. Widget tests MUST use `const AssetConfig('/no/such/dir')` so `mindMazeArt` returns keyed placeholders (`mm-art-missing-<id>`), and assert widget **types / placeholder keys**, never real image decode.
- **`encarta_mindmaze` is pure Dart** — no Flutter, no `dart:io`, no I/O. Engine changes are logic-only and unit-tested with `dart test`.
- **Graceful degradation, never a red screen** — missing art → placeholder; missing/failed audio → silence; construction failure → the existing `mm-start-failed` message.
- TDD: write the failing test, watch it fail, minimal implementation, watch it pass, commit. One logical change per commit.
- Dev data dir: `/Users/nexus/projects/experiments/strata/quarry/build` (has `encarta.sqlite` + `assets/`).

---

## File Structure

- `packages/encarta_mindmaze/lib/src/game_session.dart` — add `AnswerOutcome` enum; `answer()` returns `AnswerOutcome?`. (T1)
- `packages/encarta_mindmaze/lib/src/maze.dart` — `Character.banter` field. (T1)
- `packages/encarta_mindmaze/lib/encarta_mindmaze.dart` — export `AnswerOutcome`. (T1)
- `packages/encarta_mindmaze/lib/src/minimal_maze.dart` — author banter on fixtures. (T5)
- `app/encarta_reader/lib/src/screens/mindmaze/game_audio.dart` — `GameSfx`, `GameAudio`, `SilentGameAudio`, `sfxAssetId`, `audioAssetPath`. (T2, new)
- `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_audio.dart` — `MindMazeAudio` (media_kit). (T2, new)
- `packages/encarta_assets/tool/copy_mindmaze_audio.dart` — dev audio copy tool. (T2, new)
- `packages/encarta_assets/tool/transcode_mindmaze_art.dart` — add multi-frame sprites. (T4)
- `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart` — `framesFor()`. (T4)
- `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart` — audio wiring, mute, animation, banter tap, learn-more, pass lives. (T3, T4, T5, T6, T7)
- `app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart` — carry banter into `mm.Character`. (T5)
- `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart` — build/dispose `MindMazeAudio`, pass `onOpenArticle`. (T3, T6)
- `app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart` — lives-based tier. (T7)

---

## Task 1: Engine — `AnswerOutcome` + `Character.banter`

**Files:**
- Modify: `packages/encarta_mindmaze/lib/src/game_session.dart`
- Modify: `packages/encarta_mindmaze/lib/src/maze.dart`
- Modify: `packages/encarta_mindmaze/lib/encarta_mindmaze.dart`
- Test: `packages/encarta_mindmaze/test/game_session_test.dart`, `packages/encarta_mindmaze/test/maze_test.dart`

**Interfaces:**
- Produces: `enum AnswerOutcome { correct, wrong, won, lost }`; `AnswerOutcome? GameSession.answer(int)`; `Character({..., List<String> banter = const []})` with `final List<String> banter`.

- [ ] **Step 1: Write the failing engine tests.** Append to `packages/encarta_mindmaze/test/game_session_test.dart` (inside `main()`):

```dart
group('answer() returns an outcome', () {
  // Reuse whatever minimal session helper this file already defines. If none,
  // build one over minimalMaze() with a pool per area exactly like
  // question_picker_test / room_view fixtures. Here we assume a helper
  // `GameSession session({int lives = 3})` exists; if not, inline construction.
  test('correct (non-goal) → AnswerOutcome.correct', () {
    final s = session();
    final q = s.snapshot.currentQuestion!;
    final correct = q.choices.indexWhere((c) => c.isCorrect);
    expect(s.answer(correct), AnswerOutcome.correct);
  });

  test('wrong (lives remain) → AnswerOutcome.wrong', () {
    final s = session();
    final q = s.snapshot.currentQuestion!;
    final wrong = q.choices.indexWhere((c) => !c.isCorrect);
    expect(s.answer(wrong), AnswerOutcome.wrong);
  });

  test('wrong at 1 life → AnswerOutcome.lost', () {
    final s = session(lives: 1);
    final q = s.snapshot.currentQuestion!;
    final wrong = q.choices.indexWhere((c) => !c.isCorrect);
    expect(s.answer(wrong), AnswerOutcome.lost);
    expect(s.snapshot.status, GameStatus.lost);
  });

  test('no-op (already-answered / game over) → null', () {
    final s = session();
    final q = s.snapshot.currentQuestion!;
    s.answer(q.choices.indexWhere((c) => c.isCorrect)); // clears room
    expect(s.answer(0), isNull); // currentQuestion is null now
  });
});
```

If this file has no `session(...)` helper, add one mirroring `test/room_view_test.dart`'s `_newGame` (minimalMaze + a pool per area of 10 posable questions + `Random(1)`). Add a goal-room win case too:

```dart
test('correct on the goal room → AnswerOutcome.won', () {
  final s = session();
  // Walk the known winning path over minimalMaze():
  const path = [Direction.right, Direction.right, Direction.tower];
  for (final d in path) {
    s.answer(s.snapshot.currentQuestion!.choices.indexWhere((c) => c.isCorrect));
    s.move(d);
  }
  final goalQ = s.snapshot.currentQuestion!;
  expect(s.answer(goalQ.choices.indexWhere((c) => c.isCorrect)), AnswerOutcome.won);
  expect(s.snapshot.status, GameStatus.won);
});
```

- [ ] **Step 2: Add the `Character.banter` test.** Append to `packages/encarta_mindmaze/test/maze_test.dart`:

```dart
test('Character.banter defaults to empty and round-trips', () {
  const a = Character(
      id: 'x', spriteSetId: 'x', greeting: 'g', approve: [], rebuff: []);
  expect(a.banter, isEmpty);
  const b = Character(
      id: 'y', spriteSetId: 'y', greeting: 'g', approve: [], rebuff: [],
      banter: ['one', 'two']);
  expect(b.banter, ['one', 'two']);
});
```

- [ ] **Step 3: Run the tests, verify they fail.**

Run: `cd packages/encarta_mindmaze && dart test test/game_session_test.dart test/maze_test.dart`
Expected: FAIL — `AnswerOutcome` undefined and/or `answer` returns void; `banter` not a parameter.

- [ ] **Step 4: Add `banter` to `Character`** in `maze.dart`:

```dart
class Character {
  const Character({
    required this.id,
    required this.spriteSetId,
    required this.greeting,
    required this.approve,
    required this.rebuff,
    this.banter = const [],
  });
  final String id;
  final String spriteSetId;
  final String greeting;
  final List<String> approve;
  final List<String> rebuff;

  /// Recovered per-character monologue lines (Phase 5a decode); shown via
  /// tap-to-chatter in the UI. Empty when a character has no recovered banter.
  final List<String> banter;
}
```

- [ ] **Step 5: Add `AnswerOutcome` and change `answer()`'s return** in `game_session.dart`. Add near `GameStatus`:

```dart
/// What a single [GameSession.answer] call did, for the UI's audio/feedback.
/// `won`/`lost` mean the answer also ended the game. `null` (not a member) is
/// returned when the call was a no-op (game already over, room already cleared,
/// or an out-of-range index).
enum AnswerOutcome { correct, wrong, won, lost }
```

Replace the whole `answer` method body's signature and returns:

```dart
AnswerOutcome? answer(int choiceIndex) {
  if (_status != GameStatus.playing) return null;
  final q = _currentQuestion;
  if (q == null) return null; // room already cleared, nothing to answer
  if (choiceIndex < 0 || choiceIndex >= q.choices.length) return null;
  final room = _maze.room(_currentRoomId);
  if (q.choices[choiceIndex].isCorrect) {
    _cleared.add(_currentRoomId);
    _score += _config.pointsPerCorrect;
    _currentQuestion = null;
    _lastLine = _line(room.character.approve);
    if (_currentRoomId == _maze.goalRoomId) {
      _status = GameStatus.won;
      return AnswerOutcome.won;
    }
    return AnswerOutcome.correct;
  } else {
    _lives -= 1;
    _lastLine = _line(room.character.rebuff);
    if (_lives <= 0) {
      _lives = 0;
      _status = GameStatus.lost;
      _currentQuestion = null;
      return AnswerOutcome.lost;
    }
    _poseQuestion(room, avoid: q.id); // retry with a fresh unseen question
    return AnswerOutcome.wrong;
  }
}
```

- [ ] **Step 6: Export `AnswerOutcome`** in `encarta_mindmaze.dart`:

```dart
export 'src/game_session.dart' show GameSession, GameStatus, GameSnapshot, AnswerOutcome;
```

- [ ] **Step 7: Run the whole package suite, verify green.**

Run: `cd packages/encarta_mindmaze && dart test`
Expected: PASS (existing 26 + new cases). The `void`→`AnswerOutcome?` change is source-compatible — existing callers that ignore the return still compile.

- [ ] **Step 8: Commit.**

```bash
git add packages/encarta_mindmaze
git commit -m "feat(mindmaze): answer() returns AnswerOutcome; Character.banter field"
```

---

## Task 2: Audio service — `GameAudio` interface, `MindMazeAudio`, dev copy tool

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/game_audio.dart`
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_audio.dart`
- Create: `packages/encarta_assets/tool/copy_mindmaze_audio.dart`
- Test: `app/encarta_reader/test/mindmaze/game_audio_test.dart`

**Interfaces:**
- Produces:
  - `enum GameSfx { correct, wrong, door }`
  - `abstract class GameAudio { void playSfx(GameSfx); void startBackground(); void setMuted(bool); bool get muted; void dispose(); }`
  - `class SilentGameAudio implements GameAudio` — `const SilentGameAudio()`, all no-ops, `muted == false`.
  - `String sfxAssetId(GameSfx sfx)` → `right|wrong|dooropen`.
  - `String audioAssetPath(AssetConfig config, String id, String ext)` → `<derivedDir>/mindmaze_audio/<id>.<ext>`.
  - `class MindMazeAudio implements GameAudio` — real media_kit impl.

- [ ] **Step 1: Write the failing test** at `app/encarta_reader/test/mindmaze/game_audio_test.dart`:

```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/game_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sfxAssetId maps each SFX to its extracted asset id', () {
    expect(sfxAssetId(GameSfx.correct), 'right');
    expect(sfxAssetId(GameSfx.wrong), 'wrong');
    expect(sfxAssetId(GameSfx.door), 'dooropen');
  });

  test('audioAssetPath resolves under derivedDir/mindmaze_audio', () {
    const config = AssetConfig('/data');
    expect(audioAssetPath(config, 'right', 'wav'),
        '/data/assets_derived/mindmaze_audio/right.wav');
    expect(audioAssetPath(config, 'BGLOOP1', 'mid'),
        '/data/assets_derived/mindmaze_audio/BGLOOP1.mid');
  });

  test('SilentGameAudio is a const no-op that never throws', () {
    const audio = SilentGameAudio();
    expect(audio.muted, isFalse);
    // None of these should throw or change observable state.
    audio.startBackground();
    audio.playSfx(GameSfx.correct);
    audio.setMuted(true);
    audio.dispose();
    expect(audio.muted, isFalse);
  });
}
```

- [ ] **Step 2: Run it, verify it fails.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/game_audio_test.dart`
Expected: FAIL — `game_audio.dart` does not exist.

- [ ] **Step 3: Create `game_audio.dart`:**

```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:path/path.dart' as p;

/// A one-shot game sound effect. Mapped to an extracted MINDMAZE.EIT asset id
/// by [sfxAssetId].
enum GameSfx { correct, wrong, door }

/// The extracted `.wav` asset id backing each SFX.
String sfxAssetId(GameSfx sfx) {
  switch (sfx) {
    case GameSfx.correct:
      return 'right';
    case GameSfx.wrong:
      return 'wrong';
    case GameSfx.door:
      return 'dooropen';
  }
}

/// Runtime path for a MindMaze audio asset copied by `copy_mindmaze_audio.dart`
/// into `<derivedDir>/mindmaze_audio/<id>.<ext>`.
String audioAssetPath(AssetConfig config, String id, String ext) =>
    p.join(config.derivedDir, 'mindmaze_audio', '$id.$ext');

/// Game-audio port: looping background + fire-and-forget SFX + mute. Implemented
/// for real by [MindMazeAudio] (media_kit) and stubbed by [SilentGameAudio].
abstract class GameAudio {
  void startBackground();
  void playSfx(GameSfx sfx);
  void setMuted(bool muted);
  bool get muted;
  void dispose();
}

/// A no-op [GameAudio] for tests and graceful fallback when playback can't init.
class SilentGameAudio implements GameAudio {
  const SilentGameAudio();
  @override
  void startBackground() {}
  @override
  void playSfx(GameSfx sfx) {}
  @override
  void setMuted(bool muted) {}
  @override
  bool get muted => false;
  @override
  void dispose() {}
}
```

- [ ] **Step 4: Run the test, verify green.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/game_audio_test.dart`
Expected: PASS.

- [ ] **Step 5: Create the real `MindMazeAudio`** at `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_audio.dart`. (No unit test — media_kit needs native libs; verified in the T8 manual play-through. It self-degrades to silence on any failure.)

```dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:media_kit/media_kit.dart';

import 'game_audio.dart';

/// Real game audio over media_kit. One looping background player (MIDI, falling
/// back to a looping ambience .wav if the .mid won't open) plus a short-lived
/// player per SFX. Every media call is guarded so a playback failure degrades to
/// silence rather than crashing the game. mpv is initialized at app bootstrap
/// (`MediaKit.ensureInitialized()`), so no per-instance init here.
class MindMazeAudio implements GameAudio {
  MindMazeAudio(this.config);

  final AssetConfig config;
  Player? _bg;
  bool _muted = false;
  bool _disposed = false;

  @override
  bool get muted => _muted;

  @override
  void startBackground() {
    if (_disposed || _bg != null) return;
    try {
      final bg = Player();
      _bg = bg;
      bg.setPlaylistMode(PlaylistMode.loop);
      _openBackground(bg);
    } catch (_) {
      _bg = null;
    }
  }

  Future<void> _openBackground(Player bg) async {
    final mid = File(audioAssetPath(config, 'BGLOOP1', 'mid'));
    final amb = File(audioAssetPath(config, 'amb1', 'wav'));
    // Prefer MIDI; if the file is absent or mpv fails to open it, fall back to a
    // looping ambience .wav so there is always background audio.
    try {
      if (mid.existsSync()) {
        await bg.open(Media(mid.path), play: !_muted);
        return;
      }
    } catch (_) {/* fall through to ambience */}
    try {
      if (amb.existsSync()) {
        await bg.open(Media(amb.path), play: !_muted);
      }
    } catch (_) {/* leave silent */}
  }

  @override
  void playSfx(GameSfx sfx) {
    if (_disposed || _muted) return;
    final file = File(audioAssetPath(config, sfxAssetId(sfx), 'wav'));
    if (!file.existsSync()) return;
    try {
      // A dedicated player per shot so overlapping SFX don't cut each other off;
      // dispose it once it finishes.
      final p = Player();
      p.stream.completed.listen((done) {
        if (done) p.dispose();
      });
      p.open(Media(file.path), play: true);
    } catch (_) {/* ignore */}
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    final bg = _bg;
    if (bg == null) return;
    try {
      if (muted) {
        bg.pause();
      } else {
        bg.play();
      }
    } catch (_) {/* ignore */}
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _bg?.dispose();
    } catch (_) {/* ignore */}
    _bg = null;
  }
}
```

- [ ] **Step 6: Create the dev copy tool** at `packages/encarta_assets/tool/copy_mindmaze_audio.dart`:

```dart
// One-time dev tool: copies the MindMaze audio referenced by Phase 6 from the
// content-addressed extraction into assets_derived/mindmaze_audio/<id>.<ext>
// (friendly names the app resolves at runtime). Run once locally:
//   dart run tool/copy_mindmaze_audio.dart
// Output is under the gitignored quarry build dir, so nothing is committed.
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

// Background music (MIDI) + ambience fallback + the wired SFX.
const _ids = <String>[
  'BGLOOP1', 'BGLOOP2', 'BGLOOP3', // MIDI loops (BGLOOP1 used; 2/3 available)
  'amb1', // ambience fallback if MIDI won't play
  'right', 'wrong', 'dooropen', // SFX
];

void main() {
  final db = sqlite3.open('$_dataDir/encarta.sqlite', mode: OpenMode.readOnly);
  final outDir = Directory('$_dataDir/assets_derived/mindmaze_audio')
    ..createSync(recursive: true);

  for (final id in _ids) {
    final rows = db.select(
      "SELECT path, ext FROM asset WHERE source='MINDMAZE.EIT' AND baggage_id=?",
      [id],
    );
    if (rows.isEmpty) {
      stderr.writeln('SKIP $id: no asset row');
      continue;
    }
    final src = File('$_dataDir/assets/${rows.first['path']}');
    if (!src.existsSync()) {
      stderr.writeln('SKIP $id: file missing ${src.path}');
      continue;
    }
    // ext column includes the leading dot (e.g. ".wav"); strip it.
    final ext = (rows.first['ext'] as String).replaceFirst('.', '');
    final out = File('${outDir.path}/$id.$ext');
    out.writeAsBytesSync(src.readAsBytesSync());
    stdout.writeln('wrote ${out.path}');
  }
  db.dispose();
}
```

- [ ] **Step 7: Run the copy tool once and eyeball output** (populates the runtime dir used later):

Run: `cd packages/encarta_assets && dart run tool/copy_mindmaze_audio.dart`
Expected: `wrote …/mindmaze_audio/BGLOOP1.mid`, `…/amb1.wav`, `…/right.wav`, `…/wrong.wav`, `…/dooropen.wav` (BGLOOP2/3 too). No `SKIP` for `right`/`wrong`/`dooropen`/`amb1`/`BGLOOP1`.

- [ ] **Step 8: Run the audio unit test again + analyze, commit.**

```bash
cd app/encarta_reader && flutter test test/mindmaze/game_audio_test.dart && flutter analyze lib/src/screens/mindmaze/mindmaze_audio.dart lib/src/screens/mindmaze/game_audio.dart
git add app/encarta_reader/lib/src/screens/mindmaze/game_audio.dart app/encarta_reader/lib/src/screens/mindmaze/mindmaze_audio.dart app/encarta_reader/test/mindmaze/game_audio_test.dart packages/encarta_assets/tool/copy_mindmaze_audio.dart
git commit -m "feat(mindmaze): GameAudio port + media_kit impl + dev audio copy tool"
```

---

## Task 3: Wire audio into `RoomView` + `MindMazePage`

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart`
- Test: `app/encarta_reader/test/mindmaze/room_view_test.dart`

**Interfaces:**
- Consumes: `AnswerOutcome` (T1), `GameAudio`/`GameSfx`/`SilentGameAudio` (T2).
- Produces: `RoomView({..., GameAudio audio = const SilentGameAudio()})`; a `mm-mute` HUD button.

- [ ] **Step 1: Add a recording fake + failing tests.** At the top of `room_view_test.dart`, add imports and a fake:

```dart
import 'package:encarta_reader/src/screens/mindmaze/game_audio.dart';

class _RecordingAudio implements GameAudio {
  final List<GameSfx> sfx = [];
  int backgroundStarts = 0;
  bool _muted = false;
  @override
  void startBackground() => backgroundStarts++;
  @override
  void playSfx(GameSfx s) => sfx.add(s);
  @override
  void setMuted(bool m) => _muted = m;
  @override
  bool get muted => _muted;
  @override
  void dispose() {}
}
```

Update `_app` to accept and pass an audio (default a fresh recorder is fine per call), then add tests inside `main()`:

```dart
testWidgets('starts background music on entry and plays SFX on outcomes',
    (tester) async {
  final audio = _RecordingAudio();
  await tester.pumpWidget(MaterialApp(
    home: RoomView(
      newGame: _newGame,
      maze: minimalMaze(),
      config: const AssetConfig('/no/such/dir'),
      audio: audio,
    ),
  ));
  await tester.pump();
  expect(audio.backgroundStarts, 1);

  await tester.tap(_wrongAnswerFinder(tester));
  await tester.pump();
  expect(audio.sfx, contains(GameSfx.wrong));

  await tester.tap(_correctAnswerFinder(tester));
  await tester.pump();
  expect(audio.sfx, contains(GameSfx.correct));

  await tester.tap(find.byKey(const ValueKey('mm-door-right')));
  await tester.pump();
  expect(audio.sfx, contains(GameSfx.door));
});

testWidgets('mute button toggles audio mute', (tester) async {
  final audio = _RecordingAudio();
  await tester.pumpWidget(MaterialApp(
    home: RoomView(
      newGame: _newGame,
      maze: minimalMaze(),
      config: const AssetConfig('/no/such/dir'),
      audio: audio,
    ),
  ));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('mm-mute')));
  await tester.pump();
  expect(audio.muted, isTrue);
});
```

- [ ] **Step 2: Run, verify failure.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart`
Expected: FAIL — `RoomView` has no `audio` param; no `mm-mute` key.

- [ ] **Step 3: Add the `audio` field + mute state** to `RoomView` in `room_view.dart`. Add the import `import 'game_audio.dart';`, add the constructor param and field:

```dart
  const RoomView({
    super.key,
    required this.newGame,
    required this.maze,
    required this.config,
    this.audio = const SilentGameAudio(),
  });

  final GameSession Function() newGame;
  final MazeGraph maze;
  final AssetConfig config;
  final GameAudio audio;
```

In `_RoomViewState` add `bool _muted = false;` and start background after a successful `_start()` in `initState`:

```dart
  @override
  void initState() {
    super.initState();
    _start();
    if (!_startFailed) widget.audio.startBackground();
  }
```

- [ ] **Step 4: Fire SFX from `_answer` and `_move`.** Replace `_answer`/`_move`:

```dart
  void _answer(int i) {
    final outcome = _session.answer(i);
    if (outcome == AnswerOutcome.correct || outcome == AnswerOutcome.won) {
      widget.audio.playSfx(GameSfx.correct);
    } else if (outcome == AnswerOutcome.wrong || outcome == AnswerOutcome.lost) {
      widget.audio.playSfx(GameSfx.wrong);
    }
    setState(() {});
  }

  void _move(Direction d) {
    widget.audio.playSfx(GameSfx.door);
    setState(() => _session.move(d));
  }
```

- [ ] **Step 5: Add the mute button to the HUD.** In `_hud`, add a leading/ trailing `IconButton` (place it in the first `Row` or as a new HUD element). Simplest: wrap the score `Flexible` row — instead, add an `IconButton` at the end of the HUD `Row`'s children is awkward with `spaceBetween`; put the mute control inside the lives `Row`:

```dart
            Row(
              key: const ValueKey('mm-lives'),
              children: [
                IconButton(
                  key: const ValueKey('mm-mute'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white54),
                  onPressed: () => setState(() {
                    _muted = !_muted;
                    widget.audio.setMuted(_muted);
                  }),
                ),
                for (var i = 0; i < snap.lives; i++)
                  const Icon(Icons.favorite, color: Color(0xFFE0557A), size: 18),
                const SizedBox(width: 8),
                Text('${snap.lives}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
```

- [ ] **Step 6: Run the RoomView suite, verify green.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart`
Expected: PASS (existing + new).

- [ ] **Step 7: Build & pass a real audio into `MindMazePage`.** In `mindmaze_page.dart`, add imports for `game_audio.dart` + `mindmaze_audio.dart`, hold the audio on the state, and dispose it:

```dart
class _MindMazePageState extends State<MindMazePage> {
  Future<_Loaded?>? _future;
  GameAudio? _audio;

  GameAudio _audioFor(AssetConfig config) {
    // Guard construction: in headless tests (or if mpv fails) fall back to
    // silence instead of throwing.
    if (_audio != null) return _audio!;
    try {
      _audio = MindMazeAudio(config);
    } catch (_) {
      _audio = const SilentGameAudio();
    }
    return _audio!;
  }

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }
```

Then in `build`, after computing `config`, pass it:

```dart
        final config = scope.assets?.config ?? const AssetConfig.defaultConfig();
        return RoomView(
          maze: loaded.maze,
          config: config,
          audio: _audioFor(config),
          newGame: () => mm.GameSession(
            maze: loaded.maze,
            pools: loaded.pools,
            config: const mm.GameConfig(),
            random: Random(),
          ),
        );
```

- [ ] **Step 8: Run app analyze + full mindmaze test dir, commit.**

```bash
cd app/encarta_reader && flutter test test/mindmaze && flutter analyze lib/src/screens/mindmaze
git add app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart app/encarta_reader/test/mindmaze/room_view_test.dart
git commit -m "feat(mindmaze): wire game audio (SFX, background, mute) into RoomView"
```

---

## Task 4: Multi-frame sprite animation

**Files:**
- Modify: `packages/encarta_assets/tool/transcode_mindmaze_art.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Test: `app/encarta_reader/test/mindmaze/mindmaze_art_test.dart`, `app/encarta_reader/test/mindmaze/room_view_test.dart`

**Interfaces:**
- Produces: `List<String> framesFor(String spriteSetId)`; `RoomView` cycles frames on a ~400ms timer.

- [ ] **Step 1: Write the failing `framesFor` test.** Append to `app/encarta_reader/test/mindmaze/mindmaze_art_test.dart`:

```dart
import 'package:encarta_reader/src/screens/mindmaze/mindmaze_art.dart';

void main() {
  test('framesFor returns all frames of a multi-frame set, in order', () {
    expect(framesFor('jester'), ['jester1', 'jester2', 'jester3', 'jester4']);
    expect(framesFor('duke'), ['duke1', 'duke2', 'duke3']);
  });
  test('framesFor returns a single frame for single-frame sets', () {
    expect(framesFor('king'), ['king1']);
    expect(framesFor('parrot'), ['parrot']);
  });
  test('framesFor falls back to the id itself for unknown sets', () {
    expect(framesFor('nope'), ['nope']);
  });
}
```

(If the file already has a `void main()`, merge these into it rather than adding a second.)

- [ ] **Step 2: Run, verify failure.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: FAIL — `framesFor` undefined.

- [ ] **Step 3: Add `framesFor`** to `mindmaze_art.dart`. Replace the `_spriteFrame` map + `spriteFrameFor` with:

```dart
// Ordered transcoded frames per character sprite set. Multi-frame sets animate
// (Phase 6); single-frame sets render statically. Frame ids match the extracted
// .dib names transcoded by tool/transcode_mindmaze_art.dart.
const _spriteFrames = <String, List<String>>{
  'jester': ['jester1', 'jester2', 'jester3', 'jester4'],
  'duke': ['duke1', 'duke2', 'duke3'],
  'suitarm': ['suitarm1', 'suitarm2'], // guard
  'secnldy': ['secnldy1', 'secnldy2'], // lady
  'servant': ['servant1', 'servant2'],
  'king': ['king1'],
  'sorceres': ['sorceres'],
  'alchem': ['alchem'],
  'asiantra': ['asiantra'], // merchant
  'parrot': ['parrot'],
  'maninst': ['maninst'], // prisoner
};

/// The ordered transcoded frame ids for a character [spriteSetId]; a single
/// element for static sets, or `[spriteSetId]` if the set is unknown.
List<String> framesFor(String spriteSetId) =>
    _spriteFrames[spriteSetId] ?? [spriteSetId];
```

- [ ] **Step 4: Run the art test, verify green.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing animation test.** Append to `room_view_test.dart` (uses the placeholder-key trick: art dir is `/no/such/dir`, so each frame renders as `mm-art-missing-<frameId>`):

```dart
testWidgets('the character sprite cycles frames over time', (tester) async {
  await tester.pumpWidget(_app()); // atrium → jester (4 frames)
  await tester.pump();
  expect(find.byKey(const ValueKey('mm-art-missing-jester1')), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('mm-art-missing-jester2')), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('mm-art-missing-jester3')), findsOneWidget);
});
```

- [ ] **Step 6: Run, verify failure.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart --plain-name 'cycles frames'`
Expected: FAIL — sprite is static (`jester1` never advances).

- [ ] **Step 7: Add the frame timer to `RoomView`.** In `room_view.dart` add `import 'dart:async';`. In `_RoomViewState` add a field + lifecycle:

```dart
  Timer? _spriteTimer;
  int _frame = 0;
```

In `initState`, after the background start, drive the animation:

```dart
    _spriteTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _frame++);
    });
```

Add `dispose`:

```dart
  @override
  void dispose() {
    _spriteTimer?.cancel();
    super.dispose();
  }
```

Update `_scene` to render the current frame:

```dart
  Widget _scene(Room room) {
    final frames = framesFor(room.character.spriteSetId);
    final frameId = frames[_frame % frames.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        mindMazeArt(widget.config, room.backdropId, fit: BoxFit.cover),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.8,
            child: mindMazeArt(widget.config, frameId, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 8: Run the RoomView suite, verify green** (the timer is cancelled on dispose, so no "pending timer" failure).

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart`
Expected: PASS.

- [ ] **Step 9: Add multi-frame ids to the transcode tool.** In `transcode_mindmaze_art.dart` replace `_sprites`:

```dart
const _sprites = [
  // multi-frame sets (animated in Phase 6)
  'jester1', 'jester2', 'jester3', 'jester4',
  'duke1', 'duke2', 'duke3',
  'suitarm1', 'suitarm2',
  'secnldy1', 'secnldy2',
  'servant1', 'servant2',
  // single-frame sets
  'king1', 'sorceres', 'alchem', 'asiantra', 'parrot', 'maninst',
];
```

- [ ] **Step 10: Re-run the transcode tool + commit.**

```bash
cd packages/encarta_assets && dart run tool/transcode_mindmaze_art.dart
```
Expected: `wrote …/jester2.png` … `jester4.png`, `duke2/3`, `suitarm2`, `secnldy2`, `servant2` (plus the existing ones). Any `SKIP` means that `.dib` frame isn't in the corpus — note it; the runtime degrades that frame to a placeholder but animation still cycles.

```bash
git add packages/encarta_assets/tool/transcode_mindmaze_art.dart app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/test/mindmaze/mindmaze_art_test.dart app/encarta_reader/test/mindmaze/room_view_test.dart
git commit -m "feat(mindmaze): animate multi-frame character sprites"
```

---

## Task 5: Authentic banter — tap to chatter

**Files:**
- Modify: `packages/encarta_mindmaze/lib/src/minimal_maze.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Test: `packages/encarta_mindmaze/test/minimal_maze_test.dart` (optional touch), `app/encarta_reader/test/mindmaze/room_view_test.dart`, `app/encarta_reader/test/mindmaze/castle_adapter_test.dart`

**Interfaces:**
- Consumes: `Character.banter` (T1), `MindMazeCharacter.banter` (existing).
- Produces: a `mm-character-tap` gesture target and a `mm-banter` line in `RoomView`; `castleToMaze` fills `Character.banter`.

- [ ] **Step 1: Author banter on the `minimalMaze` jester** so the fixture (used by RoomView tests + the Phase-4 fallback) has tappable banter. In `minimal_maze.dart`, add a `banter:` to `_jester`:

```dart
const _jester = Character(
  id: 'jester', spriteSetId: 'jester',
  greeting: "Welcome, seeker! Answer true and the castle opens to you.",
  approve: ['Ha! Sharp as a tack.', 'The doors swing wide for a clever mind.'],
  rebuff: ['Tsk — think again, wanderer.', 'The stones themselves wince at that.'],
  banter: [
    'Hee hee! The walls have ears, you know.',
    'Riddle me this, or riddle me that!',
  ],
);
```

- [ ] **Step 2: Write the failing banter tap test.** Append to `room_view_test.dart`:

```dart
testWidgets('tapping the character cycles its banter lines', (tester) async {
  await tester.pumpWidget(_app()); // atrium jester has banter
  await tester.pump();
  expect(find.byKey(const ValueKey('mm-banter')), findsNothing);
  await tester.tap(find.byKey(const ValueKey('mm-character-tap')));
  await tester.pump();
  expect(find.byKey(const ValueKey('mm-banter')), findsOneWidget);
  expect(find.text('Hee hee! The walls have ears, you know.'), findsOneWidget);
  // Next tap advances to the second line.
  await tester.tap(find.byKey(const ValueKey('mm-character-tap')));
  await tester.pump();
  expect(find.text('Riddle me this, or riddle me that!'), findsOneWidget);
});
```

- [ ] **Step 3: Write the failing adapter test.** Append to `app/encarta_reader/test/mindmaze/castle_adapter_test.dart` (a `MindMazeCharacter` now carries banter; assert it reaches `mm.Character.banter`). Mirror the fixture style already in that file — one character with `banter: ['b1']`, one room referencing it, then:

```dart
  test('castleToMaze carries character banter through', () {
    final castle = data.MindMazeCastle(
      characters: [
        const data.MindMazeCharacter(
            id: 'jester', spriteSet: 'jester', greeting: 'hi', banter: ['b1', 'b2']),
      ],
      rooms: [
        const data.MindMazeRoom(
            id: 'atrium', area: 0, backdropId: 'atrium',
            characterId: 'jester', isGoal: false),
        const data.MindMazeRoom(
            id: 'throne', area: 0, backdropId: 'atrium',
            characterId: 'jester', isGoal: true),
      ],
      doors: const [
        data.MindMazeDoor(roomId: 'atrium', direction: 'right', targetRoomId: 'throne'),
      ],
    );
    final maze = castleToMaze(castle);
    expect(maze.room('atrium').character.banter, ['b1', 'b2']);
  });
```

(Match the exact constructor argument order/names this test file already uses; the snippet above uses the real `MindMazeCastle`/`MindMazeRoom`/`MindMazeDoor`/`MindMazeCharacter` signatures.)

- [ ] **Step 4: Run both, verify failure.**

Run:
```
cd packages/encarta_mindmaze && dart test test/minimal_maze_test.dart
cd ../../app/encarta_reader && flutter test test/mindmaze/room_view_test.dart test/mindmaze/castle_adapter_test.dart
```
Expected: adapter test FAILS (banter not carried); room_view banter test FAILS (no `mm-character-tap`). `minimal_maze_test` may still pass — that step just adds data.

- [ ] **Step 5: Carry banter in the adapter.** In `castle_adapter.dart`, in the `mm.Character(...)` built inside the room loop, add:

```dart
      character: mm.Character(
        id: r.characterId,
        spriteSetId: c?.spriteSet ?? r.characterId,
        greeting: c?.greeting ?? '',
        approve: _genericApprove,
        rebuff: _genericRebuff,
        banter: c?.banter ?? const [],
      ),
```

- [ ] **Step 6: Add tap-to-chatter to `RoomView`.** Add state to `_RoomViewState`:

```dart
  String? _banterLine;
  int _banterIdx = 0;
  String _banterRoom = '';
```

Add the handler:

```dart
  void _tapCharacter(Room room) {
    final banter = room.character.banter;
    if (banter.isEmpty) return;
    setState(() {
      if (_banterRoom != room.id) {
        _banterRoom = room.id;
        _banterIdx = 0;
      } else {
        _banterIdx = (_banterIdx + 1) % banter.length;
      }
      _banterLine = banter[_banterIdx];
    });
  }
```

Wrap the sprite in `_scene` with a `GestureDetector`:

```dart
          child: GestureDetector(
            key: const ValueKey('mm-character-tap'),
            onTap: () => _tapCharacter(room),
            child: mindMazeArt(widget.config, frameId, fit: BoxFit.contain),
          ),
```

In `_dialogPanel`, after the `lastCharacterLine` block, show the banter line only for the current room (a room change makes `_banterRoom != currentRoomId`, hiding a stale line):

```dart
    if (_banterLine != null && _banterRoom == snap.currentRoomId) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(_banterLine!,
            key: const ValueKey('mm-banter'),
            style: const TextStyle(
                color: Colors.white70, fontStyle: FontStyle.italic)),
      ));
    }
```

- [ ] **Step 7: Run the suites, verify green.**

Run:
```
cd packages/encarta_mindmaze && dart test
cd ../../app/encarta_reader && flutter test test/mindmaze
```
Expected: PASS.

- [ ] **Step 8: Commit.**

```bash
git add packages/encarta_mindmaze/lib/src/minimal_maze.dart app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/test/mindmaze/room_view_test.dart app/encarta_reader/test/mindmaze/castle_adapter_test.dart
git commit -m "feat(mindmaze): tap-to-chatter authentic character banter"
```

---

## Task 6: "Learn more" article link

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart`
- Test: `app/encarta_reader/test/mindmaze/room_view_test.dart`

**Interfaces:**
- Produces: `RoomView({..., void Function(int refid)? onOpenArticle})`; a `mm-learn-more` button shown on a cleared room.
- Consumes: `AnswerChoice.articleRefid` (existing), `AppNavigator.openArticle` (existing).

- [ ] **Step 1: Write the failing test.** Append to `room_view_test.dart`:

```dart
testWidgets('cleared room shows Learn more → opens the correct answer article',
    (tester) async {
  int? opened;
  await tester.pumpWidget(MaterialApp(
    home: RoomView(
      newGame: _newGame,
      maze: minimalMaze(),
      config: const AssetConfig('/no/such/dir'),
      onOpenArticle: (refid) => opened = refid,
    ),
  ));
  await tester.pump();
  // Capture the correct choice's refid from the posed question before answering.
  final correctBtn = _correctAnswerFinder(tester);
  await tester.tap(correctBtn);
  await tester.pump();
  expect(find.byKey(const ValueKey('mm-learn-more')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('mm-learn-more')));
  await tester.pump();
  // _q() sets the correct choice's articleRefid == its question id (>= 0).
  expect(opened, isNotNull);
  expect(opened! >= 0, isTrue);
});

testWidgets('no Learn more when onOpenArticle is not provided', (tester) async {
  await tester.pumpWidget(_app()); // default: onOpenArticle == null
  await tester.pump();
  await tester.tap(_correctAnswerFinder(tester));
  await tester.pump();
  expect(find.byKey(const ValueKey('mm-learn-more')), findsNothing);
});
```

- [ ] **Step 2: Run, verify failure.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart --plain-name 'Learn more'`
Expected: FAIL — no `onOpenArticle` param / no `mm-learn-more`.

- [ ] **Step 3: Add the callback + captured refid to `RoomView`.** Add the constructor param + field:

```dart
    this.onOpenArticle,
  });
  ...
  final void Function(int refid)? onOpenArticle;
```

Add state `int? _learnMoreRefid;`. Capture the correct refid in `_answer` (the question is still on the snapshot before `answer()` nulls it), and clear it on move:

```dart
  void _answer(int i) {
    final q = _session.snapshot.currentQuestion;
    final outcome = _session.answer(i);
    if (outcome == AnswerOutcome.correct || outcome == AnswerOutcome.won) {
      widget.audio.playSfx(GameSfx.correct);
      _learnMoreRefid =
          q?.choices.firstWhere((c) => c.isCorrect).articleRefid;
    } else if (outcome == AnswerOutcome.wrong || outcome == AnswerOutcome.lost) {
      widget.audio.playSfx(GameSfx.wrong);
    }
    setState(() {});
  }

  void _move(Direction d) {
    widget.audio.playSfx(GameSfx.door);
    _learnMoreRefid = null;
    setState(() => _session.move(d));
  }
```

- [ ] **Step 4: Render the Learn more button** in `_dialogPanel`'s cleared branch (`else if (snap.currentRoomCleared)`), before the door buttons:

```dart
      } else if (snap.currentRoomCleared) {
        if (widget.onOpenArticle != null && _learnMoreRefid != null) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: TextButton.icon(
              key: const ValueKey('mm-learn-more'),
              icon: const Icon(Icons.menu_book, size: 18),
              label: const Text('Learn more'),
              onPressed: () => widget.onOpenArticle!(_learnMoreRefid!),
            ),
          ));
        }
        for (final door in room.doors) {
          // …existing door buttons…
```

- [ ] **Step 5: Run, verify green.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/room_view_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire the page's navigator.** In `mindmaze_page.dart` `build`, pass:

```dart
        return RoomView(
          maze: loaded.maze,
          config: config,
          audio: _audioFor(config),
          onOpenArticle: (refid) => scope.navigator.openArticle(refid),
          newGame: () => mm.GameSession(
```

- [ ] **Step 7: Analyze + commit.**

```bash
cd app/encarta_reader && flutter test test/mindmaze && flutter analyze lib/src/screens/mindmaze
git add app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart app/encarta_reader/test/mindmaze/room_view_test.dart
git commit -m "feat(mindmaze): Learn more link opens the answer's article"
```

---

## Task 7: Lives-based medal tiers on the end screen

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Test: `app/encarta_reader/test/mindmaze/end_screen_test.dart`

**Interfaces:**
- Produces: `MindMazeEndScreen({..., required int livesRemaining})`; per-tier art + rank + keys `mm-medal-gold|silver|bronze`.
- Consumes: `GameSnapshot.lives` (existing).

- [ ] **Step 1: Write the failing test.** Append to `end_screen_test.dart` (keep the existing `AssetConfig('/no/such/dir')` guard so art → placeholder, never a real `Image.file`):

```dart
Widget _end(int lives) => MaterialApp(
      home: Scaffold(
        body: MindMazeEndScreen(
          config: const AssetConfig('/no/such/dir'),
          score: 500,
          livesRemaining: lives,
          onPlayAgain: () {},
        ),
      ),
    );

void main() {
  testWidgets('3 lives → gold: trophy + Master Scholar rank', (tester) async {
    await tester.pumpWidget(_end(3));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-gold')), findsOneWidget);
    expect(find.text('Master Scholar Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-trophy')), findsOneWidget);
  });

  testWidgets('2 lives → silver medal', (tester) async {
    await tester.pumpWidget(_end(2));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-silver')), findsOneWidget);
    expect(find.text('Scholar Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-medal')), findsOneWidget);
  });

  testWidgets('1 life → bronze ribbon', (tester) async {
    await tester.pumpWidget(_end(1));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-medal-bronze')), findsOneWidget);
    expect(find.text('Apprentice Of MindMaze'), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-ribbon')), findsOneWidget);
  });
}
```

(If `end_screen_test.dart` already has a `main()`/helper, merge these in and update the existing `MindMazeEndScreen(...)` construction to pass `livesRemaining`.)

- [ ] **Step 2: Run, verify failure.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/end_screen_test.dart`
Expected: FAIL — no `livesRemaining` param / no `mm-medal-*` keys.

- [ ] **Step 3: Add the tier logic** to `end_screen.dart`. Replace the `const _rank`/`const _blurb` region with a tier model + selector, and add the field:

```dart
/// A win-tier keyed to lives remaining: art id + authored rank label.
class _Tier {
  const _Tier(this.key, this.artId, this.rank);
  final String key;
  final String artId;
  final String rank;
}

// 3+ lives → gold (authentic top rank); 2 → silver; 1 → bronze.
_Tier _tierForLives(int lives) {
  if (lives >= 3) {
    return const _Tier('mm-medal-gold', 'trophy', 'Master Scholar Of MindMaze');
  }
  if (lives == 2) {
    return const _Tier('mm-medal-silver', 'medal', 'Scholar Of MindMaze');
  }
  return const _Tier('mm-medal-bronze', 'ribbon', 'Apprentice Of MindMaze');
}

const _blurb = "Zorlock's curse is broken. The throne room opens, and the "
    'castle is yours.';
```

Add `required this.livesRemaining` to the constructor and `final int livesRemaining;`. In `build`, compute `final tier = _tierForLives(livesRemaining);` and replace the trophy art + rank text:

```dart
                  SizedBox(
                    height: 120,
                    key: ValueKey(tier.key),
                    child: mindMazeArt(config, tier.artId, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  const Text('You have won the castle!',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(tier.rank,
                      style: const TextStyle(
                          color: Color(0xFFF2D06B),
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
```

(The `mm-won` key stays on the outer `SizedBox.expand`. The tier key goes on the art `SizedBox`.)

- [ ] **Step 4: Pass lives from `RoomView`.** In `room_view.dart`, update the win-branch:

```dart
            if (snap.status == GameStatus.won)
              MindMazeEndScreen(
                config: widget.config,
                score: snap.score,
                livesRemaining: snap.lives,
                onPlayAgain: _restart,
              ),
```

- [ ] **Step 5: Run the end-screen + room-view suites, verify green.**

Run: `cd app/encarta_reader && flutter test test/mindmaze/end_screen_test.dart test/mindmaze/room_view_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/test/mindmaze/end_screen_test.dart
git commit -m "feat(mindmaze): lives-based gold/silver/bronze end-screen medals"
```

---

## Task 8: Gate — dev transcode, full suites, macOS live play-through, PR

**Files:** none (build/verify/ship).

- [ ] **Step 1: Re-run both dev asset tools** (idempotent; populates every new sprite frame + audio file the runtime loads):

```bash
cd packages/encarta_assets
dart run tool/transcode_mindmaze_art.dart
dart run tool/copy_mindmaze_audio.dart
```
Expected: sprite frames + audio written; note any `SKIP` (a missing source frame degrades to a placeholder but never crashes).

- [ ] **Step 2: Engine package suite green.**

Run: `cd packages/encarta_mindmaze && dart test`
Expected: PASS (all cases).

- [ ] **Step 3: Data package suite green** (no changes expected there, but banter path is exercised):

Run: `cd packages/encarta_data && dart test`
Expected: PASS.

- [ ] **Step 4: App suite green.**

Run: `cd app/encarta_reader && flutter test`
Expected: PASS (no hangs — every widget test uses `/no/such/dir` art).

- [ ] **Step 5: App analyze clean.**

Run: `cd app/encarta_reader && flutter analyze`
Expected: No issues (or only pre-existing baseline).

- [ ] **Step 6: macOS build.**

Run: `cd app/encarta_reader && flutter build macos --debug`
Expected: build succeeds.

- [ ] **Step 7: Manual live play-through (macOS).** Launch the app, open **Play MindMaze**, and confirm by observation:
  - Background audio plays on entry; the **mute** button silences/restores it.
  - Answering **right**/**wrong** plays the right/wrong SFX; moving through a **door** plays the door SFX.
  - The character sprite **animates** (jester/duke/guard/lady/servant cycle frames).
  - **Tapping the character** cycles authentic banter lines under the greeting.
  - A cleared room shows **Learn more**, and tapping it opens the answer's article (then navigate back into the game).
  - Win with 3 / 2 / 1 lives shows the **gold / silver / bronze** medal + rank on the end screen.
  - Note in the PR body whether the `.mid` background played or the ambience fallback was used.

- [ ] **Step 8: Open the PR** to reader `main` once the play-through passes:

```bash
git push -u origin mindmaze-polish
gh pr create --repo strata-works/reader --base main --head mindmaze-polish \
  --title "MindMaze Phase 6: polish (audio, animation, banter, learn-more, medals)" \
  --body "Implements the Phase 6 polish spec (docs/superpowers/specs/2026-07-04-mindmaze-06-polish-design.md): game audio (SFX + looping background w/ MIDI→ambience fallback + mute), multi-frame sprite animation, tap-to-chatter authentic banter, a Learn-more article link, and lives-based gold/silver/bronze end-screen medals. Engine gains AnswerOutcome + Character.banter (pure, unit-tested). Assets stay on the dev-transcode flow. Live play-through confirmed on macOS."
```

---

## Self-Review

**Spec coverage:**
- Audio (music + ambience fallback + SFX + mute) → T2 (service), T3 (wiring). ✓
- Multi-frame sprite animation → T4. ✓
- Authentic banter (greeting + tap-to-chatter) → T5 (adapter + tap UI); greeting unchanged. ✓
- Learn more → T6. ✓
- Lives-based medal tiers → T7. ✓
- Engine additions (`AnswerOutcome`, `Character.banter`) → T1. ✓
- Dev-transcode asset flow (art frames + audio copy) → T2 (copy tool), T4 (frame ids), T8 (run both). ✓
- Graceful degradation (missing art/audio, construction failure) → SilentGameAudio fallback (T2/T3), placeholder art (existing), `mm-start-failed` (existing). ✓
- `Image.file` hang guard → every widget test uses `/no/such/dir`; assertions on placeholder keys/types. ✓

**Deviations from the spec (intentional, minor):**
- `GameSfx` drops the `knock`-on-entry sound — movement already triggers `dooropen`, and a separate knock adds an unwired enum value / awkward door+knock overlap. `door`/`correct`/`wrong` cover the felt events. (Noted here so it isn't read as an omission.)
- Background is a single `BGLOOP1`→`amb1` loop started once (the spec permitted "a single BGLOOP is acceptable if per-area proves fiddly").

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every test step shows the assertion. ✓

**Type consistency:** `AnswerOutcome?` return used identically in T1/T3/T6; `GameAudio`/`GameSfx`/`SilentGameAudio` names consistent across T2/T3; `framesFor` signature consistent T4; `MindMazeEndScreen.livesRemaining` consistent T7; `onOpenArticle` (`void Function(int)`) consistent T6. `RoomView` gains params with defaults (`audio = const SilentGameAudio()`, `onOpenArticle` nullable) so existing tests keep compiling. ✓
