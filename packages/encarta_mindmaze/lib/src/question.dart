/// One answer choice. Exactly one choice in a question is correct.
/// [articleRefid] joins article.refid for a later "learn more".
class AnswerChoice {
  const AnswerChoice({
    required this.text,
    required this.articleRefid,
    required this.isCorrect,
  });

  final String text;
  final int articleRefid;
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      other is AnswerChoice &&
      other.text == text &&
      other.articleRefid == articleRefid &&
      other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(text, articleRefid, isCorrect);
}

bool _choicesEqual(List<AnswerChoice> a, List<AnswerChoice> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A MindMaze question: a clue and its answer [choices] as presented
/// (already in display order). [id] is mm_question.id (the "seen" dedup key);
/// [area] is the castle wing 0–8, or null.
class Question {
  const Question({
    required this.id,
    required this.area,
    required this.clue,
    required this.choices,
  });

  final int id;
  final int? area;
  final String clue;
  final List<AnswerChoice> choices;

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.id == id &&
      other.area == area &&
      other.clue == clue &&
      _choicesEqual(other.choices, choices);

  @override
  int get hashCode => Object.hash(id, area, clue, choices.length);
}
