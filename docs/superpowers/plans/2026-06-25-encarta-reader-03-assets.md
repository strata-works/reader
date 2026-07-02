# encarta_assets (Unit 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `encarta_assets` Flutter package: resolve hashed asset files (preferring derived over original), render `.dib` bitmaps today via a runtime BMP-header shim, resolve `inlinebmp` references gracefully, and play WMA/WMV originals on desktop via `media_kit` — all with graceful degradation (never crash, never blank).

**Architecture:** A Flutter package that owns `dart:io` and `media_kit`. It depends on `encarta_data` (for `MediaItem` and `EncartaDb`) but **not** on `encarta_render`. The renderer stays storage/format-agnostic and calls into this package only through the injected `AssetResolver` typedef (`Widget Function(String inlineId, int inlineType)`), which `EncartaAssets.inlineBmp` satisfies. The package exposes file-resolution (`resolvePath`), a cached `.dib`→BMP shim, and three widgets (`EncartaImage`, `EncartaAudio`, `EncartaVideo`).

**Tech Stack:** Flutter 3.42.0 beta / Dart 3.12 beta; macOS arm64; `encarta_data` (path dep); `media_kit ^1.1.11` + `media_kit_video ^1.2.5` + `media_kit_libs_macos_audio ^1.0.4` + `media_kit_libs_macos_video ^1.1.4`; `path ^1.9.0`. Pub workspace member (`resolution: workspace`, single shared lockfile).

## Global Constraints

- Toolchain: Flutter 3.42.0 beta / Dart 3.12 beta; target macOS arm64.
- This package is the **only** unit allowed to import `dart:io` and `media_kit`. `encarta_render` must never import either.
- This package depends on `encarta_data` (path) but **must not** depend on `encarta_render`.
- DB is read-only; this package never writes the corpus. It only reads asset files off disk.
- Data dir is configurable via `AssetConfig(dataDir)`; default `/Users/nexus/projects/experiments/strata/quarry/build`.
- `asset.path` is relative to `<dataDir>/assets/` and already includes the subdir (e.g. `image/ae3ce60978a8b1e7.jpg`, `other/5466cdd6eab010ec.dib`).
- Resolution always **prefers** `assets_derived/`, **falls back** to `assets/`, returns null if neither exists.
- Graceful degradation: missing/unresolved asset → placeholder + caption/credit; un-playable media → poster + "media unavailable"; `inlineBmp` miss → small placeholder. Never throw out of a widget, never render blank.
- Decoded-image and `.dib`-conversion results are cached; `media_kit` players are lazy-initialized.
- TDD throughout: write failing test → run-fail → minimal impl → run-pass → commit. Frequent commits.
- Flutter package → use `flutter test`. Run from `packages/encarta_assets`.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/encarta_assets/pubspec.yaml` | Package manifest; deps; workspace member. |
| `packages/encarta_assets/lib/encarta_assets.dart` | Public library barrel; exports the public API. |
| `packages/encarta_assets/lib/src/asset_config.dart` | `AssetConfig(dataDir)` with `assetsDir` / `derivedDir`. |
| `packages/encarta_assets/lib/src/encarta_assets_base.dart` | `EncartaAssets` (holds `EncartaDb` + `AssetConfig`); `resolvePath`, `inlineBmp(inlineId, inlineType)`. |
| `packages/encarta_assets/lib/src/dib_shim.dart` | `DibShim`: cached `.dib`→BMP-with-header byte transform. |
| `packages/encarta_assets/lib/src/encarta_image.dart` | `EncartaImage` widget (resolve + `.dib` shim + placeholder). |
| `packages/encarta_assets/lib/src/inline_bmp_view.dart` | Internal widget returned by `inlineBmp`; placeholder on miss. |
| `packages/encarta_assets/lib/src/encarta_audio.dart` | `EncartaAudio` widget (media_kit, lazy player, poster on failure). |
| `packages/encarta_assets/lib/src/encarta_video.dart` | `EncartaVideo` widget (media_kit + media_kit_video, lazy, poster on failure). |
| `packages/encarta_assets/lib/src/media_kit_init.dart` | `ensureMediaKit()` one-time `MediaKit.ensureInitialized()` guard. |
| `packages/encarta_assets/test/asset_config_test.dart` | `AssetConfig` tests. |
| `packages/encarta_assets/test/resolve_path_test.dart` | `resolvePath` three-case tests with fake files. |
| `packages/encarta_assets/test/dib_shim_test.dart` | `.dib` header-prepend test with a synthetic DIB. |
| `packages/encarta_assets/test/inline_bmp_test.dart` | `inlineBmp` graceful-fallback + resolved-path widget tests. |
| `packages/encarta_assets/test/encarta_image_test.dart` | `EncartaImage` placeholder + resolve widget tests. |
| `packages/encarta_assets/test/encarta_media_test.dart` | `EncartaAudio` / `EncartaVideo` poster-on-miss widget tests. |
| `packages/encarta_assets/tool/probe_inlinebmp.dart` | Runtime DB probe script for the `inlinebmp` verification task. |

---

## Task 1: Package scaffold + library barrel

**Files:**
- Create: `packages/encarta_assets/pubspec.yaml`
- Create: `packages/encarta_assets/lib/encarta_assets.dart`
- Create: `packages/encarta_assets/test/scaffold_test.dart`

**Interfaces:**
- Consumes: nothing yet (depends on `encarta_data` path for later tasks).
- Produces: the importable library `package:encarta_assets/encarta_assets.dart` and a `kEncartaAssetsLibraryName` sentinel proving the package compiles and is on the workspace.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/scaffold_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library barrel is importable and exposes the sentinel', () {
    expect(kEncartaAssetsLibraryName, 'encarta_assets');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/scaffold_test.dart
```

Expected FAIL: `Target of URI doesn't exist: 'package:encarta_assets/encarta_assets.dart'` / `Undefined name 'kEncartaAssetsLibraryName'` (the package and barrel do not exist yet).

- [ ] **Step 3: Write minimal implementation**

