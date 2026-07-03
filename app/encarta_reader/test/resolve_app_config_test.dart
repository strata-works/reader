import 'package:encarta_reader/src/config/app_config.dart';
import 'package:encarta_reader/src/config/corpus_provisioner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop: ignores provisioner, uses default', () async {
    final cfg = await resolveAppConfig(
      args: const [],
      env: const {},
      isMobile: false,
      provisionCorpus: () async => '/should/not/be/used',
    );
    expect(cfg.dataDir, AppConfig.defaultDataDir);
  });

  test('mobile: no override → provisioned corpus dir wins', () async {
    final cfg = await resolveAppConfig(
      args: const [],
      env: const {},
      isMobile: true,
      provisionCorpus: () async => '/data/user/0/corpus',
    );
    expect(cfg.dataDir, '/data/user/0/corpus');
  });

  test('mobile: --data-dir override still wins (no provisioning)', () async {
    var provisioned = false;
    final cfg = await resolveAppConfig(
      args: const ['--data-dir=/dev/corpus'],
      env: const {},
      isMobile: true,
      provisionCorpus: () async {
        provisioned = true;
        return '/data/user/0/corpus';
      },
    );
    expect(cfg.dataDir, '/dev/corpus');
    expect(provisioned, isFalse);
  });
}
