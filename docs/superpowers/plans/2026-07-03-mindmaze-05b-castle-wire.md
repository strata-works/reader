# MindMaze Phase 5b — Castle-Wire Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the authored `minimalMaze()` placeholder with the authentic decoded castle (`mm_room`/`mm_door`/`mm_character` from Phase 5a) and add a trophy end-screen.

**Architecture:** Extend each existing layer, no new pattern. The data-API (`encarta_data`) gains a `mindmazeCastle()` query returning a `MindMazeCastle` data model; the app (`encarta_reader`) adapts that model into an engine `MazeGraph` (`encarta_mindmaze`) and drives `GameSession` with it; the room UI gains a trophy end-screen. Art transcoding is extended for the new backdrops/sprites/end art.

**Tech Stack:** Dart/Flutter pub workspace; drift (SQLite codegen) for the data layer; `package:test` (data + engine) and `flutter_test` (app widgets).

## Global Constraints

- **Base branch:** `mindmaze-castle-wire` off `main` (contains merged Phases 2–4 + Android/iOS work).
- **Reader-side only:** consume the already-built `quarry/build/encarta.sqlite`; do NOT reopen the quarry decode.
- **Drift regen gate:** after any `tables.drift`/`queries.drift` change run `dart run build_runner build --delete-conflicting-outputs` in `packages/encarta_data`; `dart analyze` excludes `*.g.dart`, so **`dart test` is the real gate** for drift changes.
- **Engine is pure:** `packages/encarta_mindmaze` takes NO Flutter/drift/sqlite deps — do not import data-API or Flutter into it. Mapping lives in the app layer.
- **flutter_test art gotcha:** never pump a real `Image.file` (async codec hangs ~10 min). In tests the derived PNGs are absent, so `mindMazeArt` returns a labeled placeholder `Container` keyed `mm-art-missing-<id>` — assert that key / widget type, never a decoded image.
- **Authored-vs-authentic provenance:** room/door *connectivity* is the Phase 5a authored spine (flag it in a code comment); characters, banter, greetings, backdrops are authentic; the generic approve/rebuff feedback and the win blurb are authored (documented in code).
- **Start-room convention:** `startRoomId = 'atrium'` (the decode has no `is_start` flag); validate its presence.

---

### Task 1: Data-API castle query (`encarta_data`)

Adds the three castle tables to the drift schema, a `mindmazeCastle()` query, the `MindMazeCastle`/`MindMazeRoom`/`MindMazeDoor`/`MindMazeCharacter` models, and extends the test fixture with castle rows.

**Files:**
- Modify: `packages/encarta_data/lib/src/tables.drift` (after the `mm_answer` table, ~line 67)
- Modify: `packages/encarta_data/lib/src/queries.drift` (append after line 152)
- Modify: `packages/encarta_data/lib/src/models.dart` (append after `MindMazeQuestion`, ~line 230)
- Modify: `packages/encarta_data/lib/encarta_data.dart` (extend the `models.dart` export)
- Modify: `packages/encarta_data/lib/src/encarta_db.dart` (add `mindmazeCastle()`)
- Modify: `packages/encarta_data/tool/build_fixture.dart` (create + copy castle tables)
- Regenerate: `packages/encarta_data/lib/src/database.g.dart` (build_runner)
- Regenerate: `packages/encarta_data/test/fixtures/encarta_fixture.sqlite` (build_fixture tool)
- Test: `packages/encarta_data/test/mindmaze_castle_test.dart` (new)

**Interfaces:**
- Produces:
  - `class MindMazeCastle { final List<MindMazeRoom> rooms; final List<MindMazeDoor> doors; final List<MindMazeCharacter> characters; }`
  - `class MindMazeRoom { final String id; final int? area; final String backdropId; final String characterId; final bool isGoal; }`
  - `class MindMazeDoor { final String roomId; final String direction; final String targetRoomId; }`
  - `class MindMazeCharacter { final String id; final String spriteSet; final String greeting; final List<String> banter; }`
  - `Future<MindMazeCastle> EncartaDb.mindmazeCastle()`

- [ ] **Step 1: Write the failing test**

