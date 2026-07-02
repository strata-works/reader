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
