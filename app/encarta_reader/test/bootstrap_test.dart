import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_data/encarta_data.dart';

/// Minimal stand-in for [EncartaDb]. Uses noSuchMethod so we don't have to
/// implement every method — the test only needs identity checks.
class FakeDb implements EncartaDb {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('FakeDb.${invocation.memberName} must not be called in this test');

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap initializes media, opens the DB read-only, builds assets',
      () async {
    var mediaInit = false;
    String? openedPath;

    final env = await bootstrap(
      const AppConfig('/data/X'),
      openDb: (path) async {
        openedPath = path;
        return FakeDb();
      },
      initMedia: () => mediaInit = true,
    );

    expect(mediaInit, isTrue);
    expect(openedPath, '/data/X/encarta.sqlite');
    expect(env.assets.config.dataDir, '/data/X');
    expect(identical(env.db, env.assets.db), isTrue);
  });
}
