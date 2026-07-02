# MindMaze Phase 2 — `encarta_data` Query API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the MindMaze question bank (`mm_question`/`mm_answer` in `encarta.sqlite`) through the reader's `encarta_data` package as typed, read-only `mindmazeQuestions({int? area})` + `mindmazeQuestionCount({int? area})` methods.

**Architecture:** Follow the package's drift conventions exactly — declare the two tables in `tables.drift`, add named queries to `queries.drift`, regenerate `database.g.dart`, add immutable model classes to `models.dart`, and map/fold query rows to models in `EncartaDb` (same shape as `mediaForArticle`). Extend the test fixture with a real mm slice; test against it.

**Tech Stack:** Dart, drift (SQLite ORM with codegen via build_runner), `package:test`. Package: `reader/packages/encarta_data` (member of the `encarta_reader_workspace` pub workspace).

## Global Constraints

- **Read-only.** Reuse the existing `EncartaDb.open` path (FTS5 loader + read-only interceptor); never write to the corpus.
- **No new dependencies.**
- **drift codegen:** after editing any `.drift` file, regenerate with `dart run build_runner build --delete-conflicting-outputs` and commit the updated `lib/src/database.g.dart`.
- **Combined model:** `mindmazeQuestions` returns `MindMazeQuestion` objects each carrying their `List<MindMazeAnswer>` (exactly 4, ordinal-ordered; ordinal 0 = correct, `is_correct=1`).
- **`area` semantics:** `mindmazeQuestions(area: X)` → only that wing; `mindmazeQuestions()` (null) → ALL questions including `area == null` (~6% untagged). The game core buckets by each question's `.area`.
- **Scope guard (do NOT build):** no selection/shuffle/random/"seen" logic; no `questionsWhereArticleIsAnswer` reverse-lookup; no surfacing of `mm_answer.flag`; no JOIN to `article` in the pool query.
- **Conventions:** model classes are `const`-constructible with value `==`/`hashCode` (match `MediaItem`); tests use `package:test/test.dart` against `const fixturePath = 'test/fixtures/encarta_fixture.sqlite'` opened via `EncartaDb.open` (match `test/media_for_article_test.dart`).
- **Commands run from** `reader/packages/encarta_data`. If deps aren't resolved, run `dart pub get` at the reader workspace root first.
- **Real DB** (source for the fixture) already contains the rows: `/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite` has `mm_question` (8,020) + `mm_answer` (32,080), with `area` populated (0–8 or NULL).

---

### Task 1: Drift tables + named queries + codegen

**Files:**
- Modify: `lib/src/tables.drift`
- Modify: `lib/src/queries.drift`
- Regenerate: `lib/src/database.g.dart` (via build_runner)

**Interfaces:**
- Produces (drift-generated on `EncartaDatabase`): `mindmazeQuestionsByArea(int area)`, `mindmazeAllQuestions()` — each a `Selectable` of a result row with fields `questionId (int)`, `area (int?)`, `clue (String?)`, `ordinal (int?)`, `text (String?)`, `articleRefid (int?)`, `isCorrect (int?)`; and `mindmazeCountByArea(int area)`, `mindmazeCountAll()` — each `Selectable<int>` (single `count(*)` column, like `firstTitledRefid`).

- [ ] **Step 1: Add the two tables to `lib/src/tables.drift`**

Append after the `article_fts` virtual table:

```sql
CREATE TABLE mm_question (
  id    INTEGER NOT NULL PRIMARY KEY,
  area  INTEGER,
  clue  TEXT
);

CREATE TABLE mm_answer (
  id            INTEGER NOT NULL PRIMARY KEY,
  question_id   INTEGER,
  ordinal       INTEGER,
  text          TEXT,
  article_refid INTEGER,
  is_correct    INTEGER,
  flag          INTEGER
);
```

- [ ] **Step 2: Add the four named queries to `lib/src/queries.drift`**

