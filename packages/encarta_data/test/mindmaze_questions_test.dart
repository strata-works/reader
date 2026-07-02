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
