// packages/encarta_assets/lib/src/encarta_assets_base.dart
import 'dart:io';

import 'package:encarta_data/encarta_data.dart';
import 'package:path/path.dart' as p;

import 'asset_config.dart';

/// Asset resolution + the entry point for media widgets.
///
/// Holds a read-only [EncartaDb] and an [AssetConfig]. This class owns
/// `dart:io`; the renderer never does file IO directly. `inlineBmp` (Task 6)
/// resolves `inlinebmp` references directly through `db.assetByBaggageId`.
class EncartaAssets {
  final EncartaDb db;
  final AssetConfig config;

  /// Locked positional constructor (matches the shared contract exactly).
  EncartaAssets(this.db, this.config);

  /// Test constructor: builds an instance without opening the real (685 MB) DB.
  /// Pass a fake [db] to exercise `inlineBmp`'s `assetByBaggageId` lookup; omit
  /// it for pure file-resolution tests (a throwing stand-in is used).
  EncartaAssets.forTesting(this.config, {EncartaDb? db})
      : db = db ?? _UnusedDb();

  /// Resolve a storage-relative asset path (e.g. `image/abc.jpg`,
  /// `other/xx.dib`) to a concrete [File].
  ///
  /// PREFERS `<dataDir>/assets_derived/<assetPath>`; FALLS BACK to
  /// `<dataDir>/assets/<assetPath>`; returns null if neither exists.
  File? resolvePath(String assetPath) {
    final derived = File(p.join(config.derivedDir, assetPath));
    if (derived.existsSync()) return derived;
    final original = File(p.join(config.assetsDir, assetPath));
    if (original.existsSync()) return original;
    return null;
  }
}

/// Never-used DB stand-in for [EncartaAssets.forTesting] when no fake is given.
/// Any access throws, so tests that accidentally hit a DB path fail loudly.
class _UnusedDb implements EncartaDb {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('EncartaAssets.forTesting has no database');
}