Append to the end of the file:

```sql
-- MindMaze: question × answer rows for one castle wing, ordered so a fold in
-- Dart can group consecutive rows by questionId with answers ordinal-ordered.
mindmazeQuestionsByArea:
SELECT q.id AS questionId, q.area AS area, q.clue AS clue,
       a.ordinal AS ordinal, a.text AS text,
       a.article_refid AS articleRefid, a.is_correct AS isCorrect
FROM mm_question q
JOIN mm_answer a ON a.question_id = q.id
WHERE q.area = :area
ORDER BY q.id, a.ordinal;

-- Same projection across every wing (including area IS NULL).
mindmazeAllQuestions:
SELECT q.id AS questionId, q.area AS area, q.clue AS clue,
       a.ordinal AS ordinal, a.text AS text,
       a.article_refid AS articleRefid, a.is_correct AS isCorrect
FROM mm_question q
JOIN mm_answer a ON a.question_id = q.id
ORDER BY q.id, a.ordinal;

mindmazeCountByArea:
SELECT count(*) AS n FROM mm_question WHERE area = :area;

mindmazeCountAll:
SELECT count(*) AS n FROM mm_question;
```

- [ ] **Step 3: Regenerate the drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `[INFO] Succeeded` with `database.g.dart` rewritten; no errors.

- [ ] **Step 4: Verify it compiles cleanly**

Run: `dart analyze lib`
Expected: `No issues found!` (the new generated query methods exist and type-check; nothing calls them yet).

- [ ] **Step 5: Commit**

```bash
git add lib/src/tables.drift lib/src/queries.drift lib/src/database.g.dart
git commit -m "feat(data): drift tables + queries for MindMaze questions/answers"
```

---

### Task 2: Model classes

**Files:**
- Modify: `lib/src/models.dart`
- Modify: `lib/encarta_data.dart` (export the new models)
- Test: `test/mindmaze_models_test.dart`

**Interfaces:**
- Produces:
  - `MindMazeAnswer({required int ordinal, required String text, required int articleRefid, required bool isCorrect})` — value type.
  - `MindMazeQuestion({required int id, required int? area, required String clue, required List<MindMazeAnswer> answers})` with `MindMazeAnswer get correct` (the `isCorrect` answer). Value type (list-aware `==`).

- [ ] **Step 1: Write the failing test**

Create `test/mindmaze_models_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  const answers = [
    MindMazeAnswer(ordinal: 0, text: 'Right', articleRefid: 100, isCorrect: true),
    MindMazeAnswer(ordinal: 1, text: 'Wrong', articleRefid: 200, isCorrect: false),
  ];

  test('correct returns the isCorrect (ordinal 0) answer', () {
    const q = MindMazeQuestion(id: 1, area: 3, clue: 'A clue', answers: answers);
    expect(q.correct.text, 'Right');
    expect(q.correct.ordinal, 0);
  });

  test('MindMazeAnswer has value equality', () {
    const a = MindMazeAnswer(ordinal: 0, text: 'X', articleRefid: 1, isCorrect: true);
    const b = MindMazeAnswer(ordinal: 0, text: 'X', articleRefid: 1, isCorrect: true);
    const c = MindMazeAnswer(ordinal: 1, text: 'X', articleRefid: 1, isCorrect: false);
    expect(a, equals(b));
    expect(a, isNot(equals(c)));
  });

  test('MindMazeQuestion equality compares answers element-wise', () {
    const q1 = MindMazeQuestion(id: 1, area: null, clue: 'c', answers: answers);
    const q2 = MindMazeQuestion(id: 1, area: null, clue: 'c', answers: answers);
    const q3 = MindMazeQuestion(id: 1, area: null, clue: 'c', answers: [
      MindMazeAnswer(ordinal: 0, text: 'Different', articleRefid: 100, isCorrect: true),
    ]);
    expect(q1, equals(q2));
    expect(q1, isNot(equals(q3)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/mindmaze_models_test.dart`
