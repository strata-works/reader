# Mobile (Android/iOS) Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Encarta reader launch and run with real content on Android/iOS, backed by a bundled ~250-article sample corpus, with WMA/WMV playback wired; desktop unchanged.

**Architecture:** A dev tool builds a small standalone corpus (DB subset + copied asset files) and zips it into the app as a single asset. On mobile first-launch, the app unpacks that zip into app-private storage and feeds the path into `AppConfig`'s already-plumbed `setting` branch. media_kit mobile libs + minSdk/iOS-target bumps make the native side build.

**Tech Stack:** Flutter 3.42 beta / Dart 3.12 beta, drift + sqlite3 (`sqlite3_flutter_libs` bundles FTS5), media_kit, `archive` (zip), `path_provider`.

## Global Constraints

- DB filename is `encarta.sqlite` (NOT `.db`); it lives at `<dataDir>/encarta.sqlite`.
- FTS invariant is load-bearing: `article_fts.rowid == article.refid`, `body` = article `xml` with `<...>` tags stripped. FTS is **contentless** — always rebuild it in code, never copy the shadow tables.
- Asset files live on the filesystem at `<dataDir>/assets/<kind>/<hash><ext>` (preferred override: `<dataDir>/assets_derived/<same-path>`), keyed by `asset.hash`, not by `baggage_id`. Bytes are NOT in the DB.
- `AppConfig.resolve` takes **named** params `{required List<String> args, required Map<String,String> env, String? setting}`; precedence CLI `--data-dir=` > `ENCARTA_DATA_DIR` env > `setting` > `AppConfig.defaultDataDir`.
- Desktop (macOS) behavior must not change: provisioning runs ONLY on `Platform.isAndroid || Platform.isIOS`.
- `encarta_assets` must NOT depend on more than one `media_kit_libs_macos_*` package ("must be uniq") — the existing `media_kit_libs_macos_video` stays; add the android/ios `_video` libs (they bundle audio too).
- Sample `sample_corpus.zip` target size < 30 MB; it is committed to the repo.
- Do not use haiku for any implementer/reviewer subagent (sonnet or better).

---

### Task 1: Sample-corpus builder tool + generated `sample_corpus.zip`

**Files:**
- Create: `packages/encarta_data/tool/build_sample_corpus.dart`
- Create (generated, committed): `app/encarta_reader/assets/sample_corpus.zip`
- Modify: `packages/encarta_data/pubspec.yaml` (add `archive` dev_dependency)

**Interfaces:**
- Consumes: the full corpus at `/Users/nexus/projects/experiments/strata/quarry/build/{encarta.sqlite,assets,assets_derived}`; an FTS5-capable libsqlite3 (`/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib`).
- Produces: `app/encarta_reader/assets/sample_corpus.zip` whose ROOT contains `encarta.sqlite`, `assets/<kind>/…` and/or `assets_derived/<kind>/…` (no wrapping top dir).

 > **Note (as-built):** the final builder ranks by rare decodable images, unions ~8 audio-bearing articles, skips undecodable .jtn/.gtn, and landed 208 articles / 18.3 MB — see the committed tool for the exact queries.

- [ ] **Step 1: Add the `archive` dev_dependency to encarta_data**

In `packages/encarta_data/pubspec.yaml`, under `dev_dependencies:` add:

```yaml
  archive: ^3.6.0
```

- [ ] **Step 2: Write the builder tool**

Create `packages/encarta_data/tool/build_sample_corpus.dart`:

```dart
// Builds a small standalone sample corpus (DB subset + copied asset files) and
// zips it to app/encarta_reader/assets/sample_corpus.zip for bundling on mobile.
// Run from the encarta_data package root with the full corpus present:
//   dart run tool/build_sample_corpus.dart
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const srcRoot = '/Users/nexus/projects/experiments/strata/quarry/build';
const srcDb = '$srcRoot/encarta.sqlite';
const outRoot = 'build/sample_corpus'; // scratch build dir (git-ignored)
const outDb = '$outRoot/encarta.sqlite';
const outZip = '../../app/encarta_reader/assets/sample_corpus.zip';
const targetArticles = 250;

void main() {
  // 1. Load an FTS5-capable libsqlite3 (same probe as build_fixture.dart).
  var loaded = false;
  for (final p in const [
    '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
    '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
  ]) {
    if (File(p).existsSync()) {
      open.overrideForAll(() => DynamicLibrary.open(p));
      loaded = true;
      break;
    }
  }
  if (!loaded) {
    stderr.writeln('No fts5-capable libsqlite3 found (brew install sqlite).');
    exit(1);
  }
  if (!File(srcDb).existsSync()) {
    stderr.writeln('Real corpus not found at $srcDb');
    exit(1);
  }

  // 2. Fresh output tree.
  final outDir = Directory(outRoot);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  final dst = sqlite3.open(outDb);
  dst.execute("ATTACH DATABASE 'file:$srcDb?mode=ro' AS src");

  // 3. Schema (identical to the real DB's read subset).
  dst.execute('''
    CREATE TABLE article (refid INTEGER PRIMARY KEY, source TEXT, title TEXT, xml BLOB);
    CREATE TABLE asset (baggage_id TEXT PRIMARY KEY, hash TEXT, kind TEXT, ext TEXT, path TEXT, source TEXT);
    CREATE TABLE media (refid INTEGER PRIMARY KEY, "group" TEXT, title TEXT, credit TEXT, caption TEXT, source TEXT);
    CREATE TABLE media_file (media_refid INTEGER, role TEXT, baggage_id TEXT, ext TEXT, PRIMARY KEY(media_refid, role));
    CREATE TABLE article_media (article_refid INTEGER, media_refid INTEGER, PRIMARY KEY(article_refid, media_refid));
    CREATE TABLE xref (refid INTEGER, target_refid INTEGER, PRIMARY KEY(refid, target_refid));
    CREATE VIRTUAL TABLE article_fts USING fts5(body, content='', contentless_delete=1, tokenize='unicode61');
  ''');

  // 4. Select ~targetArticles titled, image-bearing articles, richest first, so
  //    the sample looks like a real (small) encyclopedia.
  final ids = <int>{};
  for (final r in dst.select(
      "SELECT a.refid AS refid FROM src.article a "
      "JOIN src.article_media am ON am.article_refid = a.refid "
      "JOIN src.media_file mf ON mf.media_refid = am.media_refid "
      "JOIN src.asset s ON s.baggage_id = mf.baggage_id AND s.kind = 'image' "
      "WHERE a.title IS NOT NULL "
      "GROUP BY a.refid ORDER BY count(*) DESC LIMIT ?",
      [targetArticles])) {
    ids.add(r['refid'] as int);
  }
  if (ids.isEmpty) {
    stderr.writeln('No image-bearing titled articles found.');
    exit(1);
  }
  final inC = ids.join(',');

  // 5. Copy DB rows (mirror build_fixture.dart); xref pruned to in-slice edges.
  dst.execute('INSERT INTO article SELECT * FROM src.article WHERE refid IN ($inC)');
  dst.execute('INSERT INTO article_media SELECT * FROM src.article_media WHERE article_refid IN ($inC)');
  dst.execute('INSERT INTO media SELECT * FROM src.media WHERE refid IN (SELECT media_refid FROM article_media)');
  dst.execute('INSERT INTO media_file SELECT * FROM src.media_file WHERE media_refid IN (SELECT refid FROM media)');
  dst.execute('INSERT INTO asset SELECT * FROM src.asset WHERE baggage_id IN (SELECT baggage_id FROM media_file)');
  dst.execute('INSERT INTO xref SELECT * FROM src.xref WHERE refid IN ($inC) AND target_refid IN ($inC)');

  // 6. Rebuild contentless FTS (rowid == refid invariant).
  final tagRe = RegExp(r'<[^>]*>');
  final fts = dst.prepare('INSERT INTO article_fts(rowid, body) VALUES(?, ?)');
  for (final r in dst.select('SELECT refid, xml FROM article')) {
    final refid = r['refid'] as int;
    final raw = r['xml'];
    final text = (raw is List<int>
            ? utf8.decode(raw, allowMalformed: true)
            : '${raw ?? ''}')
        .replaceAll(tagRe, ' ');
    fts.execute([refid, text]);
  }
  fts.dispose();
  dst.execute('DETACH DATABASE src');

  // 7. Copy referenced asset files. Prefer the derived (transcoded) file when
  //    present (smaller/decodable), matching the resolver's precedence; else the
  //    original. Same relative path either way. Missing files are skipped (data
  //    gaps degrade to placeholders at runtime).
  var copied = 0, skipped = 0, bytes = 0;
  for (final r in dst.select('SELECT path FROM asset')) {
    final rel = r['path'] as String?;
    if (rel == null || rel.isEmpty) continue;
    final derived = File('$srcRoot/assets_derived/$rel');
    final original = File('$srcRoot/assets/$rel');
    File? src;
    String subdir;
    if (derived.existsSync()) {
      src = derived;
      subdir = 'assets_derived';
    } else if (original.existsSync()) {
      src = original;
      subdir = 'assets';
    } else {
      skipped++;
      continue;
    }
    final out = File('$outRoot/$subdir/$rel');
    out.parent.createSync(recursive: true);
    src.copySync(out.path);
    copied++;
    bytes += src.lengthSync();
  }

  // 8. Self-check the output (integration guard from the spec).
  final artN = dst.select('SELECT count(*) AS n FROM article').first['n'] as int;
  final ftsN = dst
      .select('SELECT count(*) AS n FROM article a '
          'JOIN article_fts f ON f.rowid = a.refid')
      .first['n'] as int;
  dst.dispose();
  if (ftsN != artN) {
    stderr.writeln('FTS invariant broken: $ftsN joined != $artN articles');
    exit(1);
  }

  // 9. Zip the output tree (its ROOT becomes the corpus dir on device).
  final zipFile = File(outZip);
  zipFile.parent.createSync(recursive: true);
  if (zipFile.existsSync()) zipFile.deleteSync();
  final enc = ZipFileEncoder();
  enc.create(zipFile.path);
  enc.addDirectory(outDir, includeDirName: false);
  enc.close();

  final zipMb = zipFile.lengthSync() / (1024 * 1024);
  stdout.writeln('Sample: $artN articles, $copied assets copied '
      '(${(bytes / 1e6).toStringAsFixed(1)} MB raw), $skipped missing.');
  stdout.writeln('Wrote ${zipFile.path} (${zipMb.toStringAsFixed(1)} MB).');
  if (zipMb > 30) {
    stderr.writeln('WARNING: zip exceeds 30 MB budget — lower targetArticles.');
  }
}
```