Create `packages/encarta_data/test/mindmaze_castle_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('mindmazeCastle() returns the full decoded castle', () async {
    final castle = await db.mindmazeCastle();
    expect(castle.rooms, hasLength(11));
    expect(castle.doors, hasLength(20));
    expect(castle.characters, hasLength(11));
  });

  test('exactly one goal room, and atrium is present as the start', () async {
    final castle = await db.mindmazeCastle();
    expect(castle.rooms.where((r) => r.isGoal), hasLength(1));
    expect(castle.rooms.singleWhere((r) => r.isGoal).id, 'throne');
    expect(castle.rooms.map((r) => r.id), contains('atrium'));
  });

  test('a room carries its backdrop + resident character', () async {
    final castle = await db.mindmazeCastle();
    final atrium = castle.rooms.singleWhere((r) => r.id == 'atrium');
    expect(atrium.backdropId, isNotEmpty);
    expect(atrium.characterId, 'jester');
    expect(atrium.area, 0);
  });

  test('doors reference real rooms and a valid direction', () async {
    final castle = await db.mindmazeCastle();
    final ids = castle.rooms.map((r) => r.id).toSet();
    const dirs = {'left', 'right', 'tower', 'north', 'south'};
    for (final d in castle.doors) {
      expect(ids, contains(d.roomId));
      expect(ids, contains(d.targetRoomId));
      expect(dirs, contains(d.direction));
    }
  });

  test('character banter_json parses to a non-empty line list', () async {
    final castle = await db.mindmazeCastle();
    final jester = castle.characters.singleWhere((c) => c.id == 'jester');
    expect(jester.spriteSet, 'jester');
    expect(jester.greeting, isNotEmpty);
    expect(jester.banter, isNotEmpty);
    expect(jester.banter.first, isA<String>());
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/encarta_data && dart test test/mindmaze_castle_test.dart`
Expected: FAIL — compile error `The method 'mindmazeCastle' isn't defined` (and no castle rows in the fixture yet).

- [ ] **Step 3: Add the drift tables**

In `packages/encarta_data/lib/src/tables.drift`, after the `mm_answer` table (line 67), add:

```sql
CREATE TABLE mm_room (
  id           TEXT NOT NULL PRIMARY KEY,
  area         INTEGER,
  backdrop_id  TEXT,
  character_id TEXT,
  is_goal      INTEGER
);

CREATE TABLE mm_door (
  room_id        TEXT NOT NULL,
  direction      TEXT NOT NULL,
  target_room_id TEXT,
  PRIMARY KEY (room_id, direction)
);

CREATE TABLE mm_character (
  id          TEXT NOT NULL PRIMARY KEY,
  sprite_set  TEXT,
  greeting    TEXT,
  banter_json TEXT
);
```

- [ ] **Step 4: Add the drift queries**

Append to `packages/encarta_data/lib/src/queries.drift`:

```sql
-- MindMaze castle graph (Phase 5b). Rooms, directed doors, and characters,
-- each ordered by id for deterministic assembly.
mindmazeRooms:
SELECT id AS id, area AS area, backdrop_id AS backdropId,
       character_id AS characterId, is_goal AS isGoal
FROM mm_room ORDER BY id;

mindmazeDoors:
SELECT room_id AS roomId, direction AS direction,
       target_room_id AS targetRoomId
FROM mm_door ORDER BY room_id, direction;

mindmazeCharacters:
SELECT id AS id, sprite_set AS spriteSet, greeting AS greeting,
       banter_json AS banterJson
FROM mm_character ORDER BY id;
```

- [ ] **Step 5: Add the models**

Append to `packages/encarta_data/lib/src/models.dart`:

```dart
/// The decoded MindMaze castle: its [rooms], directed [doors], and the
/// [characters] that pose questions. Connectivity is the Phase 5a authored
/// spine; room/character content and banter are authentic (decoded from
/// ENCARTA.EXE). See `mindmazeCastle()`.
class MindMazeCastle {
  const MindMazeCastle({
    required this.rooms,
    required this.doors,
    required this.characters,
  });

  final List<MindMazeRoom> rooms;
  final List<MindMazeDoor> doors;
  final List<MindMazeCharacter> characters;
}

/// A castle room: its question-pool [area] (nullable), [backdropId] art,
/// resident [characterId], and whether it is the [isGoal] (throne) room.
class MindMazeRoom {
  const MindMazeRoom({
    required this.id,
    required this.area,
    required this.backdropId,
    required this.characterId,
    required this.isGoal,
  });

  final String id;
  final int? area;
  final String backdropId;
  final String characterId;
  final bool isGoal;
}

/// A one-way navigation edge from [roomId] to [targetRoomId] via [direction]
/// (one of left|right|tower|north|south).
class MindMazeDoor {
  const MindMazeDoor({
    required this.roomId,
    required this.direction,
    required this.targetRoomId,
  });

  final String roomId;
  final String direction;
  final String targetRoomId;
}

/// A castle character: its [spriteSet] art id, authentic [greeting], and all
/// recovered [banter] lines (parsed from banter_json).
class MindMazeCharacter {
  const MindMazeCharacter({
    required this.id,
    required this.spriteSet,
    required this.greeting,
    required this.banter,
  });

  final String id;
  final String spriteSet;
  final String greeting;
  final List<String> banter;
}
```

- [ ] **Step 6: Export the new models**

In `packages/encarta_data/lib/encarta_data.dart`, extend the `models.dart` export show-list with the four new types:

```dart
export 'src/models.dart' show Article, SearchHit, MediaItem, AssetRow, XrefTarget, TitleRef, MindMazeQuestion, MindMazeAnswer, MindMazeCastle, MindMazeRoom, MindMazeDoor, MindMazeCharacter;
```

- [ ] **Step 7: Implement `mindmazeCastle()`**

In `packages/encarta_data/lib/src/encarta_db.dart`, add this method to the `EncartaDb` class (e.g. right after `mindmazeQuestions`, ~line 250). `banterJson` is a JSON array of strings; parse it defensively (empty list on null/blank/parse-failure):

```dart
  /// The decoded MindMaze castle (rooms, directed doors, characters). Rooms are
  /// ordered by id; each character's `banter_json` is parsed to a line list.
  /// Throws if the underlying db lacks the castle tables (an old corpus) — the
  /// caller degrades gracefully.
  Future<MindMazeCastle> mindmazeCastle() async {
    final rooms = [
      for (final r in await _db.mindmazeRooms().get())
        MindMazeRoom(
          id: r.id,
          area: r.area,
          backdropId: r.backdropId ?? '',
          characterId: r.characterId ?? '',
          isGoal: (r.isGoal ?? 0) != 0,
        ),
    ];
    final doors = [
      for (final d in await _db.mindmazeDoors().get())
        MindMazeDoor(
          roomId: d.roomId,
          direction: d.direction,
          targetRoomId: d.targetRoomId ?? '',
        ),
    ];
    final characters = [
      for (final c in await _db.mindmazeCharacters().get())
        MindMazeCharacter(
          id: c.id,
          spriteSet: c.spriteSet ?? '',
          greeting: c.greeting ?? '',
          banter: _parseBanter(c.banterJson),
        ),
    ];
    return MindMazeCastle(rooms: rooms, doors: doors, characters: characters);
  }

  static List<String> _parseBanter(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return [for (final e in decoded) '$e'];
      }
    } catch (_) {/* malformed banter → no lines */}
    return const [];
  }
```

(`dart:convert` is already imported at the top of the file.)

- [ ] **Step 8: Regenerate drift code**

Run: `cd packages/encarta_data && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded` — `database.g.dart` now defines `mindmazeRooms()`, `mindmazeDoors()`, `mindmazeCharacters()` and their `*Result` row classes.

- [ ] **Step 9: Extend the fixture builder with castle tables**

In `packages/encarta_data/tool/build_fixture.dart`, inside the `dst.execute('''…''')` schema block (after the `mm_answer` line, ~line 53), add the castle `CREATE TABLE`s:

```sql
    CREATE TABLE mm_room (id TEXT PRIMARY KEY, area INTEGER, backdrop_id TEXT, character_id TEXT, is_goal INTEGER);
    CREATE TABLE mm_door (room_id TEXT, direction TEXT, target_room_id TEXT, PRIMARY KEY (room_id, direction));
    CREATE TABLE mm_character (id TEXT PRIMARY KEY, sprite_set TEXT, greeting TEXT, banter_json TEXT);
```

Then, just before the `DETACH DATABASE src` line (~line 116), copy the castle wholesale (it is tiny — 11/20/11 rows):

```dart
  // MindMaze castle (Phase 5b): copy the whole graph — it is small and the
  // adapter/tests assert against the real 11-room / 20-door / 11-character set.
  dst.execute('INSERT INTO mm_room SELECT * FROM src.mm_room');
  dst.execute('INSERT INTO mm_door SELECT * FROM src.mm_door');
  dst.execute('INSERT INTO mm_character SELECT * FROM src.mm_character');
```

- [ ] **Step 10: Rebuild the fixture**

Run: `cd packages/encarta_data && dart run tool/build_fixture.dart`
Expected: `Wrote test/fixtures/encarta_fixture.sqlite with <N> articles.` (requires `quarry/build/encarta.sqlite` present — it is).

- [ ] **Step 11: Run the test to verify it passes**

Run: `cd packages/encarta_data && dart test test/mindmaze_castle_test.dart`
Expected: PASS (all 5 tests). Then run the full package suite to catch drift-regen regressions: `dart test` — Expected: PASS (pre-existing `test_store` ResourceWarning-style leaks, if any, are unrelated).

- [ ] **Step 12: Commit**

```bash
git add packages/encarta_data/lib packages/encarta_data/tool/build_fixture.dart \
        packages/encarta_data/test/mindmaze_castle_test.dart \
        packages/encarta_data/test/fixtures/encarta_fixture.sqlite
git commit -m "feat(mindmaze): decode castle query (mindmazeCastle) in encarta_data"
```

---

### Task 2: Castle → MazeGraph adapter (`encarta_reader`)

