// packages/encarta_assets/test/resolve_path_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late EncartaAssets assets;

  setUp(() {
    root = Directory.systemTemp.createTempSync('encarta_assets_resolve');
    // resolvePath never touches the DB; forTesting supplies a throwing stand-in.
    assets = EncartaAssets.forTesting(AssetConfig(root.path));
  });

  tearDown(() => root.deleteSync(recursive: true));

  void writeFile(String dir, String rel) {
    final f = File(p.join(root.path, dir, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync([1, 2, 3]);
  }

  test('prefers derived when both derived and original exist', () {
    writeFile('assets', 'image/abc.jpg');
    writeFile('assets_derived', 'image/abc.jpg');
    final f = assets.resolvePath('image/abc.jpg');
    expect(f, isNotNull);
    expect(f!.path, p.join(root.path, 'assets_derived', 'image/abc.jpg'));
  });

  test('falls back to original when only original exists', () {
    writeFile('assets', 'image/abc.jpg');
    final f = assets.resolvePath('image/abc.jpg');
    expect(f, isNotNull);
    expect(f!.path, p.join(root.path, 'assets', 'image/abc.jpg'));
  });

  test('returns null when neither exists', () {
    final f = assets.resolvePath('image/missing.jpg');
    expect(f, isNull);
  });
}
