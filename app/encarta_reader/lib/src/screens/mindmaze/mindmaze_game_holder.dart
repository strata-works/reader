import 'package:encarta_mindmaze/encarta_mindmaze.dart' as mm;

/// Holds the live MindMaze game across page re-inflation. The app navigates
/// push-only (HistoryController + pushPath), so Back inflates a fresh
/// MindMazePage; without this holder the new RoomView would start a new
/// GameSession and lose progress (e.g. after a "Learn more" excursion). Owned
/// once at app root and passed via AppScope so the session outlives the page.
class MindMazeGameHolder {
  mm.MazeGraph? maze;
  Map<int, List<mm.Question>>? pools;
  mm.GameSession? session;
}
