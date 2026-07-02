// packages/encarta_assets/test/scaffold_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library barrel is importable and exposes the sentinel', () {
    expect(kEncartaAssetsLibraryName, 'encarta_assets');
  });
}