- [ ] **Step 3: Resolve deps**

Run: `cd packages/encarta_data && dart pub get`
Expected: resolves with `archive` added, exit 0.

- [ ] **Step 4: Run the builder**

Run: `cd packages/encarta_data && dart run tool/build_sample_corpus.dart`
Expected: prints `Sample: 250 articles, <N> assets copied …` then `Wrote ../../app/encarta_reader/assets/sample_corpus.zip (<size> MB).` with NO `FTS invariant broken` error and NO `exceeds 30 MB` warning (if the warning fires, lower `targetArticles`, e.g. to 180, and re-run).

- [ ] **Step 5: Independently verify the generated corpus**

Run:
```bash
cd /Users/nexus/projects/experiments/strata/reader
ls -lh app/encarta_reader/assets/sample_corpus.zip
/opt/homebrew/opt/sqlite/bin/sqlite3 packages/encarta_data/build/sample_corpus/encarta.sqlite \
  "SELECT (SELECT count(*) FROM article) AS articles,
          (SELECT count(*) FROM article a JOIN article_fts f ON f.rowid=a.refid) AS fts_joined,
          (SELECT count(*) FROM asset) AS assets;"
```
Expected: zip is < 30 MB; `articles == fts_joined` (FTS invariant holds); `assets > 0`.

- [ ] **Step 6: Ignore the scratch build dir**

Add `build/` to `packages/encarta_data/.gitignore` (create the file if absent) so the scratch `build/sample_corpus/` tree is never committed — only the zip is.

```
build/
```

- [ ] **Step 7: Commit**

```bash
cd /Users/nexus/projects/experiments/strata/reader
git add packages/encarta_data/tool/build_sample_corpus.dart \
        packages/encarta_data/pubspec.yaml \
        packages/encarta_data/.gitignore \
        app/encarta_reader/assets/sample_corpus.zip
git commit -m "feat(data): sample-corpus builder + bundled sample_corpus.zip"
```

---

### Task 2: Corpus provisioner (device-free unzip + version logic)

