// packages/encarta_assets/test/media_kit_init_test.dart
//
// NOTE: MediaKit.ensureInitialized() throws in headless test environments
// because libmpv/Mpv.framework is not present. We wire in a no-op override via
// [mediaKitInitOverride] so the idempotence and flag logic are fully testable
// without spinning up native media libraries.
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset the guard first, then install a no-op so MediaKit.ensureInitialized()
    // is never called for real in the headless test environment.
    resetMediaKitGuard();
    mediaKitInitOverride = () {};
  });

  tearDown(resetMediaKitGuard);

  test('ensureMediaKit is idempotent and flips the initialized flag', () {
    expect(mediaKitInitialized, isFalse);
    ensureMediaKit();
    expect(mediaKitInitialized, isTrue);
    // Second call must not throw.
    ensureMediaKit();
    expect(mediaKitInitialized, isTrue);
  });

  test('ensureMediaKit calls underlying init exactly once (idempotent)', () {
    int callCount = 0;
    mediaKitInitOverride = () => callCount++;

    ensureMediaKit();
    ensureMediaKit();
    ensureMediaKit();

    expect(callCount, 1, reason: 'underlying init must run exactly once');
    expect(mediaKitInitialized, isTrue);
  });
}
