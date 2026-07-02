import 'dart:math';

import 'game_config.dart';
import 'maze.dart';
import 'question.dart';
import 'question_picker.dart';

/// The high-level game state.
enum GameStatus { playing, won, lost }

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// An immutable view of the session for the UI to render / tests to assert.
class GameSnapshot {
  const GameSnapshot({
    required this.currentRoomId,
    required this.lives,
    required this.score,
    required this.currentQuestion,
    required this.currentRoomCleared,
    required this.status,
    required this.clearedRooms,
    required this.lastCharacterLine,
  });

  final String currentRoomId;
  final int lives;
  final int score;
  final Question? currentQuestion; // null once the room is cleared
  final bool currentRoomCleared;
  final GameStatus status;
  final Set<String> clearedRooms;
  final String? lastCharacterLine;

  @override
  bool operator ==(Object other) =>
      other is GameSnapshot &&
      other.currentRoomId == currentRoomId &&
      other.lives == lives &&
      other.score == score &&
      other.currentQuestion == currentQuestion &&
      other.currentRoomCleared == currentRoomCleared &&
      other.status == status &&
      _setEquals(other.clearedRooms, clearedRooms) &&
      other.lastCharacterLine == lastCharacterLine;

  @override
  int get hashCode => Object.hash(currentRoomId, lives, score, currentQuestion,
      currentRoomCleared, status, clearedRooms.length, lastCharacterLine);
}

/// The MindMaze game loop: lives + retry, reach & clear the goal room to win.
/// Pure and synchronous — every transition is a function of state + input +
/// the injected [Random].
class GameSession {
  GameSession({
    required MazeGraph maze,
    required Map<int, List<Question>> pools,
    required GameConfig config,
    required Random random,
  })  : _maze = maze,
        _config = config,
        _random = random,
        _picker = QuestionPicker(pools, random) {
    // Fail fast: every room must have at least one posable question, or the
    // game would soft-lock on entering it. Pools are injected by the caller
    // (the app maps encarta_data questions in), so this is a precondition.
    for (final room in maze.rooms.values) {
      final pool = pools[room.area];
      final hasPosable = pool != null &&
          pool.any((q) => q.choices.where((c) => c.isCorrect).length == 1);
      if (!hasPosable) {
        throw ArgumentError(
          'room "${room.id}" (area ${room.area}) has no posable question',
        );
      }
    }
    _lives = config.startingLives;
    _enterRoom(maze.startRoomId, greet: true);
  }

  final MazeGraph _maze;
  final GameConfig _config;
  final Random _random;
  final QuestionPicker _picker;

  late String _currentRoomId;
  late int _lives;
  int _score = 0;
  final Set<int> _seen = <int>{};
  final Set<String> _cleared = <String>{};
  Question? _currentQuestion;
  GameStatus _status = GameStatus.playing;
  String? _lastLine;

  GameSnapshot get snapshot => GameSnapshot(
        currentRoomId: _currentRoomId,
        lives: _lives,
        score: _score,
        currentQuestion: _currentQuestion,
        currentRoomCleared: _cleared.contains(_currentRoomId),
        status: _status,
        clearedRooms: Set<String>.unmodifiable(_cleared),
        lastCharacterLine: _lastLine,
      );

  /// Answer the current question by its index into `snapshot.currentQuestion.choices`.
  void answer(int choiceIndex) {
    if (_status != GameStatus.playing) return;
    final q = _currentQuestion;
    if (q == null) return; // room already cleared, nothing to answer
    if (choiceIndex < 0 || choiceIndex >= q.choices.length) return;
    final room = _maze.room(_currentRoomId);
    if (q.choices[choiceIndex].isCorrect) {
      _cleared.add(_currentRoomId);
      _score += _config.pointsPerCorrect;
      _currentQuestion = null;
      _lastLine = _line(room.character.approve);
      if (_currentRoomId == _maze.goalRoomId) _status = GameStatus.won;
    } else {
      _lives -= 1;
      _lastLine = _line(room.character.rebuff);
      if (_lives <= 0) {
        _lives = 0;
        _status = GameStatus.lost;
        _currentQuestion = null;
      } else {
        _poseQuestion(room, avoid: q.id); // retry with a fresh unseen question
      }
    }
  }

  /// Move through the door in [direction]; only allowed once the current room
  /// is cleared. Entering the goal room poses its question — winning happens in
  /// [answer], never on the move itself.
  void move(Direction direction) {
    if (_status != GameStatus.playing) return;
    if (!_cleared.contains(_currentRoomId)) return;
    final target = _maze.doorTarget(_currentRoomId, direction);
    if (target == null) return;
    _enterRoom(target.id);
  }

  void _enterRoom(String roomId, {bool greet = false}) {
    _currentRoomId = roomId;
    final room = _maze.room(roomId);
    if (greet) _lastLine = room.character.greeting;
    if (_cleared.contains(roomId)) {
      _currentQuestion = null;
      return;
    }
    _poseQuestion(room);
  }

  void _poseQuestion(Room room, {int? avoid}) {
    final q = _picker.pick(room.area, _seen, avoid: avoid);
    _currentQuestion = q;
    if (q != null) _seen.add(q.id);
  }

  String? _line(List<String> lines) =>
      lines.isEmpty ? null : lines[_random.nextInt(lines.length)];
}
