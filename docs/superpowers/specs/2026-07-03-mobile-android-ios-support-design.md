# Mobile (Android/iOS) Support — Design

**Date:** 2026-07-03
**Status:** Approved (design), pending implementation plan

## Goal

Make the Encarta reader launch and run **with real content** on Android and iOS
out of the box, backed by a bundled ~250-article sample corpus, with WMA/WMV
audio playback wired. Desktop (macOS) behavior is unchanged.

## Non-goals

- No full ~116k-article corpus on a phone (685 MB DB + 3.4 GB assets is
  infeasible to bundle or transfer).
- No download/import/file-picker UI for a user-supplied corpus.
- No cloud/remote backend.

These stay future work. The design activates `AppConfig`'s already-plumbed
`setting` resolution branch, which leaves a clean seam for a future
downloaded/imported corpus without further refactoring.

## Background — how the corpus is wired today

- `app/encarta_reader/lib/src/config/app_config.dart` — immutable `AppConfig`
  holds `dataDir`; derives `dbPath => '$dataDir/encarta.sqlite'`.
  `AppConfig.resolve(args, env, {setting})` precedence:
  **`--data-dir=` CLI arg > `ENCARTA_DATA_DIR` env > persisted `setting` >
  `defaultDataDir`** (`/Users/nexus/projects/experiments/strata/quarry/build`).
  `main.dart` currently never passes `setting` — so on desktop it is effectively
  hardcoded-default unless overridden. **`setting` is our mobile hook.**
- `app/encarta_reader/lib/main.dart` → `AppConfig.resolve` → `bootstrap(config)`.
- `app/encarta_reader/lib/src/bootstrap.dart` wires the two consumers:
  `EncartaDb.open(config.dbPath)` and `EncartaAssets(db, AssetConfig(config.dataDir))`.
- Assets are **filesystem** files at `<dataDir>/assets/<kind>/<hash><ext>`
  (preferred override dir: `<dataDir>/assets_derived/<...>`), keyed by the
  `asset.hash` column — **not** stored in the DB. `EncartaAssets.resolvePath`
  joins `derivedDir` first, then `assetsDir`.
- drift schema (`packages/encarta_data/lib/src/tables.drift`): `article`
  (`refid` PK, `xml` BLOB), `asset` (`baggage_id` PK, `hash`, `kind`, `ext`,
  `path`), `media`, `media_file` (`media_refid`,`role` → `baggage_id`),
  `article_media`, `xref`, and **contentless** `article_fts`
  (`fts5(body, content='', contentless_delete=1)`).
- **FTS invariant (load-bearing):** `article_fts.rowid == article.refid`, and
  `body` = the article's `xml` with all `<...>` tags stripped. Verified by
  `EncartaDb.verifyFtsRowidMapping`. A subset build must **rebuild** FTS in
  code — never copy the shadow tables.
