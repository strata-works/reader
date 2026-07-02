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
