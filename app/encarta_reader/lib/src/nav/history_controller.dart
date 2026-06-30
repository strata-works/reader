import 'package:flutter/foundation.dart';

/// Browser-like history of route locations (the Encarta "Back").
class HistoryController extends ChangeNotifier {
  final List<String> _stack = <String>[];
  int _index = -1;

  String? get current => _index >= 0 ? _stack[_index] : null;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index >= 0 && _index < _stack.length - 1;

  void push(String location) {
    if (current == location) return;
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(location);
    _index = _stack.length - 1;
    notifyListeners();
  }

  String? back() {
    if (!canGoBack) return null;
    _index--;
    notifyListeners();
    return current;
  }

  String? forward() {
    if (!canGoForward) return null;
    _index++;
    notifyListeners();
    return current;
  }
}