- Blueprint: `packages/encarta_data/tool/build_fixture.dart` already does the
  DB-subset half (schema create, ATTACH real DB read-only, `INSERT…SELECT…WHERE
  refid IN (…)` for article/media tables, `xref` pruned to in-slice edges, FTS
  rebuilt row-by-row, MindMaze sliced). It omits only asset-file copying
  (fixtures don't need binaries).

## Components

### A. Sample-corpus builder (dev tool)

New `packages/encarta_data/tool/build_sample_corpus.dart`, reusing
`build_fixture.dart`'s subset logic. Run manually on a machine that has the full
corpus. Args: source corpus root, output dir, target article count (default
250).

1. **Select ~250 seed articles:** titled AND image-bearing (have at least one
   `article_media → media → media_file → asset` of `kind='image'`) so the
   sample is visually representative; bias a subset toward audio-bearing
   articles so playback demos. Spread across the title alphabet for variety.
2. **Copy DB rows** for `article`, `article_media`, `media`, `media_file`,
   `asset`, `xref` — mirroring `build_fixture.dart`. `xref` is pruned to edges
   whose **both** endpoints are in the slice. (In-sample links navigate;
   out-of-sample links degrade to plain text — existing dead-link behavior.)
3. **Rebuild `article_fts`** in Dart (`INSERT INTO article_fts(rowid, body)
   VALUES(refid, tagStrippedXml)`), preserving `rowid == refid`.
4. **Copy asset files (new step):** for every sliced `asset` row, copy
   `<srcRoot>/assets/<asset.path>` → `<out>/assets/<asset.path>` (creating the
   `<kind>/` subdir); also copy `<srcRoot>/assets_derived/<asset.path>` when it
   exists (resolver prefers it). Note: `path` uses `hash`; `other`-kind files
   may have empty `ext`.
5. **Package:** zip `<out>/encarta.sqlite` + `<out>/assets/` (+ `assets_derived/`
   if present) into `app/encarta_reader/assets/sample_corpus.zip`. Target
   **< 30 MB**; the tool prints the final size and article/asset counts so the
   operator can retune the count if over budget.

The `sample_corpus.zip` is **committed to the repo** so app builds (and CI /
other contributors without the full corpus) can bundle it.

### B. Bundle + first-launch provisioning

- Register the single `assets/sample_corpus.zip` in `app/encarta_reader/pubspec.yaml`
  `flutter: assets:`.
- New deps (app): `archive` (pure-Dart unzip), `path_provider` (app dirs).
- New `app/encarta_reader/lib/src/config/corpus_provisioner.dart`:
  - `Future<String> provisionBundledCorpus()`:
    1. `dir = <applicationSupportDirectory>/corpus`.
    2. If `dir/.sample_version` exists and equals the current `sampleVersion`
       const → return `dir` (already provisioned).
    3. Else: delete any partial `dir`, load `sample_corpus.zip` bytes via
       `rootBundle.load`, extract to `dir`, write `.sample_version`, return `dir`.
  - The **pure extraction** step is factored into
    `void extractCorpusZip(Uint8List zipBytes, Directory target)` so it is
    unit-testable without a device or `rootBundle`.

### C. Platform-aware bootstrap

`main.dart`:
- `WidgetsFlutterBinding.ensureInitialized()` (needed before `rootBundle` /
  `path_provider`).
- On `Platform.isAndroid || Platform.isIOS`: `final corpusDir = await
  provisionBundledCorpus();` then `AppConfig.resolve(args, env, setting:
  corpusDir)`. On desktop, `setting` stays `null` → existing CLI/env/default
  behavior, unchanged.

### D. media_kit mobile + platform config

- Add `media_kit_libs_android_video` and `media_kit_libs_ios_video` to
  `packages/encarta_assets/pubspec.yaml` (macOS libs stay).
- Ensure `MediaKit.ensureInitialized()` runs on mobile (locate the current call
  site — bootstrap or main — and confirm it covers Android/iOS).
- Android: `minSdk = 24` (`android/app/build.gradle`). No runtime permissions —
  the corpus is app-private storage.
- iOS: deployment target `13.0` (`ios/Podfile` + Xcode project). No Info.plist
  data-access keys — corpus is app-private.
- Verify `EncartaDb`'s Homebrew-dylib probe (`/opt/homebrew/opt/sqlite/...`)
  fails-soft on mobile (try/catch → bundled `sqlite3_flutter_libs`, which ships
  FTS5).

## Error handling

- A provisioning failure (corrupt zip, out of space) clears the partial corpus
  dir and surfaces the app's existing graceful "corpus unavailable" state
  rather than crashing; the next launch retries the unpack.
- Version-marker mismatch (shipping a new sample) triggers a clean re-unpack.

## Testing

- **Unit (device-free):** `extractCorpusZip` against an in-memory zip →
  temp dir (files land at expected relative paths); version-marker skip vs.
  refresh logic.
- **Integration (gated on full corpus present; skipped otherwise, matching
  existing fixture-dependent tests):** `build_sample_corpus` output DB opens,
  `article_fts.rowid == article.refid` holds, and every referenced asset file
  exists on disk under the output tree.
- Full existing suite stays green; desktop bootstrap path is unchanged.

## Rollout

Single feature branch → PR. Deliverables: the builder tool, the committed
`sample_corpus.zip`, provisioner + bootstrap wiring, media_kit mobile libs, and
Android/iOS platform-config bumps. Manual verification target: Android emulator
and/or iOS Simulator launches to a browsable, searchable sample with a working
image and (if a media-bearing article is in the slice) audio playback.
