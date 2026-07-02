import 'package:encarta_reader/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = '/Users/nexus/projects/experiments/strata/quarry/build';

  test('defaults to the quarry build dir', () {
    final c = AppConfig.resolve(args: const [], env: const {});
    expect(c.dataDir, fallback);
    expect(c.dbPath, '$fallback/encarta.sqlite');
  });

  test('--data-dir arg wins over env and default', () {
    final c = AppConfig.resolve(
      args: const ['--data-dir=/data/A'],
      env: const {'ENCARTA_DATA_DIR': '/data/B'},
      setting: '/data/C',
    );
    expect(c.dataDir, '/data/A');
  });

  test('env wins over setting and default', () {
    final c = AppConfig.resolve(
      args: const [],
      env: const {'ENCARTA_DATA_DIR': '/data/B'},
      setting: '/data/C',
    );
    expect(c.dataDir, '/data/B');
  });

  test('persisted setting wins over default', () {
    final c = AppConfig.resolve(args: const [], env: const {}, setting: '/data/C');
    expect(c.dataDir, '/data/C');
  });
}