Pure mapping from the data model to the engine graph, plus the area-derivation helper. No Flutter, no DB — a plain Dart test.

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart`
- Test: `app/encarta_reader/test/mindmaze/castle_adapter_test.dart`

**Interfaces:**
- Consumes: `MindMazeCastle`/`MindMazeRoom`/`MindMazeDoor`/`MindMazeCharacter` (Task 1); engine `MazeGraph`/`Room`/`Door`/`Character`/`Direction` from `package:encarta_mindmaze/encarta_mindmaze.dart`.
- Produces:
  - `MazeGraph castleToMaze(MindMazeCastle castle)` — throws `ArgumentError` if there is no goal room or no `atrium`.
  - `List<int> mazeAreas(MazeGraph maze)` — sorted, distinct non-null room areas.

- [ ] **Step 1: Write the failing test**

Create `app/encarta_reader/test/mindmaze/castle_adapter_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:encarta_reader/src/screens/mindmaze/castle_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

data.MindMazeCastle _castle() => const data.MindMazeCastle(
      rooms: [
        data.MindMazeRoom(id: 'atrium', area: 0, backdropId: 'atrium', characterId: 'jester', isGoal: false),
        data.MindMazeRoom(id: 'throne', area: 6, backdropId: 'atrium', characterId: 'king', isGoal: true),
      ],
      doors: [
        data.MindMazeDoor(roomId: 'atrium', direction: 'right', targetRoomId: 'throne'),
        data.MindMazeDoor(roomId: 'throne', direction: 'south', targetRoomId: 'atrium'),
      ],
      characters: [
        data.MindMazeCharacter(id: 'jester', spriteSet: 'jester', greeting: 'Welcome!', banter: ['a', 'b']),
        data.MindMazeCharacter(id: 'king', spriteSet: 'king', greeting: 'Prove it.', banter: ['c']),
      ],
    );

