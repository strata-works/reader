/// Pure-Dart, headless game core for MindMaze: domain model + GameSession
/// state machine. No Flutter, no I/O — logic only.
library;

export 'src/question.dart' show AnswerChoice, Question;
export 'src/maze.dart' show Direction, Door, Character, Room, MazeGraph;

/// Sentinel proving the package compiles and is wired into the workspace.
/// Real exports are added as each unit lands.
const String kEncartaMindmazeLibrary = 'encarta_mindmaze';
