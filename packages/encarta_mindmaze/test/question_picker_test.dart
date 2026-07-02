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