```yaml
# packages/encarta_assets/pubspec.yaml
name: encarta_assets
description: Asset resolution and media playback widgets for the Encarta reader.
publish_to: none
resolution: workspace

environment:
  sdk: '>=3.12.0-0 <4.0.0'
  flutter: '>=3.42.0'

dependencies:
  flutter:
    sdk: flutter
  encarta_data:
    path: ../encarta_data
  media_kit: ^1.1.11
  media_kit_video: ^1.2.5
  media_kit_libs_macos_audio: ^1.0.4
  media_kit_libs_macos_video: ^1.1.4
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
```

> Also append `packages/encarta_assets` (explicit entry, no globs) to the root
> `reader/pubspec.yaml` `workspace:` members list so this package joins the shared
> single-lockfile workspace.

```dart
// packages/encarta_assets/lib/encarta_assets.dart
/// Asset resolution + media playback for the Encarta reader.
///
/// This is the ONLY package allowed to import `dart:io` and `media_kit`.
/// It depends on `encarta_data` but never on `encarta_render`.
library encarta_assets;

/// Sentinel proving the barrel compiles and is wired into the workspace.
const String kEncartaAssetsLibraryName = 'encarta_assets';

// Public API is exported as each piece lands:
// export 'src/asset_config.dart';
// export 'src/encarta_assets_base.dart';
// export 'src/dib_shim.dart';
// export 'src/encarta_image.dart';
// export 'src/encarta_audio.dart';
// export 'src/encarta_video.dart';
```

Then resolve the workspace once so the path dep and lockfile are wired:

```bash
cd packages/encarta_assets && flutter pub get
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/scaffold_test.dart
```

Expected PASS: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/pubspec.yaml packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/scaffold_test.dart && git commit -m "feat(assets): scaffold encarta_assets package + library barrel"
```

---

## Task 2: `AssetConfig`

**Files:**
- Create: `packages/encarta_assets/lib/src/asset_config.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/asset_config_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class AssetConfig { final String dataDir; const AssetConfig(this.dataDir); String get assetsDir; String get derivedDir; }` and `const AssetConfig.defaultConfig()`. `assetsDir => <dataDir>/assets`, `derivedDir => <dataDir>/assets_derived`. Later tasks build paths off these.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/asset_config_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('assetsDir and derivedDir are joined under dataDir', () {
    const cfg = AssetConfig('/data/root');
    expect(cfg.assetsDir, p.join('/data/root', 'assets'));
    expect(cfg.derivedDir, p.join('/data/root', 'assets_derived'));
  });

  test('default config points at the quarry build dir', () {
    const cfg = AssetConfig.defaultConfig();
    expect(cfg.dataDir,
        '/Users/nexus/projects/experiments/strata/quarry/build');
    expect(
        cfg.assetsDir,
        '/Users/nexus/projects/experiments/strata/quarry/build/assets');
    expect(cfg.derivedDir,
        '/Users/nexus/projects/experiments/strata/quarry/build/assets_derived');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/asset_config_test.dart
```

Expected FAIL: `Undefined name 'AssetConfig'` (class not defined / not exported).

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/asset_config.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/asset_config_test.dart
```

Expected PASS: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/asset_config.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/asset_config_test.dart && git commit -m "feat(assets): AssetConfig with assetsDir/derivedDir and default data dir"
```

---

## Task 3: `EncartaAssets.resolvePath` (prefer derived, fall back to original)

**Files:**
- Create: `packages/encarta_assets/lib/src/encarta_assets_base.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/resolve_path_test.dart`

**Interfaces:**
- Consumes: `AssetConfig`; `EncartaDb` (from `package:encarta_data/encarta_data.dart`) — held but not called in this task. `inlineBmp` (Task 6) calls the locked additive `EncartaDb.assetByBaggageId(String) → Future<AssetRow?>` (Unit 1 owns `AssetRow{baggageId,hash,kind,ext,path}`).
- Produces: `class EncartaAssets { EncartaAssets(this.db, this.config); final EncartaDb db; final AssetConfig config; File? resolvePath(String assetPath); }`. Later tasks (`EncartaImage`, `inlineBmp`, media widgets) all call `resolvePath`.

