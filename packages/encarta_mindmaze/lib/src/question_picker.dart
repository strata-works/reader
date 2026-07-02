import 'dart:math';

import 'question.dart';

/// Selects an unseen question for a room's area and shuffles its choices.
/// Pure given the injected [Random]; never soft-locks (resets when exhausted).
class QuestionPicker {
  QuestionPicker(this._pools, this._random);

  final Map<int, List<Question>> _pools;
  final Random _random;

  /// A question from [area] whose id is not in [seen], with freshly shuffled
  /// choices. If every valid question in the area is already seen, reuses the
  /// full valid pool (so play never stalls). Returns null only when the area
  /// has no question with exactly one correct choice.
  Question? pick(int area, Set<int> seen) {
    final pool = _pools[area];
    if (pool == null || pool.isEmpty) return null;
    final valid = pool.where(_hasOneCorrect).toList();
    if (valid.isEmpty) return null;
    var candidates = valid.where((q) => !seen.contains(q.id)).toList();
    if (candidates.isEmpty) candidates = valid; // reset: reuse full pool
    final chosen = candidates[_random.nextInt(candidates.length)];
    return _withShuffledChoices(chosen);
  }

  bool _hasOneCorrect(Question q) =>
      q.choices.where((c) => c.isCorrect).length == 1;

  Question _withShuffledChoices(Question q) {
    final shuffled = [...q.choices]..shuffle(_random);
    return Question(id: q.id, area: q.area, clue: q.clue, choices: shuffled);
  }
}
