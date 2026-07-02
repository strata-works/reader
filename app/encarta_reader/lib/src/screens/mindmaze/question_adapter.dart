import 'package:encarta_data/encarta_data.dart' as data;
import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

/// Maps the data-layer [data.MindMazeQuestion] to the game engine's
/// [mm.Question]. Choice order is preserved (the engine shuffles later).
mm.Question toGameQuestion(data.MindMazeQuestion q) => mm.Question(
      id: q.id,
      area: q.area,
      clue: q.clue,
      choices: [
        for (final a in q.answers)
          mm.AnswerChoice(
            text: a.text,
            articleRefid: a.articleRefid,
            isCorrect: a.isCorrect,
          ),
      ],
    );
