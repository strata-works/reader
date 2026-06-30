// packages/encarta_assets/lib/encarta_assets.dart
/// Asset resolution + media playback for the Encarta reader.
///
/// This is the ONLY package allowed to import `dart:io` and `media_kit`.
/// It depends on `encarta_data` but never on `encarta_render`.
library;

// Public API is exported as each piece lands:
export 'src/asset_config.dart';
export 'src/dib_shim.dart';
export 'src/encarta_assets_base.dart';
export 'src/encarta_image.dart';
export 'src/inline_bmp_view.dart';
export 'src/media_kit_init.dart';
export 'src/encarta_audio.dart';
export 'src/encarta_video.dart';

/// Sentinel proving the barrel compiles and is wired into the workspace.
const String kEncartaAssetsLibraryName = 'encarta_assets';
