// packages/encarta_assets/lib/src/asset_config.dart
import 'package:path/path.dart' as p;

/// Configuration for where asset binaries live on disk.
///
/// `asset.path` values from the DB are relative to [assetsDir], e.g.
/// `image/ae3ce60978a8b1e7.jpg` or `other/5466cdd6eab010ec.dib`.
class AssetConfig {
  /// Root data directory (the quarry build dir by default).
  final String dataDir;

  const AssetConfig(this.dataDir);

  /// The shipped default: the quarry build directory.
  const AssetConfig.defaultConfig()
      : dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

  /// Original (un-transcoded) asset binaries: `<dataDir>/assets`.
  String get assetsDir => p.join(dataDir, 'assets');

  /// Derived/transcoded assets (PNG/mp3/mp4), when present:
  /// `<dataDir>/assets_derived`.
  String get derivedDir => p.join(dataDir, 'assets_derived');
}
