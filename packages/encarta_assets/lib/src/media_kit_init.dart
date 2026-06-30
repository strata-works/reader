// packages/encarta_assets/lib/src/media_kit_init.dart
import 'package:media_kit/media_kit.dart';

bool _initialized = false;

/// Override this in tests to avoid spinning up libmpv in a headless environment.
/// In production code, leave this as `null` to use [MediaKit.ensureInitialized].
void Function()? mediaKitInitOverride;

/// True once [ensureMediaKit] has run.
bool get mediaKitInitialized => _initialized;

/// One-time, idempotent `media_kit` initialization. Call once in the app's
/// `main()`; media widgets also call it defensively before creating a Player.
void ensureMediaKit() {
  if (_initialized) return;
  (mediaKitInitOverride ?? MediaKit.ensureInitialized)();
  _initialized = true;
}

/// Reset the guard. Intended for use in tests only.
// ignore: avoid_positional_boolean_parameters
void resetMediaKitGuard() {
  _initialized = false;
  mediaKitInitOverride = null;
}
