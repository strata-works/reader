import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_config.dart';

/// Long-lived runtime singletons for the app.
class AppEnvironment {
  final AppConfig config;
  final EncartaDb db;
  final EncartaAssets assets;
  const AppEnvironment({
    required this.config,
    required this.db,
    required this.assets,
  });

  Future<void> dispose() => db.close();
}

/// Boots the app: init media_kit, open the read-only DB, build the asset resolver.
/// [openDb]/[initMedia] are injectable seams; production uses the real defaults.
Future<AppEnvironment> bootstrap(
  AppConfig config, {
  Future<EncartaDb> Function(String dbPath)? openDb,
  void Function()? initMedia,
}) async {
  (initMedia ?? () => MediaKit.ensureInitialized())();
  final db = await (openDb ?? EncartaDb.open)(config.dbPath);
  final assets = EncartaAssets(db, AssetConfig(config.dataDir));
  return AppEnvironment(config: config, db: db, assets: assets);
}