**Files:**
- Create: `app/encarta_reader/lib/src/config/corpus_provisioner.dart`
- Test: `app/encarta_reader/test/corpus_provisioner_test.dart`
- Modify: `app/encarta_reader/pubspec.yaml` (add `archive`, `path_provider`)

**Interfaces:**
- Produces:
  - `void extractCorpusZip(Uint8List zipBytes, Directory target)` — extracts a zip's files under `target`, creating parent dirs.
  - `bool corpusIsProvisioned(Directory corpus, String version)` — true iff `<corpus>/.sample_version` exists and trims to `version`.
  - `const String sampleVersion` — current sample marker (`'2026-07-03-1'`).
  - `Future<String> provisionBundledCorpus()` — unpacks `assets/sample_corpus.zip` into `<applicationSupport>/corpus` on first run (or version change), returns that dir path.

- [ ] **Step 1: Add app deps**

In `app/encarta_reader/pubspec.yaml`, under `dependencies:` add:

```yaml
  archive: ^3.6.0
  path_provider: ^2.1.4
```

Run: `cd app/encarta_reader && flutter pub get`
Expected: resolves, exit 0.

- [ ] **Step 2: Write the failing test**

Create `app/encarta_reader/test/corpus_provisioner_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encarta_reader/src/config/corpus_provisioner.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zipOf(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, bytes) =>
      archive.addFile(ArchiveFile(name, bytes.length, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('extractCorpusZip writes files at their zip-relative paths', () {
    final tmp = Directory.systemTemp.createTempSync('corpus_extract_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final zip = _zipOf({
      'encarta.sqlite': [1, 2, 3],
      'assets/image/abc.png': [9, 8, 7],
    });

    extractCorpusZip(zip, tmp);

    expect(File('${tmp.path}/encarta.sqlite').readAsBytesSync(), [1, 2, 3]);
    expect(File('${tmp.path}/assets/image/abc.png').readAsBytesSync(), [9, 8, 7]);
  });

  test('corpusIsProvisioned tracks the version marker', () {
    final tmp = Directory.systemTemp.createTempSync('corpus_marker_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    expect(corpusIsProvisioned(tmp, sampleVersion), isFalse);

    File('${tmp.path}/.sample_version').writeAsStringSync(sampleVersion);
    expect(corpusIsProvisioned(tmp, sampleVersion), isTrue);
    expect(corpusIsProvisioned(tmp, 'other-version'), isFalse);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/corpus_provisioner_test.dart`
Expected: FAIL — `corpus_provisioner.dart` / its symbols don't exist yet.

- [ ] **Step 4: Write the implementation**

Create `app/encarta_reader/lib/src/config/corpus_provisioner.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Bump when a new sample_corpus.zip ships so devices re-unpack it.
const String sampleVersion = '2026-07-03-1';

/// Bundled asset key for the packaged sample corpus.
const String _sampleAsset = 'assets/sample_corpus.zip';

/// Extract every file in [zipBytes] under [target], creating parent dirs.
void extractCorpusZip(Uint8List zipBytes, Directory target) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  for (final file in archive) {
    final outPath = '${target.path}/${file.name}';
    if (file.isFile) {
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

/// True iff [corpus] holds a `.sample_version` marker equal to [version].
bool corpusIsProvisioned(Directory corpus, String version) {
  final marker = File('${corpus.path}/.sample_version');
  return corpus.existsSync() &&
      marker.existsSync() &&
      marker.readAsStringSync().trim() == version;
}

/// Ensure the bundled sample corpus is unpacked into app-private storage and
/// return its directory. Idempotent: skips when the version marker matches.
/// On failure, leaves the corpus dir cleared so the next launch retries.
Future<String> provisionBundledCorpus() async {
  final support = await getApplicationSupportDirectory();
  final corpus = Directory('${support.path}/corpus');
  if (corpusIsProvisioned(corpus, sampleVersion)) return corpus.path;

  if (corpus.existsSync()) corpus.deleteSync(recursive: true);
  corpus.createSync(recursive: true);
  try {
    final data = await rootBundle.load(_sampleAsset);
    extractCorpusZip(data.buffer.asUint8List(), corpus);
    File('${corpus.path}/.sample_version').writeAsStringSync(sampleVersion);
  } catch (_) {
    if (corpus.existsSync()) corpus.deleteSync(recursive: true);
    rethrow;
  }
  return corpus.path;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd app/encarta_reader && flutter test test/corpus_provisioner_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/nexus/projects/experiments/strata/reader
git add app/encarta_reader/lib/src/config/corpus_provisioner.dart \
        app/encarta_reader/test/corpus_provisioner_test.dart \
        app/encarta_reader/pubspec.yaml
git commit -m "feat(app): corpus provisioner (unzip bundled sample to app storage)"
```