void main() {
  test('castleToMaze wires rooms, doors, start and goal', () {
    final maze = castleToMaze(_castle());
    expect(maze.startRoomId, 'atrium');
    expect(maze.goalRoomId, 'throne');
    expect(maze.rooms.keys.toSet(), {'atrium', 'throne'});
    expect(maze.room('atrium').backdropId, 'atrium');
    expect(maze.doorTarget('atrium', mm.Direction.right)?.id, 'throne');
  });

  test('character greeting maps through; approve/rebuff are populated', () {
    final maze = castleToMaze(_castle());
    final c = maze.room('atrium').character;
    expect(c.id, 'jester');
    expect(c.spriteSetId, 'jester');
    expect(c.greeting, 'Welcome!');
    expect(c.approve, isNotEmpty);
    expect(c.rebuff, isNotEmpty);
  });

  test('mazeAreas is the sorted distinct room areas', () {
    expect(mazeAreas(castleToMaze(_castle())), [0, 6]);
  });

  test('throws when there is no goal room', () {
    final noGoal = data.MindMazeCastle(
      rooms: const [
        data.MindMazeRoom(id: 'atrium', area: 0, backdropId: 'atrium', characterId: 'jester', isGoal: false),
      ],
      doors: const [],
      characters: const [
        data.MindMazeCharacter(id: 'jester', spriteSet: 'jester', greeting: 'hi', banter: []),
      ],
    );
    expect(() => castleToMaze(noGoal), throwsArgumentError);
  });

  test('throws when there is no atrium start room', () {
    final noAtrium = data.MindMazeCastle(
      rooms: const [
        data.MindMazeRoom(id: 'throne', area: 6, backdropId: 'atrium', characterId: 'king', isGoal: true),
      ],
      doors: const [],
      characters: const [
        data.MindMazeCharacter(id: 'king', spriteSet: 'king', greeting: 'hi', banter: []),
      ],
    );
    expect(() => castleToMaze(noAtrium), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/mindmaze/castle_adapter_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../castle_adapter.dart'`.

- [ ] **Step 3: Implement the adapter**

Create `app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart`:

```dart
import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

// The decoded castle has authentic greetings but no per-answer reaction lines
// (the original used generic right/wrong cues), so approve/rebuff are authored
// generic feedback, shared by every character. Banter variety is Phase 6.
const _genericApprove = <String>[
  'Correct — the way opens.',
  'Well answered. Proceed.',
];
const _genericRebuff = <String>[
  'No — think again, seeker.',
  'Not so. The door stays shut.',
];

// The decode has no is_start flag; the Phase 5a authored spine always enters at
// the atrium. Kept as a named convention (candidate for an is_start flag in a
// future quarry pass).
const _startRoomId = 'atrium';

/// Adapts the data-layer [castle] into the engine's [mm.MazeGraph].
///
/// Connectivity is the Phase 5a authored spine; room/character content and
/// greetings are authentic. Throws [ArgumentError] if the castle lacks a goal
/// room or the `atrium` start room, so the page can degrade gracefully rather
/// than build a broken maze.
mm.MazeGraph castleToMaze(data.MindMazeCastle castle) {
  final characters = {for (final c in castle.characters) c.id: c};

  final goals = castle.rooms.where((r) => r.isGoal);
  if (goals.length != 1) {
    throw ArgumentError('castle must have exactly one goal room, found ${goals.length}');
  }
  if (!castle.rooms.any((r) => r.id == _startRoomId)) {
    throw ArgumentError('castle has no "$_startRoomId" start room');
  }

  final doorsByRoom = <String, List<mm.Door>>{};
  for (final d in castle.doors) {
    (doorsByRoom[d.roomId] ??= []).add(
      mm.Door(direction: mm.Direction.values.byName(d.direction), targetRoomId: d.targetRoomId),
    );
  }

  final rooms = <String, mm.Room>{};
  for (final r in castle.rooms) {
    final c = characters[r.characterId];
    rooms[r.id] = mm.Room(
      id: r.id,
      area: r.area ?? 0,
      backdropId: r.backdropId,
      character: mm.Character(
        id: r.characterId,
        spriteSetId: c?.spriteSet ?? r.characterId,
        greeting: c?.greeting ?? '',
        approve: _genericApprove,
        rebuff: _genericRebuff,
      ),
      doors: doorsByRoom[r.id] ?? const [],
    );
  }

  return mm.MazeGraph(
    rooms: rooms,
    startRoomId: _startRoomId,
    goalRoomId: goals.single.id,
  );
}

/// The sorted, distinct room areas the [maze] uses — the exact set of question
/// pools that must be loaded to construct a [mm.GameSession] over it.
List<int> mazeAreas(mm.MazeGraph maze) {
  final areas = {for (final r in maze.rooms.values) r.area}.toList()..sort();
  return areas;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app/encarta_reader && flutter test test/mindmaze/castle_adapter_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/castle_adapter.dart \
        app/encarta_reader/test/mindmaze/castle_adapter_test.dart
git commit -m "feat(mindmaze): castleToMaze adapter + mazeAreas helper"
```

---

### Task 3: Wire the page to the real castle (`encarta_reader`)

Load the castle, adapt it, derive pool areas from it, and drive `GameSession` — replacing `minimalMaze()` and the hardwired `[0,1]` pool areas.

**Files:**
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_pools.dart` (drop the stale coupling comment; keep the injected-query signature)
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart:20-70`
- Test: `app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart` (add an area-passthrough case)

**Interfaces:**
- Consumes: `EncartaDb.mindmazeCastle()` (Task 1); `castleToMaze`, `mazeAreas` (Task 2); existing `buildMindMazePools({required mindmazeQuestions, List<int> areas})`.
- Produces: a `MindMazePage` that renders `RoomView` over the decoded castle.

- [ ] **Step 1: Write the failing test**

Add to `app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart` (new test; keep existing tests):

```dart
  test('buildMindMazePools loads exactly the requested areas', () async {
    final requested = <int>[];
    final pools = await buildMindMazePools(
      areas: const [0, 2, 6],
      mindmazeQuestions: (area) async {
        requested.add(area);
        return [
          data.MindMazeQuestion(
            id: area,
            area: area,
            clue: 'clue $area',
            answers: const [
              data.MindMazeAnswer(ordinal: 0, text: 'a', articleRefid: 1, isCorrect: true),
              data.MindMazeAnswer(ordinal: 1, text: 'b', articleRefid: 2, isCorrect: false),
            ],
          ),
        ];
      },
    );
    expect(requested, [0, 2, 6]);
    expect(pools.keys.toSet(), {0, 2, 6});
    expect(pools[6], hasLength(1));
  });
```

Ensure the file imports `package:encarta_data/encarta_data.dart' as data;` (add if absent).

- [ ] **Step 2: Run the test to verify it fails/passes-as-written**

Run: `cd app/encarta_reader && flutter test test/mindmaze/mindmaze_pools_test.dart`
Expected: PASS if `buildMindMazePools` already threads `areas` (it does) — this test locks the behavior in before the page change. If the import was missing it FAILS to compile first; add the import, then PASS.

- [ ] **Step 3: Drop the stale coupling comment in `mindmaze_pools.dart`**

Replace the doc comment above `buildMindMazePools` (lines 6-8, the "`minimalMaze()` uses areas 0 and 1, the default." sentence) with:

```dart
/// Loads and adapts the question pools for the given [areas]. Pure: takes the
/// query function so it is testable without a database. Callers pass the areas
/// the loaded maze actually uses (see `mazeAreas`).
```

- [ ] **Step 4: Rewrite `mindmaze_page.dart` to load the real castle**

Replace the body of `_MindMazePageState` (lines 20-70) so it loads the castle, adapts it, and derives the pool areas. Full new file:

```dart
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'castle_adapter.dart';
import 'mindmaze_pools.dart';
import 'room_view.dart';

@RoutePage()
class MindMazePage extends StatefulWidget {
  const MindMazePage({super.key});

  @override
  State<MindMazePage> createState() => _MindMazePageState();
}

/// The loaded maze plus its question pools — everything RoomView needs.
class _Loaded {
  const _Loaded(this.maze, this.pools);
  final mm.MazeGraph maze;
  final Map<int, List<mm.Question>> pools;
}

class _MindMazePageState extends State<MindMazePage> {
  Future<_Loaded?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final db = AppScope.of(context).db;
    if (db == null) {
      _future = Future.value(null);
      return;
    }
    _future = () async {
      // Build the authentic castle, then load exactly the pools its rooms use.
      final maze = castleToMaze(await db.mindmazeCastle());
      final pools = await buildMindMazePools(
        areas: mazeAreas(maze),
        mindmazeQuestions: (area) => db.mindmazeQuestions(area: area),
      );
      return _Loaded(maze, pools);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<_Loaded?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('MindMaze could not start.'));
        }
        final loaded = snap.data;
        if (loaded == null || loaded.pools.values.any((l) => l.isEmpty)) {
          return const Center(child: Text('MindMaze questions are unavailable.'));
        }
        final config = scope.assets?.config ?? const AssetConfig.defaultConfig();
        return RoomView(
          maze: loaded.maze,
          config: config,
          newGame: () => mm.GameSession(
            maze: loaded.maze,
            pools: loaded.pools,
            config: const mm.GameConfig(),
            random: Random(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run the mindmaze app tests to verify nothing regressed**

Run: `cd app/encarta_reader && flutter test test/mindmaze/`
Expected: PASS. (`mindmaze_route_test` still routes to the page; the page now shows the loading spinner / graceful-degradation text without a seeded castle db, which those tests already tolerate. If a route test asserted `minimalMaze`-specific content, update it to the new load path.)

- [ ] **Step 6: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/mindmaze_page.dart \
        app/encarta_reader/lib/src/screens/mindmaze/mindmaze_pools.dart \
        app/encarta_reader/test/mindmaze/mindmaze_pools_test.dart
git commit -m "feat(mindmaze): drive the game from the decoded castle"
```

---

### Task 4: Trophy end-screen (`encarta_reader`)

Extract the win overlay into a testable `MindMazeEndScreen` widget (trophy + end art + authored authentic rank text), render it from `RoomView`, and make the dialog panel scroll so full-paragraph greetings don't overflow.

**Files:**
- Create: `app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart`
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart` (won branch + dialog scroll)
- Test: `app/encarta_reader/test/mindmaze/end_screen_test.dart`

**Interfaces:**
- Consumes: `mindMazeArt` (existing) and `AssetConfig`.
- Produces: `class MindMazeEndScreen extends StatelessWidget` with `{required AssetConfig config, required int score, required VoidCallback onPlayAgain}`; renders keys `mm-won`, `mm-restart`, and art `mm-art-missing-end1` / `mm-art-missing-trophy` (placeholders when PNGs absent).

- [ ] **Step 1: Write the failing test**

Create `app/encarta_reader/test/mindmaze/end_screen_test.dart`:

```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/end_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('end screen shows rank, score, art placeholders, and play-again', (tester) async {
    var played = 0;
    await tester.pumpWidget(MaterialApp(
      home: MindMazeEndScreen(
        config: const AssetConfig.defaultConfig(),
        score: 700,
        onPlayAgain: () => played++,
      ),
    ));

    // Authentic rank text + score.
    expect(find.text('Master Scholar Of MindMaze'), findsOneWidget);
    expect(find.textContaining('700'), findsOneWidget);
    // Art wired (derived PNGs absent in tests → labeled placeholders, no Image.file).
    expect(find.byKey(const ValueKey('mm-art-missing-end1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mm-art-missing-trophy')), findsOneWidget);
    // Play again is wired.
    await tester.tap(find.byKey(const ValueKey('mm-restart')));
    expect(played, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/mindmaze/end_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../end_screen.dart'`.

- [ ] **Step 3: Implement the end-screen widget**

Create `app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart`:

```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

import 'mindmaze_art.dart';

// Authored win/rank text. The authentic rank string ("Master Scholar Of
// MindMaze") and story were decoded in Phase 5a analysis but are not persisted
// in a queryable table; the short win blurb is authored in-style.
const _rank = 'Master Scholar Of MindMaze';
const _blurb = "Zorlock's curse is broken. The throne room opens, and the "
    'castle is yours.';

/// The MindMaze victory screen: the `end1` scene behind a `trophy`, the
/// authentic rank, the final [score], and a play-again action.
class MindMazeEndScreen extends StatelessWidget {
  const MindMazeEndScreen({
    super.key,
    required this.config,
    required this.score,
    required this.onPlayAgain,
  });

  final AssetConfig config;
  final int score;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: const ValueKey('mm-won'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          mindMazeArt(config, 'end1', fit: BoxFit.cover),
          Container(color: const Color(0xCC000000)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 120,
                  child: mindMazeArt(config, 'trophy', fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                const Text('You have won the castle!',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 8),
                const Text(_rank,
                    style: TextStyle(
                        color: Color(0xFFF2D06B),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_blurb,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                Text('Final score: $score',
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('mm-restart'),
                  onPressed: onPlayAgain,
                  child: const Text('Play again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app/encarta_reader && flutter test test/mindmaze/end_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Render the end-screen from `RoomView` and make the dialog scroll**

In `app/encarta_reader/lib/src/screens/mindmaze/room_view.dart`:

1. Add the import at the top with the other local imports:

```dart
import 'end_screen.dart';
```

2. Replace the `won` branch of the overlay stack (lines 95-101) with the new widget:

```dart
            if (snap.status == GameStatus.won)
              MindMazeEndScreen(
                config: widget.config,
                score: snap.score,
                onPlayAgain: _restart,
              ),
```

(Leave the `lost` branch and `_overlay` helper unchanged — `_overlay` still serves the lost state.)

3. Make the dialog panel scrollable so full-paragraph greetings do not overflow. In `_dialogPanel`, wrap the `Column` in a bounded scroll view — replace the returned `Container`'s `child:` (lines 200-205) with:

```dart
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
```

- [ ] **Step 6: Run the room-UI tests to verify nothing regressed**

Run: `cd app/encarta_reader && flutter test test/mindmaze/`
Expected: PASS. The existing win-overlay test asserts the `mm-won` key and a `mm-restart` button — both are preserved by `MindMazeEndScreen`. If that test also asserted the old subtitle string `Final score: <n>` it still matches; if it asserted the old title `You've won the castle!` (apostrophe), update it to the new `You have won the castle!`.

- [ ] **Step 7: Commit**

```bash
git add app/encarta_reader/lib/src/screens/mindmaze/end_screen.dart \
        app/encarta_reader/lib/src/screens/mindmaze/room_view.dart \
        app/encarta_reader/test/mindmaze/end_screen_test.dart
git commit -m "feat(mindmaze): trophy end-screen with authentic rank"
```

---

### Task 5: Extend art transcode for the full castle (`encarta_assets`)

Add every room backdrop, one representative frame per sprite set, and the end/trophy art to the transcode tool, and map all 11 sprite sets in `spriteFrameFor`.

**Files:**
- Modify: `packages/encarta_assets/tool/transcode_mindmaze_art.dart:13-14` (`_sprites`, `_backdrops`)
- Modify: `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart:29-35` (`_spriteFrame` map)
- Test: `app/encarta_reader/test/mindmaze/mindmaze_art_test.dart` (add `spriteFrameFor` cases)

**Interfaces:**
- Produces: `spriteFrameFor(spriteSetId)` returns a transcoded-frame id for all 11 decoded sprite sets.

- [ ] **Step 1: Write the failing test**

Add to `app/encarta_reader/test/mindmaze/mindmaze_art_test.dart` (keep existing tests):

```dart
  test('spriteFrameFor resolves every decoded sprite set to a real frame', () {
    // Numbered-only sets resolve to their first frame…
    expect(spriteFrameFor('suitarm'), 'suitarm1');
    expect(spriteFrameFor('secnldy'), 'secnldy1');
    expect(spriteFrameFor('servant'), 'servant1');
    expect(spriteFrameFor('duke'), 'duke1');
    expect(spriteFrameFor('king'), 'king1');
    expect(spriteFrameFor('jester'), 'jester1');
    // …bare-id sets resolve to themselves.
    expect(spriteFrameFor('alchem'), 'alchem');
    expect(spriteFrameFor('asiantra'), 'asiantra');
    expect(spriteFrameFor('parrot'), 'parrot');
    expect(spriteFrameFor('maninst'), 'maninst');
    expect(spriteFrameFor('sorceres'), 'sorceres');
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: FAIL — `spriteFrameFor('suitarm')` currently returns `'suitarm'` (fallback), not `'suitarm1'`.

- [ ] **Step 3: Update the `spriteFrameFor` map**

In `app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart`, replace the `_spriteFrame` map (lines 29-35) with all 11 decoded sprite sets:

```dart
const _spriteFrame = <String, String>{
  'jester': 'jester1',
  'king': 'king1',
  'duke': 'duke1',
  'suitarm': 'suitarm1', // guard
  'secnldy': 'secnldy1', // lady
  'servant': 'servant1',
  // Sets whose art id has no numeric suffix resolve to themselves via the
  // fallback below, but list them for clarity:
  'sorceres': 'sorceres',
  'alchem': 'alchem',
  'asiantra': 'asiantra', // merchant
  'parrot': 'parrot',
  'maninst': 'maninst', // prisoner
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app/encarta_reader && flutter test test/mindmaze/mindmaze_art_test.dart`
Expected: PASS.

- [ ] **Step 5: Extend the transcode tool's art lists**

In `packages/encarta_assets/tool/transcode_mindmaze_art.dart`, replace lines 13-14 with the full castle inventory (one representative sprite frame per set; all 7 room backdrops; end + trophy art):

```dart
const _sprites = [
  'jester1', 'king1', 'duke1', 'suitarm1', 'secnldy1', 'servant1',
  'sorceres', 'alchem', 'asiantra', 'parrot', 'maninst',
];
const _backdrops = [
  'atrium', 'dunrm', 'walltre1', 'walltre2', 'bookshlf', 'plnwalls', 'rmofdoor',
  'end1', 'trophy', // end-screen art (opaque, not cyan-keyed)
];
```

Also update the tool's header comment (line 1-2) to say it transcodes "the MindMaze art referenced by the decoded castle" rather than "by minimalMaze()".

- [ ] **Step 6: Commit**

```bash
git add packages/encarta_assets/tool/transcode_mindmaze_art.dart \
        app/encarta_reader/lib/src/screens/mindmaze/mindmaze_art.dart \
        app/encarta_reader/test/mindmaze/mindmaze_art_test.dart
git commit -m "feat(mindmaze): transcode full-castle backdrops, sprites, end art"
```

---

### Task 6: Full-suite gate + manual live verification

Whole-app tests, then transcode the real art and play the castle end-to-end (mirrors the Phase 4 live-play sign-off).

**Files:** none (verification only).

- [ ] **Step 1: Run the full reader test suite**

Run: `cd app/encarta_reader && flutter test`
Expected: PASS (whole app). Also `cd packages/encarta_data && dart test` and `cd packages/encarta_mindmaze && dart test` — Expected: PASS.

- [ ] **Step 2: Transcode the real art (one-time local, not committed)**

Run: `cd packages/encarta_assets && dart run tool/transcode_mindmaze_art.dart`
Expected: `wrote …/assets_derived/mindmaze/<id>.png` for every sprite/backdrop/end/trophy id, with no `SKIP` lines (all ids exist in the corpus — verified in the spec's art inventory).

- [ ] **Step 3: Build and run the macOS app, play through to the throne**

Run: `cd app/encarta_reader && flutter run -d macos` (or the project's `/run` skill).
Verify: Home → "Play MindMaze" → the atrium loads a real backdrop + the jester sprite; answering correctly opens doors; navigate the spine atrium→gatehouse→servants→kitchen→gallery→tower→library→cellar→solar→study→throne; answering the throne question shows the **trophy end-screen** with "Master Scholar Of MindMaze" and Play again. Wrong answers cost lives; 0 lives shows the lost overlay.

- [ ] **Step 4: Commit any test fixups made during verification, then open the PR**

```bash
git push -u origin mindmaze-castle-wire
gh pr create --title "MindMaze Phase 5b: wire the authentic castle into the game" \
  --body "Replaces minimalMaze() with the decoded 11-room castle (mindmazeCastle query → castleToMaze adapter), loads pools for all castle areas, and adds the trophy end-screen. Reader-side only; consumes the Phase 5a castle tables. Spec: docs/superpowers/specs/2026-07-03-mindmaze-05b-castle-wire-design.md"
```

---

## Self-Review

**Spec coverage:**
- Goal 1 (castle query) → Task 1. Goal 2 (adapter + drive `GameSession`) → Tasks 2 & 3. Goal 3 (pools for areas 0–6) → Tasks 2 (`mazeAreas`) & 3 (page wiring). Goal 4 (end-screen) → Task 4. Goal 5 (art transcode) → Task 5. Full gate + live play → Task 6.
- Non-goals (audio, animation, banter variety, "Learn more", quarry persistence) — not scheduled. ✓
- Risks: old-db graceful degradation (Task 3, `hasError` branch + adapter throw); drift `dart test` gate (Task 1 Step 11); start-room convention (Task 2 validation); flutter_test art gotcha (Global Constraints + Tasks 4/5 placeholder-key assertions). ✓

**Placeholder scan:** every code step contains complete code; every run step has an exact command + expected result. No TBD/TODO. ✓

**Type consistency:** `MindMazeCastle`/`MindMazeRoom`/`MindMazeDoor`/`MindMazeCharacter` fields defined in Task 1 are consumed unchanged in Task 2; `castleToMaze`/`mazeAreas` produced in Task 2 are consumed in Task 3; `MindMazeEndScreen(config, score, onPlayAgain)` defined and consumed within Task 4; `spriteFrameFor` behavior asserted in Task 5 matches the map edited in the same task. Engine names (`MazeGraph`, `Room`, `Door`, `Character`, `Direction`, `GameSession`, `GameConfig`, `Question`) match `packages/encarta_mindmaze`. ✓
