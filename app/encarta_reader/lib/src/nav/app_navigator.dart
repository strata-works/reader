import 'history_controller.dart';

/// Single place that turns intents into route locations AND records history.
class AppNavigator {
  final HistoryController history;
  final void Function(String location) go;
  const AppNavigator({required this.history, required this.go});

  void _navigate(String location) {
    history.push(location);
    go(location);
  }

  void openHome() => _navigate('/');

  void openSearch(String q) => _navigate('/search?q=${Uri.encodeComponent(q)}');

  void openArticle(int refid, {String? paraId}) {
    final anchor = (paraId != null && paraId.isNotEmpty)
        ? '?para=${Uri.encodeComponent(paraId)}'
        : '';
    _navigate('/article/$refid$anchor');
  }

  void openMindMaze() => _navigate('/mindmaze');

  void openTour(String tourId) => _navigate('/tours/$tourId');

  void back() {
    final loc = history.back();
    if (loc != null) go(loc);
  }

  void forward() {
    final loc = history.forward();
    if (loc != null) go(loc);
  }
}