---

### Task 3: Platform-aware config resolution + bootstrap wiring

**Files:**
- Modify: `app/encarta_reader/lib/src/config/corpus_provisioner.dart` (add `resolveAppConfig`)
- Modify: `app/encarta_reader/lib/main.dart`
- Modify: `app/encarta_reader/pubspec.yaml` (register the zip asset)
- Test: `app/encarta_reader/test/resolve_app_config_test.dart`

**Interfaces:**
- Consumes: `AppConfig.resolve({required args, required env, String? setting})` and `AppConfig.defaultDataDir` (`app_config.dart`); `provisionBundledCorpus()` (Task 2).
- Produces: `Future<AppConfig> resolveAppConfig({required List<String> args, required Map<String,String> env, required bool isMobile, Future<String> Function()? provisionCorpus})` — on mobile with no CLI/env override, provisions and uses the corpus dir; otherwise returns the desktop resolution.

- [ ] **Step 1: Write the failing test**

Create `app/encarta_reader/test/resolve_app_config_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app/encarta_reader && flutter test test/resolve_app_config_test.dart`
Expected: FAIL — `resolveAppConfig` not defined.

- [ ] **Step 3: Implement `resolveAppConfig`**

Append to `app/encarta_reader/lib/src/config/corpus_provisioner.dart` (add the import at the top with the others):

```dart
import 'app_config.dart';
```

```dart
/// Resolve the app's [AppConfig], provisioning the bundled sample corpus on
/// mobile when no CLI/env override is present. CLI `--data-dir=` / env
/// `ENCARTA_DATA_DIR` always win (dev override, even on a device).
Future<AppConfig> resolveAppConfig({
  required List<String> args,
  required Map<String, String> env,
  required bool isMobile,
  Future<String> Function()? provisionCorpus,
}) async {
  final base = AppConfig.resolve(args: args, env: env);
  final hasOverride = base.dataDir != AppConfig.defaultDataDir;
  if (isMobile && !hasOverride && provisionCorpus != null) {
    final dir = await provisionCorpus();
    return AppConfig.resolve(args: args, env: env, setting: dir);
  }
  return base;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app/encarta_reader && flutter test test/resolve_app_config_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Wire `main.dart`**

Replace `app/encarta_reader/lib/main.dart` with:

```dart
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/corpus_provisioner.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await resolveAppConfig(
    args: args,
    env: Platform.environment,
    isMobile: Platform.isAndroid || Platform.isIOS,
    provisionCorpus: provisionBundledCorpus,
  );
  final env = await bootstrap(config);
  runApp(EncartaReaderApp(env: env));
}
```

- [ ] **Step 6: Register the bundled asset**

In `app/encarta_reader/pubspec.yaml`, under the `flutter:` section (alongside `uses-material-design` and `fonts`), add:

```yaml
  assets:
    - assets/sample_corpus.zip
```

- [ ] **Step 7: Verify the app still analyzes and the full suite is green**

Run: `cd app/encarta_reader && flutter analyze && flutter test`
Expected: analyze passes; all tests pass (existing suite + the two new test files).

- [ ] **Step 8: Commit**

```bash
cd /Users/nexus/projects/experiments/strata/reader
git add app/encarta_reader/lib/src/config/corpus_provisioner.dart \
        app/encarta_reader/lib/main.dart \
        app/encarta_reader/pubspec.yaml \
        app/encarta_reader/test/resolve_app_config_test.dart
