import 'package:encarta_reader/src/nav/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router exposes the three Encarta routes with correct paths', () {
    final router = AppRouter();
    final paths = router.routes.map((r) => r.path).toSet();
    expect(paths, containsAll(<String>['/', '/search', '/article/:refid']));
  });
}
