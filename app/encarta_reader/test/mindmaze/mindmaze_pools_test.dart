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
}