> Note: the constructor is exactly the locked positional signature `EncartaAssets(this.db, this.config)` — no extra params. An additive named constructor `EncartaAssets.forTesting(this.config, {EncartaDb? db})` lets tests run without opening the 685 MB DB. `resolvePath` does pure path joins + existence checks; tests inject fake files via a temp dir, so no real DB is opened.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/resolve_path_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late EncartaAssets assets;

  setUp(() {
    root = Directory.systemTemp.createTempSync('encarta_assets_resolve');
    // resolvePath never touches the DB; forTesting supplies a throwing stand-in.
    assets = EncartaAssets.forTesting(AssetConfig(root.path));
  });

  tearDown(() => root.deleteSync(recursive: true));

  void writeFile(String dir, String rel) {
    final f = File(p.join(root.path, dir, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync([1, 2, 3]);
  }

  test('prefers derived when both derived and original exist', () {
    writeFile('assets', 'image/abc.jpg');
    writeFile('assets_derived', 'image/abc.jpg');
    final f = assets.resolvePath('image/abc.jpg');
    expect(f, isNotNull);
    expect(f!.path, p.join(root.path, 'assets_derived', 'image/abc.jpg'));
  });

  test('falls back to original when only original exists', () {
    writeFile('assets', 'image/abc.jpg');
    final f = assets.resolvePath('image/abc.jpg');
    expect(f, isNotNull);
    expect(f!.path, p.join(root.path, 'assets', 'image/abc.jpg'));
  });

  test('returns null when neither exists', () {
    final f = assets.resolvePath('image/missing.jpg');
    expect(f, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/resolve_path_test.dart
```

Expected FAIL: `The method 'forTesting' isn't defined for the type 'EncartaAssets'` / `Undefined name 'EncartaAssets'` (class not defined).

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/encarta_assets_base.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/resolve_path_test.dart
```

Expected PASS: 3 tests pass (derived-present, original-only, missing).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/encarta_assets_base.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/resolve_path_test.dart && git commit -m "feat(assets): EncartaAssets.resolvePath prefers derived, falls back to original"
```

---

## Task 4: `.dib` runtime BMP-header-prepend shim (cached)

**Files:**
- Create: `packages/encarta_assets/lib/src/dib_shim.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/dib_shim_test.dart`

**Interfaces:**
- Consumes: nothing (pure bytes-in/bytes-out).
- Produces: `class DibShim { static Uint8List toBmp(Uint8List dib); Uint8List toBmpCached(String cacheKey, Uint8List dib); }`. `EncartaImage`/`inlineBmp` call this when the resolved file ext is `.dib`.

> A raw `.dib` is a BMP missing the 14-byte `BITMAPFILEHEADER`. The shim reads the
> `BITMAPINFOHEADER` to compute the pixel-data offset (`bfOffBits`) and total file
> size, then prepends a correct `BM` header so `Image.memory` decodes it today —
> before any transcode exists. Results are cached by file path.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/dib_shim_test.dart
import 'dart:typed_data';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal 2x2, 24-bit DIB (BITMAPINFOHEADER, no palette).
/// Each 2px row = 6 bytes padded to 8 → 16 bytes of pixel data.
Uint8List buildSyntheticDib() {
  final info = ByteData(40);
  info.setUint32(0, 40, Endian.little); // biSize
  info.setInt32(4, 2, Endian.little); // biWidth
  info.setInt32(8, 2, Endian.little); // biHeight
  info.setUint16(12, 1, Endian.little); // biPlanes
  info.setUint16(14, 24, Endian.little); // biBitCount
  info.setUint32(16, 0, Endian.little); // biCompression = BI_RGB
  info.setUint32(20, 16, Endian.little); // biSizeImage
  info.setUint32(32, 0, Endian.little); // biClrUsed = 0
  final pixels = Uint8List(16); // 2 rows * 8 bytes
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = i; // arbitrary distinguishable content
  }
  return Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...pixels]);
}

void main() {
  test('prepends a valid 14-byte BM header for a 24-bit DIB', () {
    final dib = buildSyntheticDib();
    final bmp = DibShim.toBmp(dib);

    // BM signature.
    expect(bmp[0], 0x42); // 'B'
    expect(bmp[1], 0x4D); // 'M'

    final bd = ByteData.sublistView(bmp);
    // bfSize == 14 + dib.length.
    expect(bd.getUint32(2, Endian.little), 14 + dib.length);
    // bfReserved1/2 == 0.
    expect(bd.getUint32(6, Endian.little), 0);
    // bfOffBits: no palette for 24-bit → 14 + 40 = 54.
    expect(bd.getUint32(10, Endian.little), 54);

    // Total length and that the DIB payload follows the header unchanged.
    expect(bmp.length, 14 + dib.length);
    expect(bmp.sublist(14), dib);
  });

  test('computes palette offset for an 8-bit DIB (256-color table)', () {
    final info = ByteData(40);
    info.setUint32(0, 40, Endian.little); // biSize
    info.setInt32(4, 1, Endian.little); // biWidth
    info.setInt32(8, 1, Endian.little); // biHeight
    info.setUint16(12, 1, Endian.little); // biPlanes
    info.setUint16(14, 8, Endian.little); // biBitCount = 8
    info.setUint32(16, 0, Endian.little); // biCompression
    info.setUint32(32, 0, Endian.little); // biClrUsed = 0 → 256 colors
    // 256 colors * 4 bytes + 4 bytes pixel row.
    final body = Uint8List(256 * 4 + 4);
    final dib =
        Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...body]);
    final bmp = DibShim.toBmp(dib);
    final bd = ByteData.sublistView(bmp);
    // bfOffBits = 14 + 40 + 256*4 = 1078.
    expect(bd.getUint32(10, Endian.little), 1078);
  });

  test('cache returns identical instance for the same key', () {
    final dib = buildSyntheticDib();
    final shim = DibShim();
    final a = shim.toBmpCached('k1', dib);
    final b = shim.toBmpCached('k1', dib);
    expect(identical(a, b), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/dib_shim_test.dart
```

Expected FAIL: `Undefined name 'DibShim'` (class not defined / not exported).

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/encarta_assets/lib/src/dib_shim.dart
import 'dart:typed_data';

/// Converts a raw `.dib` (a BMP without its 14-byte file header) into a complete
/// BMP byte buffer that `Image.memory` can decode today.
///
/// Layout of a DIB:  [DIB info header][optional color palette][pixel data].
/// We read the info header to compute the palette size, derive the pixel-data
/// offset (`bfOffBits`) and total file size, then prepend a correct
/// `BITMAPFILEHEADER` ("BM", size, reserved, offset).
class DibShim {
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Cached variant keyed by [cacheKey] (use the resolved file path).
  Uint8List toBmpCached(String cacheKey, Uint8List dib) =>
      _cache.putIfAbsent(cacheKey, () => toBmp(dib));

  /// Pure transform: prepend a valid 14-byte BMP file header.
  static Uint8List toBmp(Uint8List dib) {
    final info = ByteData.sublistView(dib);
    final biSize = info.getUint32(0, Endian.little);

    // BITMAPCOREHEADER (12) packs fields differently; everything Encarta ships
    // is BITMAPINFOHEADER (>=40), but handle the core case defensively.
    int bitCount;
    int clrUsed;
    int paletteEntryBytes;
    if (biSize == 12) {
      bitCount = info.getUint16(10, Endian.little);
      clrUsed = 0;
      paletteEntryBytes = 3; // RGBTRIPLE
    } else {
      bitCount = info.getUint16(14, Endian.little);
      clrUsed = info.getUint32(32, Endian.little);
      paletteEntryBytes = 4; // RGBQUAD
    }

    // Number of palette entries.
    var numColors = clrUsed;
    if (numColors == 0 && bitCount <= 8) {
      numColors = 1 << bitCount;
    }
    final paletteBytes = numColors * paletteEntryBytes;

    // BI_BITFIELDS (compression==3) with a >=40 header stores 3 (or 4 for
    // alpha-aware) 32-bit color masks before the pixel data.
    var extraMaskBytes = 0;
    if (biSize >= 40) {
      final compression = info.getUint32(16, Endian.little);
      if (compression == 3) extraMaskBytes = 12; // 3 DWORD masks
      if (compression == 6) extraMaskBytes = 16; // BI_ALPHABITFIELDS
    }

    const fileHeaderSize = 14;
    final offBits = fileHeaderSize + biSize + paletteBytes + extraMaskBytes;
    final fileSize = fileHeaderSize + dib.length;

    final out = Uint8List(fileSize);
    final header = ByteData.sublistView(out, 0, fileHeaderSize);
    header.setUint8(0, 0x42); // 'B'
    header.setUint8(1, 0x4D); // 'M'
    header.setUint32(2, fileSize, Endian.little); // bfSize
    header.setUint16(6, 0, Endian.little); // bfReserved1
    header.setUint16(8, 0, Endian.little); // bfReserved2
    header.setUint32(10, offBits, Endian.little); // bfOffBits
    out.setRange(fileHeaderSize, fileSize, dib);
    return out;
  }
}
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/dib_shim.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/dib_shim_test.dart
```

Expected PASS: 3 tests pass (24-bit header, 8-bit palette offset, cache identity).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/dib_shim.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/dib_shim_test.dart && git commit -m "feat(assets): cached .dib -> BMP runtime header-prepend shim"
```

---

## Task 5: `EncartaImage` widget (resolve + `.dib` shim + graceful placeholder)

**Files:**
- Create: `packages/encarta_assets/lib/src/encarta_image.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/encarta_image_test.dart`

**Interfaces:**
- Consumes: `MediaItem` (from `package:encarta_data/encarta_data.dart` — fields `assetPath`, `ext`, `caption`, `credit`), `resolvePath` (Task 3), `DibShim` (Task 4).
- Produces: `class EncartaImage extends StatelessWidget { const EncartaImage({super.key, required this.item, required this.assets, double maxWidth}); }`. Resolves via `resolvePath(item.assetPath)`; applies the `.dib` shim when `item.ext` is `.dib`; shows placeholder + caption/credit on miss (never blank). Task 6 (`inlineBmp`) renders an `EncartaImage` for resolved type-27 ids.

> Note: a `MediaItem` is required. `EncartaImage` takes the owning `EncartaAssets`
> so it can resolve files and share the cached `DibShim`. On miss it renders a
> labeled placeholder that still surfaces `caption`/`credit` (graceful
> degradation, §10).

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/encarta_image_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

MediaItem _item({required String path, required String ext, String? caption}) =>
    MediaItem(
      mediaRefid: 1,
      role: 'image',
      group: 'article',
      title: null,
      caption: caption,
      credit: 'Encarta',
      assetPath: path,
      ext: ext,
      kind: 'image',
    );

void main() {
  late Directory root;
  setUp(() =>
      root = Directory.systemTemp.createTempSync('encarta_assets_image'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('shows placeholder + caption/credit when asset is missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaImage(
          item: _item(
              path: 'image/missing.jpg', ext: '.jpg', caption: 'A caption'),
          assets: assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('encarta-image-placeholder')),
        findsOneWidget);
    expect(find.text('A caption'), findsOneWidget);
    expect(find.textContaining('Encarta'), findsOneWidget);
  });

  testWidgets('decodes a .dib via the shim and shows an Image', (tester) async {
    final dib = _syntheticDib();
    final f = File(p.join(root.path, 'assets', 'other', 'pic.dib'));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(dib);

    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaImage(
          item: _item(path: 'other/pic.dib', ext: '.dib'),
          assets: assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}

/// 2x2 24-bit DIB (same shape as the dib_shim test).
Uint8List _syntheticDib() {
  final info = ByteData(40);
  info.setUint32(0, 40, Endian.little);
  info.setInt32(4, 2, Endian.little);
  info.setInt32(8, 2, Endian.little);
  info.setUint16(12, 1, Endian.little);
  info.setUint16(14, 24, Endian.little);
  info.setUint32(16, 0, Endian.little);
  info.setUint32(20, 16, Endian.little);
  info.setUint32(32, 0, Endian.little);
  final pixels = Uint8List(16);
  return Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...pixels]);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/encarta_image_test.dart
```

Expected FAIL: `Undefined name 'EncartaImage'` (widget not defined / not exported).

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/encarta_assets/lib/src/encarta_image.dart
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import 'dib_shim.dart';
import 'encarta_assets_base.dart';

/// Renders a block-level article image from a [MediaItem]. Resolves the file
/// (preferring derived), applies the `.dib` shim when needed, and degrades to a
/// labeled placeholder (still showing caption/credit) on any miss.
class EncartaImage extends StatelessWidget {
  const EncartaImage({
    super.key,
    required this.item,
    required this.assets,
    this.maxWidth = 480,
  });

  final MediaItem item;
  final EncartaAssets assets;
  final double maxWidth;

  /// Shared so the `.dib`->BMP conversion cache survives across rebuilds.
  static final DibShim _sharedShim = DibShim();

  Future<Uint8List?> _load() async {
    try {
      // Prefer a derived PNG when the original is a .dib and a transcode exists.
      if (item.ext.toLowerCase() == '.dib') {
        final pngPath =
            '${item.assetPath.substring(0, item.assetPath.length - 4)}.png';
        final derivedPng = assets.resolvePath(pngPath);
        if (derivedPng != null) return derivedPng.readAsBytes();
      }
      final file = assets.resolvePath(item.assetPath);
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (item.ext.toLowerCase() == '.dib') {
        return _sharedShim.toBmpCached(file.path, bytes);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Uint8List?>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()));
              }
              final bytes = snap.data;
              if (bytes == null) return _placeholder(context);
              return Image.memory(bytes,
                  errorBuilder: (_, __, ___) => _placeholder(context));
            },
          ),
          if (item.caption != null && item.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.caption!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (item.credit != null && item.credit!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Credit: ${item.credit}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        key: const ValueKey('encarta-image-placeholder'),
        height: 120,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: const Icon(Icons.broken_image_outlined,
            size: 32, color: Color(0xFF9E9E9E)),
      );
}
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/encarta_image.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/encarta_image_test.dart
```

Expected PASS: 2 tests pass (missing → placeholder + caption/credit; `.dib` → `Image`).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/encarta_image.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/encarta_image_test.dart && git commit -m "feat(assets): EncartaImage with .dib shim + caption/credit placeholder degradation"
```

---

## Task 6: `inlinebmp` resolution — runtime verification + graceful `inlineBmp(inlineId, inlineType)`

**Files:**
- Create: `packages/encarta_assets/tool/probe_inlinebmp.dart`
- Create: `packages/encarta_assets/lib/src/inline_bmp_view.dart`
- Modify: `packages/encarta_assets/lib/src/encarta_assets_base.dart` (add `inlineBmp`)
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/inline_bmp_test.dart`

**Interfaces:**
- Consumes: `EncartaDb.assetByBaggageId(String) → Future<AssetRow?>` (Unit 1 owns `AssetRow{baggageId,hash,kind,ext,path}`), `resolvePath` (Task 3), `EncartaImage` (Task 5), `MediaItem` (from `package:encarta_data/encarta_data.dart`).
- Produces: `Widget EncartaAssets.inlineBmp(String inlineId, int inlineType)` — matches the renderer's `AssetResolver = Widget Function(String inlineId, int inlineType)` typedef **exactly**. Never throws; placeholder on type != 27 or any miss.

> **OPEN-QUESTION DELIVERABLE (verified at runtime 2026-06-25 against the real
> DB) — accepted as the canonical resolution.** `inlinebmp` ids come in two forms,
> distinguished by the `type` attribute the renderer passes as `inlineType`:
>
> - **`type == 27` → `inlineId = "<8-hex>"`** (e.g. `000f631b`). The id **IS the
>   `asset.baggage_id`**. Resolve via the additive `EncartaDb.assetByBaggageId` →
>   `AssetRow` → `resolvePath(row.path)` → render an `EncartaImage` (which applies
>   the `.dib` shim when `row.ext` is `.dib`). Verified: `000f631b →
>   image/a1456f3d47088045.gif`, `000f6e85 → image/ce867b4ff2ffafc0.gif`, etc.
>   These are real, resolvable inline images (often `.gif`, not `.dib`).
> - **`type != 27` (28 etc.) → `inlineId = "<NAME>.DIB"`** (e.g. `IIN7A0DF.DIB`,
>   case-varying). This is an **original Encarta `.DIB` filename**, NOT present as
>   `baggage_id`/`path`/`source` in the asset table (`asset.source` is the EIT
>   container name like `MDDLX01.EIT`). Unresolvable with current ETL → render the
>   placeholder. (167 `.dib` files exist on disk under `other/` but lack a
>   name→hash index.)
>
> **Algorithm for `inlineBmp(inlineId, inlineType)`:** if `inlineType != 27` →
> placeholder immediately (no DB hit). Else `db.assetByBaggageId(inlineId)`; on a
> non-null `AssetRow` build an `EncartaImage` from it (the `.dib` shim + derived-PNG
> preference are handled inside `EncartaImage`); on null/error → placeholder. Never
> throws. The resolution depends directly on `EncartaDb` held by the locked
> positional ctor `EncartaAssets(this.db, this.config)` — no injected indirection.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/inline_bmp_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Fakes only `assetByBaggageId`; any other DB access throws loudly.
class _FakeDb implements EncartaDb {
  _FakeDb(this._rows);
  final Map<String, AssetRow> _rows;

  @override
  Future<AssetRow?> assetByBaggageId(String baggageId) async =>
      _rows[baggageId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('only assetByBaggageId is faked');
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('encarta_assets_inlinebmp');
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('type != 27 (original NAME.DIB) → placeholder, no DB hit',
      (tester) async {
    // forTesting with the throwing stand-in DB proves no lookup is attempted.
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: assets.inlineBmp('IIN7A0DF.DIB', 28))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsOneWidget);
  });

  testWidgets('type 27 with unknown baggage id → placeholder', (tester) async {
    final assets = EncartaAssets.forTesting(
      AssetConfig(root.path),
      db: _FakeDb(const {}),
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: assets.inlineBmp('000f631b', 27))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsOneWidget);
  });

  testWidgets('type 27 baggage id resolves to a file → renders an Image',
      (tester) async {
    // Write a tiny valid PNG so Image.memory can decode it.
    final f = File(p.join(root.path, 'assets', 'image', 'pic.png'));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(_onePixelPng());

    final assets = EncartaAssets.forTesting(
      AssetConfig(root.path),
      db: _FakeDb({
        '000f631b': const AssetRow(
          baggageId: '000f631b',
          hash: 'deadbeef',
          kind: 'image',
          ext: '.png',
          path: 'image/pic.png',
        ),
      }),
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: assets.inlineBmp('000f631b', 27))));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsNothing);
  });
}

/// Smallest valid 1x1 PNG (transparent).
List<int> _onePixelPng() => const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ];
```

> Note: the test constructs `AssetRow` with named params per the contract's
> `AssetRow{baggageId,hash,kind,ext,path}`. If Unit 1's generated `AssetRow` uses a
> different constructor shape, mirror it here — the fields are the same.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/inline_bmp_test.dart
```

Expected FAIL: `The method 'inlineBmp' isn't defined for the type 'EncartaAssets'` (method not added yet).

- [ ] **Step 3: Write minimal implementation**

First the verification probe script (the task's investigation deliverable — runs against the real DB and re-confirms the mapping via the live `assetByBaggageId`):

```dart
// packages/encarta_assets/tool/probe_inlinebmp.dart
//
// Runtime verification of the inlinebmp id -> asset mapping.
// Run:  dart run tool/probe_inlinebmp.dart
//
// Findings (2026-06-25): type=27 ids ARE asset.baggage_id (resolvable);
// type=28 ids are original NAME.DIB filenames with no asset-table mapping
// (graceful placeholder). This script re-confirms that against the live DB.
import 'package:encarta_data/encarta_data.dart';

const _dbPath =
    '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';

Future<void> main() async {
  final db = await EncartaDb.open(_dbPath);
  // Sample type-27 ids confirmed to be baggage_ids during planning.
  const type27 = <String>['000f631b', '000f6e85', '000f3be2'];
  // Sample type-28 NAME.DIB ids confirmed NOT resolvable.
  const type28 = <String>['IIN7A0DF.DIB', 'INN7A0E4.DIB'];

  print('--- type=27 (expect: resolves via assetByBaggageId) ---');
  for (final id in type27) {
    final row = await db.assetByBaggageId(id);
    print('$id -> ${row?.path ?? 'NULL (unexpected!)'}');
  }
  print('--- type=28 NAME.DIB (expect: NULL → placeholder) ---');
  for (final id in type28) {
    final row = await db.assetByBaggageId(id);
    print('$id -> ${row?.path ?? 'NULL (expected; placeholder)'}');
  }
  await db.close();
}
```

Then the inline-bitmap view widget:

```dart
// packages/encarta_assets/lib/src/inline_bmp_view.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import 'encarta_assets_base.dart';
import 'encarta_image.dart';

/// Inline bitmap widget returned by [EncartaAssets.inlineBmp].
///
/// type==27: [inlineId] is an `asset.baggage_id` → resolve it through
/// `db.assetByBaggageId` and render an [EncartaImage] (which applies the `.dib`
/// shim if needed). type!=27: original NAME.DIB form, unresolvable today → small
/// placeholder. Never throws.
class InlineBmpView extends StatelessWidget {
  const InlineBmpView({
    super.key,
    required this.assets,
    required this.inlineId,
    required this.inlineType,
  });

  final EncartaAssets assets;
  final String inlineId;
  final int inlineType;

  static const _placeholderKey = ValueKey('inlinebmp-placeholder');

  Future<AssetRow?> _lookup() async {
    try {
      return await assets.db.assetByBaggageId(inlineId);
    } catch (_) {
      return null; // never throw out of an inline glyph
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only type-27 inlinebmp ids are asset.baggage_id values (verified).
    if (inlineType != 27) return _placeholder();
    return FutureBuilder<AssetRow?>(
      future: _lookup(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(width: 16, height: 16);
        }
        final row = snap.data;
        if (row == null) return _placeholder();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: EncartaImage(
            item: MediaItem(
              mediaRefid: -1,
              role: 'inlinebmp',
              group: 'inline',
              title: null,
              caption: null,
              credit: null,
              assetPath: row.path,
              ext: row.ext,
              kind: row.kind,
            ),
            assets: assets,
            maxWidth: 240,
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        key: _placeholderKey,
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Icon(Icons.image_not_supported, size: 12),
      );
}
```

Then add `inlineBmp` to `EncartaAssets`:

```dart
// packages/encarta_assets/lib/src/encarta_assets_base.dart  (add imports + method)
// at top, with the other imports:
import 'package:flutter/widgets.dart';

import 'inline_bmp_view.dart';

// inside class EncartaAssets, add the method:
  /// Builds an inline-bitmap widget for an `inlinebmp` reference. Matches the
  /// renderer's `AssetResolver = Widget Function(String inlineId, int inlineType)`.
  /// type==27: [inlineId] is an asset.baggage_id → resolve + render EncartaImage.
  /// type!=27: original-name form (unresolvable today) → placeholder. Never throws.
  Widget inlineBmp(String inlineId, int inlineType) =>
      InlineBmpView(assets: this, inlineId: inlineId, inlineType: inlineType);
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/inline_bmp_view.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/inline_bmp_test.dart
```

Expected PASS: 3 tests pass (type 28 → placeholder/no DB hit; type 27 unknown id → placeholder; type 27 resolved → `Image`).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/tool/probe_inlinebmp.dart packages/encarta_assets/lib/src/inline_bmp_view.dart packages/encarta_assets/lib/src/encarta_assets_base.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/inline_bmp_test.dart && git commit -m "feat(assets): inlineBmp(inlineId, inlineType) — type-27 baggage-id resolution via assetByBaggageId + graceful placeholder + DB probe"
```

---

## Task 7: `media_kit` init guard

**Files:**
- Create: `packages/encarta_assets/lib/src/media_kit_init.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/media_kit_init_test.dart`

**Interfaces:**
- Consumes: `MediaKit.ensureInitialized()` from `package:media_kit`.
- Produces: `void ensureMediaKit()` — idempotent one-time init the app calls in `main()` and the media widgets call defensively. Tracks `mediaKitInitialized`.

> `media_kit` requires a one-time `MediaKit.ensureInitialized()`. We wrap it so it
> is safe to call repeatedly and so widget tests can assert the guard without
> spinning up libmpv twice.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/media_kit_init_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureMediaKit is idempotent and flips the initialized flag', () {
    expect(mediaKitInitialized, isFalse);
    ensureMediaKit();
    expect(mediaKitInitialized, isTrue);
    // Second call must not throw.
    ensureMediaKit();
    expect(mediaKitInitialized, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/media_kit_init_test.dart
```

Expected FAIL: `Undefined name 'ensureMediaKit'` / `Undefined name 'mediaKitInitialized'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/encarta_assets/lib/src/media_kit_init.dart
import 'package:media_kit/media_kit.dart';

bool _initialized = false;

/// True once [ensureMediaKit] has run.
bool get mediaKitInitialized => _initialized;

/// One-time, idempotent `media_kit` initialization. Call once in the app's
/// `main()`; media widgets also call it defensively before creating a Player.
void ensureMediaKit() {
  if (_initialized) return;
  MediaKit.ensureInitialized();
  _initialized = true;
}
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the export)
export 'src/media_kit_init.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/media_kit_init_test.dart
```

Expected PASS: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/media_kit_init.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/media_kit_init_test.dart && git commit -m "feat(assets): idempotent ensureMediaKit() init guard"
```

---

## Task 8: `EncartaAudio` + `EncartaVideo` widgets (lazy media_kit, poster on failure)

**Files:**
- Create: `packages/encarta_assets/lib/src/encarta_audio.dart`
- Create: `packages/encarta_assets/lib/src/encarta_video.dart`
- Modify: `packages/encarta_assets/lib/encarta_assets.dart` (export)
- Create: `packages/encarta_assets/test/encarta_media_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `resolvePath`, `ensureMediaKit()`, `Player`/`VideoController` from `media_kit` / `media_kit_video`.
- Produces: `class EncartaAudio extends StatefulWidget { const EncartaAudio({super.key, required this.item, required this.assets}); }` and `class EncartaVideo extends StatefulWidget { const EncartaVideo({super.key, required this.item, required this.assets}); }`. Both resolve the file first; if missing → "media unavailable" poster and **no** player is created (lazy init). On a resolved file the player is created in `initState`'s post-resolve path.

> The poster-on-miss path is fully testable without libmpv: when `resolvePath`
> returns null we render the poster and never touch `media_kit`. Actual playback
> of a resolved WMA/WMV is exercised in the app integration smoke test on a real
> machine (libmpv is a native dep), not in unit tests.

- [ ] **Step 1: Write the failing test**

```dart
// packages/encarta_assets/test/encarta_media_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _audio() => MediaItem(
      mediaRefid: 7,
      role: 'audio',
      group: 'media',
      title: 'Clip',
      caption: null,
      credit: null,
      assetPath: 'audio/missing.wma',
      ext: '.wma',
      kind: 'audio',
    );

MediaItem _video() => MediaItem(
      mediaRefid: 8,
      role: 'item',
      group: 'media',
      title: 'Movie',
      caption: null,
      credit: null,
      assetPath: 'other/missing.wmv',
      ext: '.wmv',
      kind: 'other',
    );

void main() {
  late Directory root;
  setUp(() =>
      root = Directory.systemTemp.createTempSync('encarta_assets_media'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('EncartaAudio shows "media unavailable" poster when missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EncartaAudio(item: _audio(), assets: assets))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media-unavailable')), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);
  });

  testWidgets('EncartaVideo shows "media unavailable" poster when missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EncartaVideo(item: _video(), assets: assets))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media-unavailable')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/encarta_assets && flutter test test/encarta_media_test.dart
```

Expected FAIL: `Undefined name 'EncartaAudio'` / `Undefined name 'EncartaVideo'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/encarta_assets/lib/src/encarta_audio.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'encarta_assets_base.dart';
import 'media_kit_init.dart';

/// Plays an audio asset (WMA originals supported on desktop via media_kit).
/// The Player is lazy-initialized only after the file resolves; a missing file
/// shows a "media unavailable" poster and never creates a Player.
class EncartaAudio extends StatefulWidget {
  const EncartaAudio({super.key, required this.item, required this.assets});

  final MediaItem item;
  final EncartaAssets assets;

  @override
  State<EncartaAudio> createState() => _EncartaAudioState();
}

class _EncartaAudioState extends State<EncartaAudio> {
  Player? _player;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    final file = widget.assets.resolvePath(widget.item.assetPath);
    if (file == null) {
      _unavailable = true;
      return;
    }
    try {
      ensureMediaKit();
      final player = Player();
      _player = player;
      player.open(Media(file.path), play: false);
    } catch (_) {
      _unavailable = true;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable || _player == null) {
      return _Poster(label: widget.item.title ?? 'Audio');
    }
    final player = _player!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => player.play(),
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => player.pause(),
        ),
        Flexible(child: Text(widget.item.title ?? 'Audio')),
      ],
    );
  }
}

/// Shared "media unavailable" poster.
class _Poster extends StatelessWidget {
  const _Poster({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('media-unavailable'),
        height: 80,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off, color: Color(0xFF9E9E9E)),
            Text('$label — media unavailable',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}
```

```dart
// packages/encarta_assets/lib/src/encarta_video.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'encarta_assets_base.dart';
import 'media_kit_init.dart';

/// Plays a video asset (WMV originals supported on desktop via media_kit).
/// Player + VideoController are lazy-initialized after the file resolves; a
/// missing file shows a "media unavailable" poster and creates no Player.
class EncartaVideo extends StatefulWidget {
  const EncartaVideo({super.key, required this.item, required this.assets});

  final MediaItem item;
  final EncartaAssets assets;

  @override
  State<EncartaVideo> createState() => _EncartaVideoState();
}

class _EncartaVideoState extends State<EncartaVideo> {
  Player? _player;
  VideoController? _controller;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    final file = widget.assets.resolvePath(widget.item.assetPath);
    if (file == null) {
      _unavailable = true;
      return;
    }
    try {
      ensureMediaKit();
      final player = Player();
      _player = player;
      _controller = VideoController(player);
      player.open(Media(file.path), play: false);
    } catch (_) {
      _unavailable = true;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unavailable || controller == null) {
      return Container(
        key: const ValueKey('media-unavailable'),
        height: 180,
        alignment: Alignment.center,
        color: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Color(0xFFBDBDBD)),
            Text('${widget.item.title ?? 'Video'} — media unavailable',
                style: const TextStyle(color: Color(0xFFBDBDBD))),
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(controller: controller),
    );
  }
}
```

```dart
// packages/encarta_assets/lib/encarta_assets.dart  (add the exports)
export 'src/encarta_audio.dart';
export 'src/encarta_video.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/encarta_assets && flutter test test/encarta_media_test.dart
```

Expected PASS: 2 tests pass (audio + video poster-on-miss, no player created).

- [ ] **Step 5: Commit**

```bash
git add packages/encarta_assets/lib/src/encarta_audio.dart packages/encarta_assets/lib/src/encarta_video.dart packages/encarta_assets/lib/encarta_assets.dart packages/encarta_assets/test/encarta_media_test.dart && git commit -m "feat(assets): EncartaAudio/EncartaVideo via media_kit with lazy players + unavailable poster"
```

---

## Task 9: `float_column` maintenance/popularity check (decision record only — do NOT add the dep)

**Files:**
- Create: `packages/encarta_assets/doc/float_column_decision.md`

**Interfaces:**
- Consumes: nothing.
- Produces: a written decision record. **No code, no dependency added.** Default stays block-level media per spec §5/§6/§7.

> Spec §6 / open-question §11.6: `float_column` is the sanctioned tool for future
> text-wrap-around-image, **pending a quick maintenance/popularity check before
> depending on it.** This task performs that check and records the verdict. Media
> stays block-level for now; do not edit `pubspec.yaml`.

- [ ] **Step 1: Run the maintenance/popularity check**

```bash
# Pub health: published versions, last-publish date, likes, popularity, points.
dart pub global activate pana >/dev/null 2>&1 || true
echo "Open https://pub.dev/packages/float_column and record:"
echo " - latest version + publish date (actively maintained within ~12 months?)"
echo " - likes / popularity percentile / pub points"
echo " - null-safety + Dart 3 compatibility + declared platforms (macos/desktop)"
echo " - open issues touching desktop/Flutter 3.3x+"
```

- [ ] **Step 2: Write the decision record**

```markdown
<!-- packages/encarta_assets/doc/float_column_decision.md -->
# float_column — maintenance/popularity check (open question §11.6)

**Decision:** Do NOT add `float_column` yet. Default media presentation remains
block-level (rail / between paragraphs), which is simpler and more
Encarta-faithful (spec §5, §6, §7). Tiny `inlinebmp` glyphs are the only truly
inline images and are handled by `EncartaAssets.inlineBmp` (no float needed).

**Check performed (date: <fill at runtime>):**
- Latest version / last publish: <fill>
- Likes / popularity / pub points: <fill>
- Dart 3 + null-safety: <fill>; declared platforms include macOS/desktop: <fill>
- Notable open issues on recent Flutter/desktop: <fill>

**Adopt-it trigger (revisit only if all hold):** a concrete design need for true
text-wrap-around-image emerges AND the package is actively maintained (published
within ~12 months), Dart-3/null-safe, and lists desktop support. If adopted, it
is a single Flutter dependency added to `encarta_assets` (which already owns the
media layer) — not to `encarta_render`, keeping the renderer dependency-free.
```

- [ ] **Step 3: Commit**

```bash
git add packages/encarta_assets/doc/float_column_decision.md && git commit -m "docs(assets): record float_column maintenance check; keep block-level media default"
```

---

## Self-review notes

**Spec sections covered by this unit:**
- §3 (read path steps 4): asset resolution preferring derived over original.
- §6 `encarta_assets` in full: resolve, `.dib` runtime header shim (cached), `media_kit` for WMA/WMV originals, exposed widgets `EncartaImage`/`EncartaAudio`/`EncartaVideo` + the `AssetResolver`-shaped `inlineBmp`, and the `float_column` note.
- §9: image rendering incl. `.dib` shim; audio+video playback of originals via `media_kit`; reader never blocks on the transcode pipeline (prefers derived when present).
- §10 (asset parts): missing/unresolved asset → placeholder + caption/credit; un-playable media → poster + "media unavailable"; decoded-image + `.dib` caches; lazy `media_kit` players.
- §11 open questions: §11.6 (`float_column` check, Task 9) and the cross-cutting `inlinebmp` mapping (CONTRACT open question 2, Task 6).

**Cross-plan seam (locked with the coordinator 2026-06-25):** the renderer's
`AssetResolver` typedef is `Widget Function(String inlineId, int inlineType)` and
`EncartaAssets.inlineBmp(String inlineId, int inlineType)` matches it exactly.
Resolution depends directly on the additive `EncartaDb.assetByBaggageId(String) →
Future<AssetRow?>` (Unit 1 owns `AssetRow{baggageId,hash,kind,ext,path}`) — no
injected indirection; the locked positional ctor `EncartaAssets(this.db, this.config)`
already holds the `EncartaDb`.

**Verified at runtime (2026-06-25, against the real DB) — the `inlinebmp` deliverable:**
- `inlinebmp type="27" id="<8-hex>"` → the id IS `asset.baggage_id`; resolves directly via `assetByBaggageId` to an asset path (verified `000f631b → image/a1456f3d47088045.gif`, plus `000f6e85`, `000f3be2`, `000f2435`, `000f11e9`). These are real, resolvable inline images (mostly `.gif`).
- `inlinebmp type="28" id="<NAME>.DIB"` → original Encarta filename; NOT a `baggage_id`/`path`/`source` value (confirmed `IIN7A0DF`, `INN7A0E4`, `IIN7A0E3` are absent from `asset`). `asset.source` is the EIT container (e.g. `MDDLX01.EIT`), not the original name. With current ETL these are unresolvable → graceful placeholder by design. 167 `.dib` files exist on disk under `other/` but no name→hash index links them.
- `inlineBmp(inlineId, inlineType)` GUARANTEES the never-throw placeholder for `inlineType != 27` and for any type-27 miss; resolved type-27 ids render through `EncartaImage` (so the `.dib` shim + derived-PNG preference apply uniformly).

**Judgment calls (flag for the other plan writers / integrator):**
1. **`inlineBmp` resolution depends on the additive `encarta_data` method `assetByBaggageId`.** The locked `EncartaDb` interface had no baggage-id lookup; per the coordinator's reconciliation, Unit 1 is adding `Future<AssetRow?> assetByBaggageId(String)` returning `AssetRow{baggageId,hash,kind,ext,path}`. `inlineBmp` calls it directly through the held `EncartaDb` (no `BaggageResolver` indirection). Flagged so Unit 1 keeps that method on its plan; if it is missing, type-27 inline images still degrade to the placeholder (never crash) but cannot resolve.
2. **`EncartaAssets.forTesting(this.config, {EncartaDb? db})`** added (an additive named constructor) so file-resolution and widgets are unit-testable without opening the 685 MB DB. With no `db` it supplies a throwing `_UnusedDb` stand-in (so accidental DB access fails loudly); the `inlineBmp` tests pass a `_FakeDb` that fakes only `assetByBaggageId`.
3. **`EncartaImage`/`EncartaAudio`/`EncartaVideo` take the owning `EncartaAssets`** (named `assets`) in addition to the contract's `required MediaItem item`, so they can call `resolvePath` and share the cached `DibShim`/init guard. This is additive to the locked `{required MediaItem item}` shape.
4. **`.dib` derived-PNG preference**: `EncartaImage` probes `<stem>.png` in `assets_derived/` before applying the shim, so a future transcode is picked up automatically without changing `resolvePath` (which stays exact-relative-path).
5. **media_kit playback is verified on a real machine, not in unit tests** (libmpv is a native desktop dep). Unit tests cover the deterministic poster-on-miss + lazy-init-skip path; real WMA/WMV playback is covered by the app integration smoke test (spec §10 testing summary).
