# MindMaze Phase 4 — Playable Room UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter `/mindmaze` screen that drives the Phase-3 `GameSession` over `minimalMaze()` — render a room (backdrop + character sprite + clue + answer buttons + lives/score), answer, walk through doors, and win or lose.

**Architecture:** A build-time tool transcodes MindMaze `.dib → assets_derived/mindmaze/<id>.png` (sprites keyed cyan→alpha, backdrops opaque). In the app, a pure pool-loader + question adapter feed a `GameSession`; a `RoomView` `StatefulWidget` renders its `GameSnapshot` and forwards `answer`/`move`. Reuses `AppScope`, `AssetConfig.derivedDir`, auto_route, and the degradation pattern.

**Tech Stack:** Flutter (macOS), `package:image` (dev-dep, tool only), auto_route, `package:test`/`flutter_test`. Reader pub workspace.

## Global Constraints

- **No `DibShim`/`EncartaImage` for MindMaze art.** MindMaze `.dib` are already-BM (the shim prepends a header and corrupts them); load derived PNGs directly via `Image.file`.
- **Art is generated, not committed:** the tool writes PNGs into the gitignored `<dataDir>/assets_derived/mindmaze/`. No test depends on the real transcoded art.
- **`image` is a dev-dependency of `encarta_assets`** (tool + its test only) — never a runtime dep. The pure conversion core lives under `tool/` and is imported by the test via a relative path.
- **Engine is authoritative:** all rules/state live in `GameSession`; widgets only render `GameSnapshot` and forward `answer(int)` / `move(Direction)`. No game logic in widgets.
- **Cyan key = RGB (0,255,255).** Sprites keyed; backdrops never keyed.
- **Areas used by `minimalMaze()` are `0` and `1`.** The loader loads exactly those pools.
- **Graceful degradation:** art miss → labeled placeholder; DB/questions absent → a centered message; never a red screen (match the app's existing page pattern).
- **Deterministic tests:** widget tests construct `GameSession` directly with synthetic pools + `minimalMaze()` + a seeded `Random`; runtime uses `Random()`.
- **Commands** run from `reader/` root (`flutter test <path>`, `dart run build_runner build` in the app package) unless noted. Widget/app tests use `flutter test`; the `encarta_assets` transcode-core test uses `flutter test` too (it's a Flutter package).

---

### Task 1: Sprite/backdrop transcode tool (encarta_assets)

**Files:**
- Modify: `packages/encarta_assets/pubspec.yaml` (add dev-dep `image`)
- Create: `packages/encarta_assets/tool/mindmaze_transcode_core.dart` (pure conversion)
- Create: `packages/encarta_assets/tool/transcode_mindmaze_art.dart` (CLI wiring)
- Test: `packages/encarta_assets/test/mindmaze_transcode_test.dart`

**Interfaces:**
- Produces: `Uint8List keyCyanToPng(Uint8List dibBytes, {required bool key})` — decodes the image, (if `key`) makes every RGB (0,255,255) pixel transparent, and returns PNG bytes.

- [ ] **Step 1: Add the dev-dep**

In `packages/encarta_assets/pubspec.yaml`, under `dev_dependencies:`, add:

```yaml
  image: ^4.3.0
```

Run (from `reader/`): `dart pub get`. Expected: resolves, `image` available.

- [ ] **Step 2: Write the failing test**

`packages/encarta_assets/test/mindmaze_transcode_test.dart`:

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

import '../tool/mindmaze_transcode_core.dart';

void main() {
  test('keyed: cyan pixels become transparent, others stay opaque', () {
    final src = img.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 0, 255, 255) // cyan key
      ..setPixelRgb(1, 0, 10, 20, 30); // ordinary
    final bmp = Uint8List.fromList(img.encodeBmp(src));

    final png = keyCyanToPng(bmp, key: true);
    final out = img.decodePng(png)!;

    expect(out.getPixel(0, 0).a, 0, reason: 'cyan → transparent');
    expect(out.getPixel(1, 0).a, 255, reason: 'non-cyan → opaque');
  });

  test('not keyed: cyan stays fully opaque (backdrop)', () {
    final src = img.Image(width: 1, height: 1)..setPixelRgb(0, 0, 0, 255, 255);
    final png = keyCyanToPng(Uint8List.fromList(img.encodeBmp(src)), key: false);
    final out = img.decodePng(png)!;
    expect(out.getPixel(0, 0).a, 255);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test packages/encarta_assets/test/mindmaze_transcode_test.dart`
Expected: FAIL — `mindmaze_transcode_core.dart` / `keyCyanToPng` not found.

- [ ] **Step 4: Implement the pure core**

`packages/encarta_assets/tool/mindmaze_transcode_core.dart`:

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes [dibBytes] (a MindMaze BMP/DIB) and returns PNG bytes. When [key] is
/// true, every pixel equal to the sprite cyan key (RGB 0,255,255) is made fully
/// transparent so the sprite composites cleanly over a room backdrop; all other
/// pixels stay opaque. Backdrops pass `key: false` and stay fully opaque.
Uint8List keyCyanToPng(Uint8List dibBytes, {required bool key}) {
  final decoded = img.decodeImage(dibBytes);
  if (decoded == null) {
    throw ArgumentError('could not decode MindMaze image');
  }
  final image = decoded.convert(numChannels: 4); // ensure an alpha channel
  if (key) {
    for (final p in image) {
      if (p.r == 0 && p.g == 255 && p.b == 255) {
        p.a = 0;
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test packages/encarta_assets/test/mindmaze_transcode_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Write the CLI wiring**

`packages/encarta_assets/tool/transcode_mindmaze_art.dart`:

```dart
// One-time tool: transcodes the MindMaze art referenced by minimalMaze() from
// the extracted .dib into assets_derived/mindmaze/<id>.png. Sprites get their
// cyan key turned transparent; backdrops stay opaque. Run once locally:
//   dart run tool/transcode_mindmaze_art.dart
// (the output dir is under the gitignored quarry build dir, so PNGs are not
// committed; packaging them with the app is Phase 6.)
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'mindmaze_transcode_core.dart';

const _sprites = ['jester1', 'king1', 'sorceres', 'lady1', 'duke1'];
const _backdrops = ['atrium', 'bookshlf', 'plnwalls', 'rmofdoor'];

const _dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

void main() {
  final db = sqlite3.open('$_dataDir/encarta.sqlite', mode: OpenMode.readOnly);
  final outDir = Directory('$_dataDir/assets_derived/mindmaze')
    ..createSync(recursive: true);

  void run(String id, {required bool key}) {
    final rows = db.select(
      "SELECT path FROM asset WHERE source='MINDMAZE.EIT' AND baggage_id=?",
      [id],
    );
    if (rows.isEmpty) {
      stderr.writeln('SKIP $id: no asset row');
      return;
    }
    final src = File('$_dataDir/assets/${rows.first['path']}');
    if (!src.existsSync()) {
      stderr.writeln('SKIP $id: file missing ${src.path}');
      return;
    }
    final out = File('${outDir.path}/$id.png');
    out.writeAsBytesSync(keyCyanToPng(src.readAsBytesSync(), key: key));
    stdout.writeln('wrote ${out.path}');
  }

  for (final id in _sprites) {
    run(id, key: true);
  }
  for (final id in _backdrops) {
    run(id, key: false);
  }
  db.dispose();
}
```

- [ ] **Step 7: Commit**

```bash
git add packages/encarta_assets/pubspec.yaml packages/encarta_assets/tool/mindmaze_transcode_core.dart packages/encarta_assets/tool/transcode_mindmaze_art.dart packages/encarta_assets/test/mindmaze_transcode_test.dart
git commit -m "feat(assets): MindMaze art transcode tool (cyan→alpha sprites, opaque backdrops)"
```

---

### Task 2: App dependency + question adapter

**Files:**
- Modify: `app/encarta_reader/pubspec.yaml` (path dep `encarta_mindmaze`)
- Create: `app/encarta_reader/lib/src/screens/mindmaze/question_adapter.dart`
- Test: `app/encarta_reader/test/mindmaze/question_adapter_test.dart`

**Interfaces:**
- Produces: `mm.Question toGameQuestion(data.MindMazeQuestion q)` (mapping `encarta_data`'s `MindMazeQuestion` → `encarta_mindmaze`'s `Question`).

- [ ] **Step 1: Add the path dependency**

In `app/encarta_reader/pubspec.yaml`, under `dependencies:`, add:

```yaml
  encarta_mindmaze:
    path: ../../packages/encarta_mindmaze
```

Run (from `reader/`): `dart pub get`. Expected: resolves.

- [ ] **Step 2: Write the failing test**

`app/encarta_reader/test/mindmaze/question_adapter_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:encarta_reader/src/screens/mindmaze/question_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toGameQuestion maps id/area/clue and every choice, preserving order', () {
    const q = data.MindMazeQuestion(
      id: 7, area: 1, clue: 'A clue',
      answers: [
        data.MindMazeAnswer(ordinal: 0, text: 'Right', articleRefid: 100, isCorrect: true),
        data.MindMazeAnswer(ordinal: 1, text: 'Wrong', articleRefid: 200, isCorrect: false),
      ],
    );
    final g = toGameQuestion(q);
    expect(g, isA<mm.Question>());
    expect(g.id, 7);
    expect(g.area, 1);
    expect(g.clue, 'A clue');
    expect(g.choices.map((c) => c.text).toList(), ['Right', 'Wrong']);
    expect(g.choices[0].isCorrect, isTrue);
    expect(g.choices[0].articleRefid, 100);
    expect(g.choices[1].isCorrect, isFalse);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/mindmaze/question_adapter_test.dart` (from `app/encarta_reader`)
Expected: FAIL — `question_adapter.dart` / `toGameQuestion` not found.

- [ ] **Step 4: Implement**

`app/encarta_reader/lib/src/screens/mindmaze/question_adapter.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

/// Maps the data-layer [data.MindMazeQuestion] to the game engine's
/// [mm.Question]. Choice order is preserved (the engine shuffles later).
mm.Question toGameQuestion(data.MindMazeQuestion q) => mm.Question(
      id: q.id,
      area: q.area,
      clue: q.clue,
      choices: [
        for (final a in q.answers)
          mm.AnswerChoice(
            text: a.text,
            articleRefid: a.articleRefid,
            isCorrect: a.isCorrect,
          ),
      ],
    );
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/mindmaze/question_adapter_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add app/encarta_reader/pubspec.yaml app/encarta_reader/lib/src/screens/mindmaze/question_adapter.dart app/encarta_reader/test/mindmaze/question_adapter_test.dart
git commit -m "feat(app): encarta_mindmaze dep + MindMazeQuestion→Question adapter"
```

---

### Task 3: MindMaze art loader + sprite-frame map

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart`
- Test: `app/encarta_reader/test/mindmaze/mindmaze_art_test.dart`

**Interfaces:**
- Consumes: `AssetConfig` (from `encarta_assets`).
- Produces:
  - `Widget mindMazeArt(AssetConfig config, String id, {BoxFit fit})` — renders `<config.derivedDir>/mindmaze/<id>.png` via `Image.file`, or a labeled placeholder (keyed `ValueKey('mm-art-missing-<id>')`) when the file is absent.
  - `String spriteFrameFor(String spriteSetId)` — the representative transcoded frame for a character sprite set.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/mindmaze/mindmaze_art_test.dart`:

```dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/mindmaze_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unit-level (no pumpWidget): assert the RETURNED widget type. Do NOT pump
  // Image.file — its real async codec never settles under flutter_test and
  // hangs the test to a 10-minute timeout.

  test('missing derived PNG → labeled placeholder container (not an Image)', () {
    final w = mindMazeArt(const AssetConfig('/no/such/dir'), 'atrium');
    expect(w, isA<Container>());
    expect((w as Container).key, const ValueKey('mm-art-missing-atrium'));
  });

  test('present derived PNG → an Image widget', () {
    final dir = Directory.systemTemp.createTempSync('mmart');
    File('${dir.path}/assets_derived/mindmaze/atrium.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0, 1, 2, 3]); // content need not decode; assert the type
    final w = mindMazeArt(AssetConfig(dir.path), 'atrium');
    expect(w, isA<Image>());
    dir.deleteSync(recursive: true);
  });

  test('spriteFrameFor maps set ids to representative frames', () {
    expect(spriteFrameFor('jester'), 'jester1');
    expect(spriteFrameFor('king'), 'king1');
    expect(spriteFrameFor('sorceres'), 'sorceres');
    expect(spriteFrameFor('unknown'), 'unknown'); // fallback: id itself
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: FAIL — `mindmaze_art.dart` not found.

- [ ] **Step 3: Implement**

`app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart`:

```dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

/// Renders a MindMaze art asset by [id] from the transcoded derived PNG
/// (`<config.derivedDir>/mindmaze/<id>.png`). Shows a labeled placeholder when
/// the PNG is absent or fails to decode — never blocks play. Does NOT use the
/// reader's DibShim/EncartaImage (MindMaze .dib are already-BM and load as
/// derived PNGs here).
Widget mindMazeArt(AssetConfig config, String id, {BoxFit fit = BoxFit.contain}) {
  final file = File('${config.derivedDir}/mindmaze/$id.png');
  if (!file.existsSync()) return _placeholder(id);
  return Image.file(file, fit: fit, errorBuilder: (_, __, ___) => _placeholder(id));
}

Widget _placeholder(String id) => Container(
      key: ValueKey('mm-art-missing-$id'),
      color: const Color(0xFF23202B),
      alignment: Alignment.center,
      child: Text(
        id,
        style: const TextStyle(color: Color(0xFF8A8398), fontSize: 10),
      ),
    );

// One representative transcoded frame per character sprite set (Phase 4 uses a
// single frame; multi-frame animation is Phase 6).
const _spriteFrame = <String, String>{
  'jester': 'jester1',
  'king': 'king1',
  'sorceres': 'sorceres',
  'lady': 'lady1',
  'duke': 'duke1',
};

/// The transcoded frame id for a character [spriteSetId]; falls back to the id
/// itself if the set is unknown.
String spriteFrameFor(String spriteSetId) => _spriteFrame[spriteSetId] ?? spriteSetId;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart app/encarta_reader/test/mindmaze/mindmaze_art_test.dart
git commit -m "feat(app): MindMaze art loader (derived PNG + placeholder) + sprite-frame map"
```

---

### Task 4: RoomView — the playable room widget

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`
- Test: `app/encarta_reader/test/mindmaze/room_view_test.dart`

**Interfaces:**
- Consumes: `GameSession`/`GameStatus`/`Direction`/`MazeGraph`/`minimalMaze` (`encarta_mindmaze`); `AssetConfig` (`encarta_assets`); `mindMazeArt`/`spriteFrameFor` (Task 3).
- Produces: `RoomView({required GameSession Function() newGame, required MazeGraph maze, required AssetConfig config})` — a `StatefulWidget` that owns a `GameSession` (built via `newGame`, rebuilt on restart), renders its snapshot, and forwards `answer`/`move`.

Widget keys (for tests): answer buttons `ValueKey('mm-answer-<i>')`; door buttons `ValueKey('mm-door-<direction>')`; lives row `ValueKey('mm-lives')`; win overlay `ValueKey('mm-won')`; lose overlay `ValueKey('mm-lost')`; restart button `ValueKey('mm-restart')`.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/mindmaze/room_view_test.dart`:

```dart
import 'dart:math';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:encarta_reader/src/screens/mindmaze/room_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(int id, int area) => Question(
      id: id, area: area, clue: 'clue $id',
      choices: [
        AnswerChoice(text: 'correct-$id', articleRefid: id, isCorrect: true),
        const AnswerChoice(text: 'w1', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w2', articleRefid: 0, isCorrect: false),
        const AnswerChoice(text: 'w3', articleRefid: 0, isCorrect: false),
      ],
    );

Map<int, List<Question>> _pools() => {
      0: [for (var i = 0; i < 10; i++) _q(i, 0)],
      1: [for (var i = 10; i < 20; i++) _q(i, 1)],
    };

GameSession _newGame({int lives = 3}) => GameSession(
      maze: minimalMaze(),
      pools: _pools(),
      config: GameConfig(startingLives: lives),
      random: Random(1),
    );

Widget _app({int lives = 3}) => MaterialApp(
      home: RoomView(
        newGame: () => _newGame(lives: lives),
        maze: minimalMaze(),
        config: const AssetConfig('/no/such/dir'), // art → placeholders
      ),
    );

void main() {
  testWidgets('renders the clue and one answer button per choice', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.textContaining('clue '), findsWidgets);
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-answer-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-lives')), findsOneWidget);
  });

  testWidgets('correct answer clears the room → door buttons replace answers', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // Tap whichever answer is correct.
    await tester.tap(_correctAnswerFinder(tester));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-answer-0')), findsNothing);
    // atrium has doors right→library and tower→gallery
    expect(
      find.byKey(const ValueKey('mm-door-right')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('mm-door-tower')).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('wrong answer removes a life and re-poses a question', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_wrongAnswerFinder(tester));
    await tester.pump();
    // still answering (not cleared), and an answer button is present again
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
    // 3 → 2 hearts: assert the lives row reports 2 (see _RoomViewState renders count)
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('draining lives shows the lose overlay; Try again resets', (tester) async {
    await tester.pumpWidget(_app(lives: 1));
    await tester.pump();
    await tester.tap(_wrongAnswerFinder(tester));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-lost')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mm-restart')));
    await tester.pump();
    expect(find.byKey(const ValueKey('mm-lost')), findsNothing);
    expect(find.byKey(const ValueKey('mm-answer-0')), findsOneWidget);
  });

  testWidgets('answering through to the goal shows the win overlay', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // Greedy loop: answer correctly, then step toward an uncleared neighbor.
    for (var step = 0; step < 40; step++) {
      if (find.byKey(const ValueKey('mm-won')).evaluate().isNotEmpty) break;
      final correct = _correctAnswerFinder(tester);
      if (correct.evaluate().isNotEmpty) {
        await tester.tap(correct);
        await tester.pump();
        continue;
      }
      // room cleared — tap the first available door
      final door = find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${w.key}'.contains('mm-door-'),
      );
      if (door.evaluate().isEmpty) break;
      await tester.tap(door.first);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('mm-won')), findsOneWidget);
  });
}

// Helpers that locate the correct/wrong answer button by the label convention.
Finder _correctAnswerFinder(WidgetTester tester) =>
    find.byWidgetPredicate((w) =>
        w is FilledButton &&
        w.child is Text &&
        (w.child as Text).data != null &&
        (w.child as Text).data!.startsWith('correct-'));

Finder _wrongAnswerFinder(WidgetTester tester) =>
    find.byWidgetPredicate((w) =>
        w is FilledButton &&
        w.child is Text &&
        (w.child as Text).data == 'w1');
```

(Note: the plan's RoomView renders each answer as a `FilledButton` whose `child` is a `Text(choice.text)` and whose `key` is `ValueKey('mm-answer-<i>')` — both the key finders and the label finders above rely on that.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmaze/room_view_test.dart`
Expected: FAIL — `room_view.dart` / `RoomView` not found.

- [ ] **Step 3: Implement**

`app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`:

```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:flutter/material.dart';

import 'mindmaze_art.dart';

/// Renders and drives a MindMaze [GameSession] over [maze]. Owns the session
/// (built via [newGame], rebuilt on restart); every interaction mutates the
/// session then setState, and the whole view re-derives from the new snapshot.
class RoomView extends StatefulWidget {
  const RoomView({
    super.key,
    required this.newGame,
    required this.maze,
    required this.config,
  });

  final GameSession Function() newGame;
  final MazeGraph maze;
  final AssetConfig config;

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  late GameSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.newGame();
  }

  void _answer(int i) => setState(() => _session.answer(i));
  void _move(Direction d) => setState(() => _session.move(d));
  void _restart() => setState(() => _session = widget.newGame());

  String _directionLabel(Direction d) {
    switch (d) {
      case Direction.left:
        return '← Left';
      case Direction.right:
        return 'Right →';
      case Direction.tower:
        return '↑ Tower';
      case Direction.north:
        return '↑ North';
      case Direction.south:
        return '↓ South';
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _session.snapshot;
    final room = widget.maze.room(snap.currentRoomId);

    return Scaffold(
      backgroundColor: const Color(0xFF141018),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _hud(snap, room),
                Expanded(child: _scene(room)),
                _dialogPanel(snap, room),
              ],
            ),
            if (snap.status == GameStatus.won)
              _overlay(
                key: const ValueKey('mm-won'),
                title: "You've won the castle!",
                subtitle: 'Final score: ${snap.score}',
                buttonLabel: 'Play again',
              ),
            if (snap.status == GameStatus.lost)
              _overlay(
                key: const ValueKey('mm-lost'),
                title: 'Out of lives',
                subtitle: 'Score: ${snap.score}',
                buttonLabel: 'Try again',
              ),
          ],
        ),
      ),
    );
  }

  Widget _hud(GameSnapshot snap, Room room) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              key: const ValueKey('mm-lives'),
              children: [
                for (var i = 0; i < snap.lives; i++)
                  const Icon(Icons.favorite, color: Color(0xFFE0557A), size: 18),
                const SizedBox(width: 8),
                Text('${snap.lives}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Text('Score ${snap.score}',
                style: const TextStyle(color: Colors.white)),
            Text(room.character.id,
                style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );

  Widget _scene(Room room) => Stack(
        fit: StackFit.expand,
        children: [
          mindMazeArt(widget.config, room.backdropId, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.8,
              child: mindMazeArt(
                widget.config,
                spriteFrameFor(room.character.spriteSetId),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );

  Widget _dialogPanel(GameSnapshot snap, Room room) {
    final children = <Widget>[];
    if (snap.lastCharacterLine != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(snap.lastCharacterLine!,
            style: const TextStyle(
                color: Colors.white, fontStyle: FontStyle.italic)),
      ));
    }
    final q = snap.currentQuestion;
    if (q != null) {
      children.add(Text(q.clue, style: const TextStyle(color: Colors.white)));
      children.add(const SizedBox(height: 8));
      for (var i = 0; i < q.choices.length; i++) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: FilledButton(
            key: ValueKey('mm-answer-$i'),
            onPressed: () => _answer(i),
            child: Text(q.choices[i].text),
          ),
        ));
      }
    } else if (snap.currentRoomCleared) {
      for (final door in room.doors) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: OutlinedButton(
            key: ValueKey('mm-door-${door.direction.name}'),
            onPressed: () => _move(door.direction),
            child: Text(_directionLabel(door.direction)),
          ),
        ));
      }
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF201A2A),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _overlay({
    required Key key,
    required String title,
    required String subtitle,
    required String buttonLabel,
  }) =>
      Positioned.fill(
        key: key,
        child: Container(
          color: const Color(0xCC000000),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('mm-restart'),
                onPressed: _restart,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmaze/room_view_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/room_view.dart app/encarta_reader/test/mindmaze/room_view_test.dart
git commit -m "feat(app): RoomView — playable MindMaze room (answer/move/win/lose)"
```

---

### Task 5: Pool loader + MindMazePage

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_pools.dart`
- Create: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart`
- Test: `app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart`

**Interfaces:**
- Consumes: `toGameQuestion` (Task 2); `RoomView` (Task 4); `minimalMaze`/`GameSession`/`GameConfig` (`encarta_mindmaze`); `AppScope` (app).
- Produces:
  - `Future<Map<int, List<mm.Question>>> buildMindMazePools({required Future<List<data.MindMazeQuestion>> Function(int area) mindmazeQuestions, List<int> areas})` — pure, DB-free-testable loader.
  - `MindMazePage` (`@RoutePage`) — reads `AppScope`, loads pools, constructs `GameSession`, renders `RoomView`; degradation on missing db/questions.

- [ ] **Step 1: Write the failing test**

`app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_reader/src/screens/mindmaze/mindmaze_pools.dart';
import 'package:flutter_test/flutter_test.dart';

data.MindMazeQuestion _q(int id, int area) => data.MindMazeQuestion(
      id: id, area: area, clue: 'c$id',
      answers: [
        data.MindMazeAnswer(ordinal: 0, text: 'a', articleRefid: id, isCorrect: true),
        const data.MindMazeAnswer(ordinal: 1, text: 'b', articleRefid: 0, isCorrect: false),
      ],
    );

void main() {
  test('buildMindMazePools loads and adapts the requested areas', () async {
    final pools = await buildMindMazePools(
      mindmazeQuestions: (area) async => [_q(area * 100, area), _q(area * 100 + 1, area)],
      areas: const [0, 1],
    );
    expect(pools.keys.toSet(), {0, 1});
    expect(pools[0], hasLength(2));
    expect(pools[1]!.first.area, 1);
    expect(pools[0]!.first.choices, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmaze/mindmaze_pools_test.dart`
Expected: FAIL — `mindmaze_pools.dart` / `buildMindMazePools` not found.

- [ ] **Step 3: Implement the pure loader**

`app/encarta_reader/lib/src/screens/mindmaze/mindmaze_pools.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

import 'question_adapter.dart';

/// Loads and adapts the question pools for the given [areas]. Pure: takes the
/// query function so it is testable without a database. `minimalMaze()` uses
/// areas 0 and 1, the default.
Future<Map<int, List<mm.Question>>> buildMindMazePools({
  required Future<List<data.MindMazeQuestion>> Function(int area) mindmazeQuestions,
  List<int> areas = const [0, 1],
}) async {
  final pools = <int, List<mm.Question>>{};
  for (final area in areas) {
    final qs = await mindmazeQuestions(area);
    pools[area] = [for (final q in qs) toGameQuestion(q)];
  }
  return pools;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmaze/mindmaze_pools_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Implement MindMazePage**

`app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart`:

```dart
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'mindmaze_pools.dart';
import 'room_view.dart';

@RoutePage()
class MindMazePage extends StatefulWidget {
  const MindMazePage({super.key});

  @override
  State<MindMazePage> createState() => _MindMazePageState();
}

class _MindMazePageState extends State<MindMazePage> {
  Future<Map<int, List<mm.Question>>?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final db = AppScope.of(context).db;
    if (db == null) {
      _future = Future.value(null);
      return;
    }
    _future = buildMindMazePools(
      mindmazeQuestions: (area) => db.mindmazeQuestions(area: area),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<Map<int, List<mm.Question>>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('MindMaze could not start.'));
        }
        final pools = snap.data;
        if (pools == null || pools.values.any((l) => l.isEmpty)) {
          return const Center(child: Text('MindMaze questions are unavailable.'));
        }
        final maze = mm.minimalMaze();
        final config = scope.assets?.config ?? const AssetConfig.defaultConfig();
        return RoomView(
          maze: maze,
          config: config,
          newGame: () => mm.GameSession(
            maze: maze,
            pools: pools,
            config: const mm.GameConfig(),
            random: Random(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 6: Run the pools test + confirm the app still compiles**

Run: `flutter test test/mindmaze/mindmaze_pools_test.dart` (PASS)
Run: `flutter analyze lib/src/screens/mindmaze` — Expected: no issues (the page compiles; it is wired into the router in Task 6).

- [ ] **Step 7: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/mindmaze_pools.dart app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart
git commit -m "feat(app): MindMaze pool loader + MindMazePage (loads pools, builds GameSession)"
```

---

### Task 6: Wire the route, navigator, and Home entry point

**Files:**
- Modify: `app/encarta_reader/lib/src/nav/app_router.dart` (register route)
- Regenerate: `app/encarta_reader/lib/src/nav/app_router.gr.dart` (build_runner)
- Modify: `app/encarta_reader/lib/src/nav/app_navigator.dart` (`openMindMaze`)
- Modify: `app/encarta_reader/lib/src/screens/home/home_page.dart` (pass callback)
- Modify: `app/encarta_reader/lib/src/screens/home/home_view.dart` (a "Play MindMaze" button)
- Test: `app/encarta_reader/test/mindmaze/mindmaze_route_test.dart`

**Interfaces:**
- Consumes: `MindMazePage` (Task 5).
- Produces: `AppNavigator.openMindMaze()` → `/mindmaze`; `MindMazeRoute` registered at path `/mindmaze`; a Home entry point that calls it.

- [ ] **Step 1: Register the route**

In `app/encarta_reader/lib/src/nav/app_router.dart`, add the import and the route:

```dart
import '../screens/mindmaze/mindmaze_page.dart';
```
```dart
        AutoRoute(page: MindMazeRoute.page, path: '/mindmaze'),
```
(Add the `AutoRoute(...)` line inside the `routes` list, after the article route.)

- [ ] **Step 2: Regenerate the router**

Run (from `app/encarta_reader`): `dart run build_runner build --delete-conflicting-outputs`
Expected: `MindMazeRoute` generated in `app_router.gr.dart`; no errors.

- [ ] **Step 3: Add the navigator intent**

In `app/encarta_reader/lib/src/nav/app_navigator.dart`, add a method next to `openArticle`:

```dart
  void openMindMaze() => _navigate('/mindmaze');
```

- [ ] **Step 4: Write the failing test**

`app/encarta_reader/test/mindmaze/mindmaze_route_test.dart`:

```dart
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/app_router.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openMindMaze navigates to /mindmaze and records history', () {
    final visited = <String>[];
    final nav = AppNavigator(
      history: HistoryController(),
      go: visited.add,
    );
    nav.openMindMaze();
    expect(visited, ['/mindmaze']);
    expect(nav.history.canGoBack, isFalse); // first entry
  });

  test('the router registers a /mindmaze route', () {
    final router = AppRouter();
    final paths = router.routes.map((r) => r.path).toList();
    expect(paths, contains('/mindmaze'));
  });
}
```

(If `HistoryController`'s API differs — e.g. `canGoBack` is named differently — match the existing `history_controller.dart`; the essential assertions are `visited == ['/mindmaze']` and the route path is registered.)

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/mindmaze/mindmaze_route_test.dart`
Expected: FAIL — `openMindMaze` undefined and/or `/mindmaze` not in routes (until Steps 1–3 are in).

- [ ] **Step 6: Add the Home entry point**

In `home_view.dart`, add an `onPlayMindMaze` callback field to the `HomeView` widget and a button that calls it (place it near the hero/portal actions):

```dart
  final VoidCallback? onPlayMindMaze;
```
```dart
              if (onPlayMindMaze != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('mm-play'),
                    onPressed: onPlayMindMaze,
                    icon: const Icon(Icons.castle),
                    label: const Text('Play MindMaze'),
                  ),
                ),
```

In `home_page.dart`, pass the callback when constructing `HomeView`:

```dart
      onPlayMindMaze: () => AppScope.of(context).navigator.openMindMaze(),
```

(Match `HomeView`'s existing constructor/callsite; add the named param through both the widget constructor and the `home_page` build.)

- [ ] **Step 7: Run tests + verify build**

Run: `flutter test test/mindmaze/mindmaze_route_test.dart` (PASS — 2 tests)
Run (full app suite, no regressions): `flutter test`
Expected: all app tests pass.
Run: `flutter analyze` — Expected: no issues.
Run (the real payoff — the macOS app builds with the game wired in): `flutter build macos --debug`
Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add app/encarta_reader/lib/src/nav/app_router.dart app/encarta_reader/lib/src/nav/app_router.gr.dart app/encarta_reader/lib/src/nav/app_navigator.dart app/encarta_reader/lib/src/screens/home/home_page.dart app/encarta_reader/lib/src/screens/home/home_view.dart app/encarta_reader/test/mindmaze/mindmaze_route_test.dart
git commit -m "feat(app): wire /mindmaze route + navigator intent + Home entry point"
```

---

## Self-Review

**Spec coverage (against `2026-07-02-mindmaze-04-room-ui-design.md`):**
- Build-time transcode (cyan→alpha sprites, opaque backdrops), pure testable core, `image` dev-dep → Task 1. ✓
- Runtime art loader (derived PNG + placeholder, no DibShim) + sprite-frame map → Task 3. ✓
- `MindMazeQuestion → Question` adapter + app dep on `encarta_mindmaze` → Task 2. ✓
- Pure pool loader + `MindMazePage` (`FutureBuilder` + degradation) → Task 5. ✓
- `RoomView` (HUD lives/score, backdrop+sprite scene, dialog panel with clue/answers, door buttons on clear, win/lose overlays + restart) → Task 4. ✓
- `/mindmaze` route + `openMindMaze` + Home entry point → Task 6. ✓
- Full loop playable (answer/move/win/lose over `minimalMaze()`) → Tasks 4–6 (win/lose covered by RoomView tests). ✓
- Graceful degradation (art miss placeholder, data miss message) → Tasks 3 + 5. ✓
- macOS build stays green → Task 6 Step 7. ✓

**Placeholder scan:** No TBD/TODO; every code step is complete. The `room_view_test.dart` answer finders are `_correctAnswerFinder` (label starts with `correct-`) and `_wrongAnswerFinder` (label `w1`), both used by the tests.

**Type consistency:** `toGameQuestion` (Task 2) is consumed by `buildMindMazePools` (Task 5); `mindMazeArt`/`spriteFrameFor` (Task 3) by `RoomView` (Task 4); `RoomView({newGame, maze, config})` constructor matches its callsite in `MindMazePage` (Task 5) and its tests (Task 4); `AppNavigator.openMindMaze` (Task 6) matches its test and the Home callback; widget keys (`mm-answer-<i>`, `mm-door-<dir>`, `mm-lives`, `mm-won`, `mm-lost`, `mm-restart`) are defined in `RoomView` and referenced by its tests. ✓

**Known integration checks the implementer must honor (called out in-task):** `HistoryController`'s exact API (Task 6 test note), and `HomeView`'s existing constructor shape when threading `onPlayMindMaze` (Task 6 Step 6). These are existing-code touchpoints the plan flags explicitly rather than assuming.

**Out of scope (later phases):** maze map/end-screen art (P5); audio, sprite animation, banter variety, trophies, "learn more" navigation, full 9-wing content (P6+).
