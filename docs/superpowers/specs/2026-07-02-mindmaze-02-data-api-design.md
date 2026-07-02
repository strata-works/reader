# MindMaze Phase 2 — `encarta_data` Query API Design Spec

**Date:** 2026-07-02
**Status:** Approved (brainstorm) → ready for implementation plan
**Parent design:** `reader/docs/superpowers/specs/2026-07-01-mindmaze-design.md` (§4.1)
**Phase 1 (upstream):** `quarry` decode — `mm_question` / `mm_answer` tables now live in `encarta.sqlite` (merged, PR #1).

---

## 1. Goal & Decisions

Expose the MindMaze question bank to the Flutter reader through the existing `encarta_data` package, so the Phase 3 game core can load a castle wing's questions. Read-only, typed, drift-based — matching the package's established patterns exactly.

Decisions locked during brainstorming:

- **Combined model:** `mindmazeQuestions(...)` returns `MindMazeQuestion` objects each carrying their `List<MindMazeAnswer>` (correct + 3 decoys), assembled from one JOIN. No N+1, no separate `answersFor`.
- **Stateless pool provider:** the data layer returns a wing's whole pool; the Phase 3 game core owns shuffling, random selection, and per-session "seen" tracking. No randomness or selection SQL here.
- **Defer the reverse-lookup:** `questionsWhereArticleIsAnswer(refid)` is NOT built in Phase 2 (YAGNI); it lands when the reader wires a "test yourself on this topic" feature.

---

## 2. Data Source (from Phase 1)

`encarta.sqlite` contains:

```sql
mm_question(id INTEGER PK, area INTEGER, clue TEXT)
mm_answer(id INTEGER PK, question_id INTEGER, ordinal INTEGER,
          text TEXT, article_refid INTEGER, is_correct INTEGER, flag INTEGER)
-- indexes: idx_mm_answer_question(question_id), idx_mm_answer_article(article_refid)
```

- 8,020 questions; each has exactly 4 `mm_answer` rows (`ordinal` 0–3; `ordinal 0` = authored correct answer, `is_correct=1`).
- `area` is 0–8 (castle wing) or `NULL` (~6% of questions, whose correct-answer refid matched no `Area*.lst` pool).
- `mm_answer.article_refid` joins `article.refid` (used later for "learn more"; not joined by the Phase 2 pool query).
- `flag` (raw per-answer u16) is preserved in the DB but NOT surfaced in the Phase 2 API (no consumer; YAGNI).

---

## 3. Public API

### 3.1 Models (`lib/src/models.dart`, exported from `lib/encarta_data.dart`)

```dart
/// One MindMaze answer choice. `ordinal` 0 is the authored correct answer;
/// 1–3 are decoys. `articleRefid` joins article.refid ("learn more" target).
class MindMazeAnswer {
  final int ordinal;
  final String text;
  final int articleRefid;
  final bool isCorrect;
  const MindMazeAnswer({
    required this.ordinal,
    required this.text,
    required this.articleRefid,
    required this.isCorrect,
  });
}

/// One MindMaze question: a definition-style clue plus its four answers
/// (ordinal-ordered, index 0 correct). `area` is the castle wing 0–8, or null
/// when the question's topic matched no Area*.lst pool.
class MindMazeQuestion {
  final int id;
  final int? area;
  final String clue;
  final List<MindMazeAnswer> answers;
  const MindMazeQuestion({
    required this.id,
    required this.area,
    required this.clue,
    required this.answers,
  });

  /// The authored correct answer (ordinal 0 / is_correct = 1).
  MindMazeAnswer get correct => answers.firstWhere((a) => a.isCorrect);
}
```

### 3.2 `EncartaDb` methods (`lib/src/encarta_db.dart`)

```dart
/// All MindMaze questions for a castle wing (`area` 0–8), each with its four
/// ordinal-ordered answers. When [area] is null, returns EVERY question
/// (including area==null ones); the game core buckets by each question's
/// `.area`. Questions are ordered by id; answers by ordinal.
Future<List<MindMazeQuestion>> mindmazeQuestions({int? area});

/// Count of MindMaze questions overall, or in one wing when [area] is given.
Future<int> mindmazeQuestionCount({int? area});
```

Both are read-only. `mindmazeQuestions` runs one JOIN query returning flat
`(question × answer)` rows ordered by `(q.id, a.ordinal)`, then folds
consecutive rows sharing a question id into a `MindMazeQuestion` with its
`answers` list — the same map-rows-to-models shape as `mediaForArticle`.

### 3.3 Queries (`lib/src/queries.drift`)

```sql
-- Question × answer rows for one wing, ordered so the fold in Dart can group
-- consecutive rows by questionId and keep answers ordinal-ordered.
mindmazeQuestionsByArea:
SELECT q.id AS questionId, q.area AS area, q.clue AS clue,
       a.ordinal AS ordinal, a.text AS text,
       a.article_refid AS articleRefid, a.is_correct AS isCorrect
FROM mm_question q
JOIN mm_answer a ON a.question_id = q.id
WHERE q.area = :area
ORDER BY q.id, a.ordinal;

-- Same projection, all wings (including area IS NULL).
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

`EncartaDb.mindmazeQuestions` dispatches to `mindmazeQuestionsByArea` when
`area != null`, else `mindmazeAllQuestions`; `mindmazeQuestionCount` dispatches
to the matching count query. (Two explicit queries keep drift's generated types
clean and avoid nullable-parameter `IS NULL OR =` gymnastics — this mirrors the
existing `featuredHomeArticles` / `featuredByMediaCount` split.)

### 3.4 Drift tables (`lib/src/tables.drift`)

Add `mm_question` and `mm_answer` CREATE TABLE statements mirroring the real
schema so drift generates row classes and the queries type-check. The indexes
are not declared here (drift reads don't need them; they exist in the real DB).

---

## 4. Test Fixture

Extend `tool/build_fixture.dart`:

- `CREATE TABLE mm_question(...)` and `mm_answer(...)` in the fixture.
- Copy a deterministic slice from the real DB, chosen for coverage:
  - a handful of questions from at least two distinct non-null areas,
  - at least one question with `area IS NULL`,
  - all four `mm_answer` rows for each copied question.
- Deterministic selection (e.g. `ORDER BY id LIMIT n` per area, plus the first
  null-area question) so tests can assert exact counts.

This lets the tests below run against real-shaped rows without the full corpus.

## 5. Testing (`test/mindmaze_questions_test.dart`)

Against the extended fixture:

1. `mindmazeQuestions(area: X)` returns only questions whose `area == X`.
2. Every returned question has exactly 4 answers, ordinal-ordered `[0,1,2,3]`,
   with exactly one `isCorrect` (the ordinal-0 answer); `correct` getter returns it.
3. Grouping is correct — answers are not cross-contaminated between adjacent questions.
4. `mindmazeQuestions()` (null area) includes the `area == null` question(s).
5. `mindmazeQuestionCount(area: X)` equals the number of area-X questions;
   `mindmazeQuestionCount()` equals the fixture's total.
6. Unknown area → empty list / count 0.
7. `articleRefid` and `clue` values round-trip from the fixture rows.

Tests follow the package's existing `test/` conventions (open the fixture DB via
`EncartaDb.open`, assert on returned models).

---

## 6. Error Handling & Constraints

- **Read-only:** no writes; reuse the existing `EncartaDb.open` path (FTS5 loader,
  read-only interceptor) unchanged.
- **Empty results** for unknown/absent areas — never throws.
- **No new dependencies.**
- **Codegen:** regenerate `database.g.dart` via `dart run build_runner build` after
  editing the `.drift` files.
- **Scope guard:** no selection/shuffle/"seen" logic (Phase 3), no reverse-lookup
  (deferred), no `flag` surfacing, no article JOIN in the pool query.

---

## 7. Out of Scope (later phases)

- Selection/randomness/"seen" tracking — Phase 3 (`encarta_mindmaze` game core).
- `questionsWhereArticleIsAnswer(refid)` reverse-lookup — when a consumer needs it.
- Any game UI, castle art, sprite handling — Phases 4–6.
