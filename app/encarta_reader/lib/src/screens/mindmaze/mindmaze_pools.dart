import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

import 'question_adapter.dart';

/// Loads and adapts the question pools for the given [areas]. Pure: takes the
/// query function so it is testable without a database. Callers pass the areas
/// the loaded maze actually uses (see `mazeAreas`).
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
