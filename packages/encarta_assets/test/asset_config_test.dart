// packages/encarta_assets/test/asset_config_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('assetsDir and derivedDir are joined under dataDir', () {
    const cfg = AssetConfig('/data/root');
    expect(cfg.assetsDir, p.join('/data/root', 'assets'));
    expect(cfg.derivedDir, p.join('/data/root', 'assets_derived'));
  });

  test('default config points at the quarry build dir', () {
    const cfg = AssetConfig.defaultConfig();
    expect(cfg.dataDir,
        '/Users/nexus/projects/experiments/strata/quarry/build');
    expect(
        cfg.assetsDir,
        '/Users/nexus/projects/experiments/strata/quarry/build/assets');
    expect(cfg.derivedDir,
        '/Users/nexus/projects/experiments/strata/quarry/build/assets_derived');
  });
}
