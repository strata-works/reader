/// Immutable resolved configuration. Data dir is configuration, never hard-wired.
class AppConfig {
  final String dataDir;
  const AppConfig(this.dataDir);

  /// Path to the read-only SQLite DB inside the data dir.
  String get dbPath => '$dataDir/encarta.sqlite';

  static const defaultDataDir =
      '/Users/nexus/projects/experiments/strata/quarry/build';

  /// Resolution order: --data-dir arg > ENCARTA_DATA_DIR env > persisted setting > default.
  static AppConfig resolve({
    required List<String> args,
    required Map<String, String> env,
    String? setting,
  }) {
    for (final a in args) {
      if (a.startsWith('--data-dir=')) {
        return AppConfig(a.substring('--data-dir='.length));
      }
    }
    final fromEnv = env['ENCARTA_DATA_DIR'];
    if (fromEnv != null && fromEnv.isNotEmpty) return AppConfig(fromEnv);
    if (setting != null && setting.isNotEmpty) return AppConfig(setting);
    return const AppConfig(defaultDataDir);
  }
}
