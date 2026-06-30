import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push builds a stack; back/forward traverse it', () {
    final h = HistoryController();
    expect(h.current, isNull);
    expect(h.canGoBack, isFalse);

    h.push('/');
    h.push('/article/10');
    h.push('/article/20');
    expect(h.current, '/article/20');
    expect(h.canGoBack, isTrue);
    expect(h.canGoForward, isFalse);

    expect(h.back(), '/article/10');
    expect(h.back(), '/');
    expect(h.canGoBack, isFalse);
    expect(h.forward(), '/article/10');
    expect(h.canGoForward, isTrue);
  });

  test('pushing after going back truncates the forward branch', () {
    final h = HistoryController();
    h.push('/');
    h.push('/article/10');
    h.back();
    h.push('/search?q=cat');
    expect(h.current, '/search?q=cat');
    expect(h.canGoForward, isFalse);
    expect(h.back(), '/');
  });

  test('pushing the current location again is a no-op', () {
    final h = HistoryController();
    h.push('/article/5');
    h.push('/article/5');
    expect(h.canGoBack, isFalse);
  });

  test('back/forward return null at the ends', () {
    final h = HistoryController();
    expect(h.back(), isNull);
    h.push('/');
    expect(h.forward(), isNull);
  });
}