git commit -m "feat(app): platform-aware config — provision sample corpus on mobile"
```

---

### Task 4: media_kit mobile libs + Android/iOS platform config

**Files:**
- Modify: `packages/encarta_assets/pubspec.yaml`
- Modify: `app/encarta_reader/android/app/build.gradle.kts`
- Modify: `app/encarta_reader/ios/Podfile`

**Interfaces:**
- Consumes: existing `MediaKit.ensureInitialized()` call in `bootstrap.dart` (no code change — it registers whatever `media_kit_libs_*` packages are present). Existing try/catch-guarded `_loadFts5Sqlite()` in `encarta_db.dart` (fails-soft on mobile → bundled `sqlite3_flutter_libs` FTS5; no change).

- [ ] **Step 1: Add mobile media_kit libs**

In `packages/encarta_assets/pubspec.yaml`, under `dependencies:` (right after `media_kit_libs_macos_video`), add:

```yaml
  media_kit_libs_android_video: ^1.3.8
  media_kit_libs_ios_video: ^1.1.5
```

- [ ] **Step 2: Pin Android minSdk to 24 (media_kit floor)**

In `app/encarta_reader/android/app/build.gradle.kts`, inside `defaultConfig { … }`, replace:

```kotlin
        minSdk = flutter.minSdkVersion
```

with:

```kotlin
        minSdk = 24 // media_kit mobile libs require API 24+
```

- [ ] **Step 3: Uncomment the iOS platform floor**

In `app/encarta_reader/ios/Podfile`, change the first line from:

```ruby
# Uncomment this line to define a global platform for your project
# platform :ios, '13.0'
```

to:

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'
```

(The Xcode project already sets `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, which satisfies `media_kit_libs_ios_video`.)

- [ ] **Step 4: Resolve deps**

Run: `cd app/encarta_reader && flutter pub get`
Expected: resolves with the two new libs, exit 0. (If pub reports a `media_kit_libs_macos_* must be uniq` error, STOP — that means a duplicate macOS lib slipped in; only the android/ios `_video` libs should be new.)

- [ ] **Step 5: Confirm the existing suite is unaffected**

Run: `cd app/encarta_reader && flutter test`
Expected: all tests pass (deps changed, no logic changed).

- [ ] **Step 6: Verify the Android build links**

Run: `cd app/encarta_reader && flutter build apk --debug`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`. (First run downloads Gradle/NDK artifacts and is slow. If the Android SDK/NDK is not installed in this environment, record the failure verbatim and report it — do NOT edit unrelated Gradle config to force it; the missing-toolchain case is an operator setup step, not a code defect.)

- [ ] **Step 7: Verify the iOS pods install**

Run: `cd app/encarta_reader/ios && pod install`
Expected: `Pod installation complete!` with the media_kit pods present. (If CocoaPods specs are stale, `pod repo update` first. If this environment lacks the iOS toolchain, record the output and report it rather than working around it.)

- [ ] **Step 8: Commit**

```bash
cd /Users/nexus/projects/experiments/strata/reader
git add packages/encarta_assets/pubspec.yaml \
        app/encarta_reader/android/app/build.gradle.kts \
        app/encarta_reader/ios/Podfile \
        app/encarta_reader/pubspec.lock app/encarta_reader/ios/Podfile.lock
git commit -m "feat(mobile): media_kit android/ios libs + minSdk 24 / iOS 13 floors"
```

---

## Manual verification (operator, after all tasks)

Not a code task — the human runs these on a simulator/emulator:

- **Android:** `cd app/encarta_reader && flutter run -d <emulator-id>` → app launches to Home, browse a sample article (image renders), run a search (FTS returns hits), tap an in-sample link (navigates). If a media-bearing article is in the slice, play its audio.
- **iOS:** `flutter run -d <simulator-id>` → same checks.

Report any failures with the exact screen + console output for follow-up.

## Self-Review notes

- Spec coverage: builder+asset-copy (Task 1) ✓; bundle+provision (Task 2) ✓; platform-aware bootstrap (Task 3) ✓; media_kit mobile + platform config + fail-soft sqlite (Task 4) ✓; error handling (provisioner clears partial dir + rethrow → existing graceful state) ✓; testing (device-free units in Tasks 2–3, self-check integration guard in Task 1) ✓.
- Type consistency: `resolveAppConfig`, `provisionBundledCorpus`, `extractCorpusZip`, `corpusIsProvisioned`, `sampleVersion` names/signatures match across Tasks 2–3 and `main.dart`.
- Desktop unchanged: `isMobile` gate keeps macOS on the existing CLI/env/default path.