Expected: FAIL — compile error, `MindMazeAnswer`/`MindMazeQuestion` are undefined.

- [ ] **Step 3: Add the models**

Append to `lib/src/models.dart`:

```dart
bool _answersEqual(List<MindMazeAnswer> a, List<MindMazeAnswer> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One MindMaze answer choice. `ordinal` 0 is the authored correct answer;
/// 1–3 are decoys. `articleRefid` joins article.refid ("learn more" target).
class MindMazeAnswer {
  const MindMazeAnswer({
    required this.ordinal,
    required this.text,
    required this.articleRefid,
    required this.isCorrect,
  });

  final int ordinal;
  final String text;
  final int articleRefid;
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      other is MindMazeAnswer &&
      other.ordinal == ordinal &&
      other.text == text &&
      other.articleRefid == articleRefid &&
      other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(ordinal, text, articleRefid, isCorrect);
}

/// One MindMaze question: a definition-style clue plus its four answers
/// (ordinal-ordered, index 0 correct). `area` is the castle wing 0–8, or null
/// when the question's topic matched no Area*.lst pool.
class MindMazeQuestion {
  const MindMazeQuestion({
    required this.id,
    required this.area,
    required this.clue,
    required this.answers,
  });

  final int id;
  final int? area;
  final String clue;
  final List<MindMazeAnswer> answers;

  /// The authored correct answer (ordinal 0 / is_correct = 1).
  MindMazeAnswer get correct => answers.firstWhere((a) => a.isCorrect);

  @override
  bool operator ==(Object other) =>
      other is MindMazeQuestion &&
      other.id == id &&
      other.area == area &&
      other.clue == clue &&
      _answersEqual(other.answers, answers);

  @override
  int get hashCode => Object.hash(id, area, clue, answers.length);
}
```

- [ ] **Step 4: Export the models**

In `lib/encarta_data.dart`, extend the models export `show` list to include the two new types:

```dart
export 'src/models.dart' show Article, SearchHit, MediaItem, AssetRow, XrefTarget, TitleRef, MindMazeQuestion, MindMazeAnswer;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/mindmaze_models_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/models.dart lib/encarta_data.dart test/mindmaze_models_test.dart
git commit -m "feat(data): MindMazeQuestion/MindMazeAnswer models"
```

---

### Task 3: Fixture slice + `EncartaDb` methods + query tests

**Files:**
- Modify: `tool/build_fixture.dart`
- Regenerate: `test/fixtures/encarta_fixture.sqlite` (via the tool)
- Modify: `lib/src/encarta_db.dart`
- Test: `test/mindmaze_questions_test.dart`

**Interfaces:**
- Consumes: the drift queries (Task 1) and models (Task 2).
- Produces on `EncartaDb`:
  - `Future<List<MindMazeQuestion>> mindmazeQuestions({int? area})`
  - `Future<int> mindmazeQuestionCount({int? area})`

- [ ] **Step 1: Extend the fixture builder**

In `tool/build_fixture.dart`, add the two `CREATE TABLE` statements inside the existing `dst.execute('''...''')` schema block (alongside the other `CREATE TABLE`s):

```sql
    CREATE TABLE mm_question (id INTEGER PRIMARY KEY, area INTEGER, clue TEXT);
    CREATE TABLE mm_answer (id INTEGER PRIMARY KEY, question_id INTEGER, ordinal INTEGER, text TEXT, article_refid INTEGER, is_correct INTEGER, flag INTEGER);
```

Then, just before the `DETACH DATABASE src` line, add a deterministic MindMaze slice — a few questions from two wings plus null-area, with all four answers each:

```dart
  // MindMaze: a deterministic slice — 3 questions each from wings 0 and 1, plus
  // 2 area==null questions, with all four answers each, so the query-API tests
  // have real rows to assert against.
  final qids = <int>{};
  for (final area in const [0, 1]) {
    for (final r in dst.select(
        'SELECT id FROM src.mm_question WHERE area = ? ORDER BY id LIMIT 3', [area])) {
      qids.add(r['id'] as int);
    }
  }
  for (final r in dst.select(
      'SELECT id FROM src.mm_question WHERE area IS NULL ORDER BY id LIMIT 2')) {
    qids.add(r['id'] as int);
  }
  final qIn = qids.join(',');
  dst.execute('INSERT INTO mm_question SELECT * FROM src.mm_question WHERE id IN ($qIn)');
  dst.execute('INSERT INTO mm_answer SELECT * FROM src.mm_answer WHERE question_id IN ($qIn)');
```

- [ ] **Step 2: Regenerate the fixture**

Run: `dart run tool/build_fixture.dart`
Expected: `Wrote test/fixtures/encarta_fixture.sqlite with <N> articles.` (exit 0). The fixture now also holds 8 mm_question rows (3 area=0, 3 area=1, 2 area=null) and 32 mm_answer rows.

- [ ] **Step 3: Write the failing tests**

Create `test/mindmaze_questions_test.dart`:

```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('mindmazeQuestions(area:) returns only that wing, 4 ordinal-ordered answers', () async {
    final qs = await db.mindmazeQuestions(area: 0);
    expect(qs, hasLength(3));
    for (final q in qs) {
      expect(q.area, 0);
      expect(q.answers, hasLength(4));
      expect(q.answers.map((a) => a.ordinal).toList(), [0, 1, 2, 3]);
      expect(q.answers.where((a) => a.isCorrect).length, 1);
      expect(q.correct.ordinal, 0);
      expect(q.clue, isNotEmpty);
    }
  });

  test('answers are grouped to the right question (no cross-contamination)', () async {
    final qs = await db.mindmazeQuestions(area: 1);
    expect(qs, hasLength(3));
    // Every answer's implied question is the one it was grouped under: all four
    // ordinals present exactly once per question.
    for (final q in qs) {
      expect(q.answers.map((a) => a.ordinal).toSet(), {0, 1, 2, 3});
    }
    // Question ids are distinct and ascending (ORDER BY q.id).
    final ids = qs.map((q) => q.id).toList();
    expect(ids.toSet(), hasLength(3));
    final sorted = [...ids]..sort();
    expect(ids, sorted);
  });

  test('mindmazeQuestions() with no area returns all wings including null-area', () async {
    final all = await db.mindmazeQuestions();
    expect(all, hasLength(8)); // 3 + 3 + 2
    expect(all.where((q) => q.area == null), hasLength(2));
  });

  test('mindmazeQuestions(area:) is empty for an absent wing', () async {
    expect(await db.mindmazeQuestions(area: 7), isEmpty);
  });

  test('mindmazeQuestionCount matches per-area and total', () async {
    expect(await db.mindmazeQuestionCount(area: 0), 3);
    expect(await db.mindmazeQuestionCount(area: 1), 3);
    expect(await db.mindmazeQuestionCount(area: 7), 0);
    expect(await db.mindmazeQuestionCount(), 8);
  });

  test('answer fields round-trip from the fixture', () async {
    final q = (await db.mindmazeQuestions(area: 0)).first;
    final a = q.correct;
    expect(a.text, isNotEmpty);
    expect(a.articleRefid, greaterThan(0));
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `dart test test/mindmaze_questions_test.dart`
Expected: FAIL — `mindmazeQuestions`/`mindmazeQuestionCount` are not defined on `EncartaDb`.

- [ ] **Step 5: Add the `EncartaDb` methods**

In `lib/src/encarta_db.dart`, add these methods inside the `EncartaDb` class (e.g. after `mediaForArticle`):

```dart
  /// All MindMaze questions for a castle wing ([area] 0–8), each with its four
  /// ordinal-ordered answers. When [area] is null, returns EVERY question
  /// (including area==null ones); the game core buckets by each question's
  /// `.area`. Questions are ordered by id; answers by ordinal.
  Future<List<MindMazeQuestion>> mindmazeQuestions({int? area}) async {
    final rows = area == null
        ? await _db.mindmazeAllQuestions().get()
        : await _db.mindmazeQuestionsByArea(area).get();
    final out = <MindMazeQuestion>[];
    final buf = <MindMazeAnswer>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      buf.add(MindMazeAnswer(
        ordinal: r.ordinal ?? 0,
        text: r.text ?? '',
        articleRefid: r.articleRefid ?? 0,
        isCorrect: (r.isCorrect ?? 0) != 0,
      ));
      final isLast = i == rows.length - 1;
      // Rows are ordered by (q.id, a.ordinal), so a question's answers are
      // contiguous; emit at each boundary.
      if (isLast || rows[i + 1].questionId != r.questionId) {
        out.add(MindMazeQuestion(
          id: r.questionId,
          area: r.area,
          clue: r.clue ?? '',
          answers: List<MindMazeAnswer>.unmodifiable(buf),
        ));
        buf.clear();
      }
    }
    return out;
  }

  /// Count of MindMaze questions overall, or in one wing when [area] is given.
  Future<int> mindmazeQuestionCount({int? area}) async {
    return area == null
        ? _db.mindmazeCountAll().getSingle()
        : _db.mindmazeCountByArea(area).getSingle();
  }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `dart test test/mindmaze_questions_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 7: Run the full package suite (no regressions)**

Run: `dart test`
Expected: all tests pass (existing + the new model/query tests).

- [ ] **Step 8: Commit**

```bash
git add tool/build_fixture.dart test/fixtures/encarta_fixture.sqlite lib/src/encarta_db.dart test/mindmaze_questions_test.dart
git commit -m "feat(data): mindmazeQuestions/mindmazeQuestionCount + fixture slice"
```

---

## Self-Review

**Spec coverage (against `2026-07-02-mindmaze-02-data-api-design.md`):**
- Combined model (question embeds answers) → Task 2 models + Task 3 fold. ✓
- `mindmazeQuestions({int? area})` + null→all semantics → Task 3 (`mindmazeAllQuestions` vs `mindmazeQuestionsByArea`). ✓
- `mindmazeQuestionCount({int? area})` → Task 3 + Task 1 count queries. ✓
- Drift tables + named queries + codegen → Task 1. ✓
- Models exported from barrel → Task 2 Step 4. ✓
- Fixture extended with a real deterministic slice (≥2 non-null areas + a null-area question + 4 answers each) → Task 3 Step 1. ✓
- Tests: by-area filtering, 4 ordinal-ordered answers, exactly one correct, grouping, null-area inclusion, counts, unknown-area empty, field round-trip → Task 3 Step 3 + Task 2. ✓
- Read-only / reuse open path / no new deps → unchanged `EncartaDb.open`; no pubspec edits. ✓
- Scope guard (no selection/reverse-lookup/flag/article-JOIN) → none added. ✓

**Placeholder scan:** No TBD/TODO; every code step is complete. ✓

**Type consistency:** `MindMazeAnswer` fields (`ordinal`, `text`, `articleRefid`, `isCorrect`) and `MindMazeQuestion` fields (`id`, `area`, `clue`, `answers`, `correct`) are used identically across Tasks 2→3; the drift result fields (`questionId`, `area`, `clue`, `ordinal`, `text`, `articleRefid`, `isCorrect`) match the `AS` aliases in Task 1's queries; `mindmazeQuestions`/`mindmazeQuestionCount` signatures match their tests. ✓

**Out of scope (later phases):** game core selection/seen (Phase 3); reverse-lookup (when needed); UI (Phases 4–6).
