/// Tunable game rules.
class GameConfig {
  const GameConfig({this.startingLives = 3, this.pointsPerCorrect = 100});
  final int startingLives;
  final int pointsPerCorrect;
}
