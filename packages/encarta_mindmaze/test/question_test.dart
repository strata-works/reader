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
