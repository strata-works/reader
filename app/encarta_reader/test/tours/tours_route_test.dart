import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openTour navigates to /tours/<id> and records history', () {
    final loc = <String>[];
    final nav = AppNavigator(history: HistoryController(), go: loc.add);
    nav.openTour('acropolis');
    expect(loc.single, '/tours/acropolis');
  });
}
