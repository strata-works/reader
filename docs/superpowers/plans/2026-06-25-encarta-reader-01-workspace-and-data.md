# Encarta Reader — Unit 1: Pub Workspace Scaffold + `encarta_data` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `reader/` pub workspace and a pure-Dart, read-only `encarta_data` package (drift over the sqlite3 FFI) that exposes the locked typed API over the recovered Encarta 2009 corpus.

**Architecture:** A pub workspace (`resolution: workspace`, single shared lockfile) whose first member is `packages/encarta_data`. `encarta_data` opens the existing `encarta.sqlite` **read-only** via the `sqlite3` package, wraps it with **drift** for build-time-validated typed SQL (`.drift` files, `fts5` analyzer module enabled), and surfaces a small facade (`EncartaDb`) plus five immutable data classes. It never depends on Flutter and never writes the corpus.

**Tech Stack:** Dart 3.12 beta (`>=3.12.0-0 <4.0.0`); `drift ^2.20.0` + `drift_dev ^2.20.0` + `build_runner ^2.4.0`; `sqlite3 ^2.4.0`; `test ^1.25.0`; `lints ^5.0.0`. Target host: macOS arm64.

## Global Constraints

- Flutter 3.42 beta / **Dart 3.12 beta** — this package is **pure Dart** (`dart test`, `dart run build_runner`), NO Flutter dependency ever.
- DB is opened **READ-ONLY** (`OpenMode.readOnly`); the corpus is never modified (no migrations, no `user_version` write).
- Data directory is **configurable**: default `/Users/nexus/projects/experiments/strata/quarry/build`, DB at `<dataDir>/encarta.sqlite`. Tests use a checked-in fixture, never the real DB (except the explicit runtime-verification task, which is guarded by `File.existsSync`).
- **fts5 is required and is NOT in macOS system sqlite3.** The CLI/system lib lacks fts5 (`no such module: fts5`); load an fts5-capable libsqlite3 at runtime (Homebrew's `/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib`, verified to ship fts5).
- The FTS5 table is **contentless** (`content=''`): queries yield refids + `bm25` rank only. `snippet()`/`highlight()` return nothing — **snippets are generated in Dart** from `article.xml`.
- Never drop data / never crash on bad data: missing titles map to `''`, broken xrefs are filtered out by JOINs, unresolved `featured()` falls back gracefully.
- **TDD**: every task writes a failing test first, then the minimal code to pass. **Frequent commits**: one commit per task.
- NO placeholders in code: every step below is real, runnable Dart/SQL.

---

## File Structure

| File | Responsibility |
|---|---|
| `reader/pubspec.yaml` | Workspace root: declares members + shared dev deps (created) |
| `reader/analysis_options.yaml` | Root lint config, excludes generated files (created) |
| `reader/.gitignore` | Add Dart/drift/coverage ignores (modified) |
| `reader/packages/encarta_data/pubspec.yaml` | Pure-Dart package manifest, `resolution: workspace` (created) |
| `reader/packages/encarta_data/analysis_options.yaml` | Package lint config (created) |
| `reader/packages/encarta_data/build.yaml` | drift_dev options: sqlite dialect + `fts5` module (created) |
| `reader/packages/encarta_data/lib/src/tables.drift` | Declares the existing read-only schema + the contentless fts5 vtable (created/grown) |
| `reader/packages/encarta_data/lib/src/queries.drift` | Named, build-validated SQL queries (grown per task) |
| `reader/packages/encarta_data/lib/src/database.dart` | drift `EncartaDatabase` (no-op migration; read-only-safe) (created) |
| `reader/packages/encarta_data/lib/src/database.g.dart` | drift codegen output (generated) |
| `reader/packages/encarta_data/lib/src/models.dart` | The 5 immutable data classes (grown per task) |
| `reader/packages/encarta_data/lib/src/snippet.dart` | `encartaSnippet()` — Dart contentless-FTS snippet generation (created) |
| `reader/packages/encarta_data/lib/src/encarta_db.dart` | `EncartaDb` facade: fts5 loader, read-only open, query→model mapping (grown per task) |
| `reader/packages/encarta_data/lib/encarta_data.dart` | Public library barrel (grown per task) |
| `reader/packages/encarta_data/tool/build_fixture.dart` | One-shot: copy a slice of the real DB into the test fixture (created) |
| `reader/packages/encarta_data/test/fixtures/encarta_fixture.sqlite` | Checked-in fixture DB (~43 articles) (generated + committed) |
| `reader/packages/encarta_data/test/*_test.dart` | One test file per task (created per task) |

---

### Task 1: Pub workspace root scaffold

**Files:** Create — `reader/pubspec.yaml`, `reader/analysis_options.yaml`. Modify — `reader/.gitignore`. (Config task: the "test" is workspace resolution via `dart pub get`.)
**Interfaces:** Produces: the workspace root that every later member resolves against (single `reader/pubspec.lock`).

> **Workspace ownership (final cross-plan decision):** `dart pub` does NOT support globs in `workspace:`, so members are listed EXPLICITLY. This task creates the root with `workspace:` containing only `packages/encarta_data`. **Units 2, 3, and 4 each append their own member line** — `packages/encarta_render`, `packages/encarta_assets`, `app/encarta_reader` respectively — inside their own scaffold tasks, so every commit's `dart pub get` stays green.

- [ ] **Step 1: Write the failing check.** The verification is that `dart pub get` resolves the workspace from the repo root. Record the expectation: running it now must FAIL because no root `pubspec.yaml` exists yet.

- [ ] **Step 2: Run check to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && dart pub get
  ```
  Expected FAIL: `Could not find a file named "pubspec.yaml"`.

- [ ] **Step 3: Write minimal implementation.**
  Create `reader/pubspec.yaml`:
  ```yaml
  name: encarta_reader_workspace
  description: >-
    Pub workspace root for the Encarta Reader — a faithful-in-spirit reader for
    the recovered Microsoft Encarta 2009 corpus.
  publish_to: none
  version: 0.1.0

  environment:
    sdk: '>=3.12.0-0 <4.0.0'

  # Pub workspace = single shared lockfile across all member packages.
  # NOTE: `dart pub` requires EXPLICIT member paths here (globs like packages/*
  # are NOT supported), and listing a path that does not yet exist makes
  # `pub get` fail. Each unit therefore APPENDS its own package as it is created.
  # This unit (Unit 1) adds packages/encarta_data. Later units append:
  #   - packages/encarta_render
  #   - packages/encarta_assets
  #   - app/encarta_reader
  workspace:
    - packages/encarta_data

  dev_dependencies:
    lints: ^5.0.0
  ```
  Create `reader/analysis_options.yaml`:
  ```yaml
  include: package:lints/recommended.yaml

  analyzer:
    exclude:
      - "**/*.g.dart"
      - "**/*.drift.dart"
    language:
      strict-casts: true
      strict-raw-types: true
  ```
  Append to `reader/.gitignore` (keep existing lines):
  ```gitignore
  # Dart / pub
  .dart_tool/
  pubspec.lock
  doc/api/
  # drift / build_runner
  *.g.dart.lock
  .build_runner.fingerprint
  # coverage
  coverage/
  # macOS
  .DS_Store
  ```
  > Note: `packages/encarta_data` does not exist yet, so `dart pub get` will still fail until Task 2 creates it. That is expected — Task 1's commit captures the root config; Task 2 is the first task whose `pub get` is green. Proceed to commit the root files now.

- [ ] **Step 4: Verify the root files are well-formed.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && dart pub get 2>&1 | head -3
  ```
  Expected: it now reaches workspace resolution and fails specifically on the missing member (`Could not find a file named "pubspec.yaml" in ".../packages/encarta_data"`), proving the root YAML parses and the workspace block is read. (Green `pub get` arrives in Task 2.)

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add pubspec.yaml analysis_options.yaml .gitignore && git commit -m "chore: add pub workspace root, root lints, gitignore"
  ```

---

### Task 2: `encarta_data` package skeleton + drift wiring

**Files:** Create — `packages/encarta_data/pubspec.yaml`, `.../analysis_options.yaml`, `.../build.yaml`, `.../lib/src/tables.drift`, `.../lib/src/database.dart`, `.../lib/encarta_data.dart`, `.../test/skeleton_test.dart`. Generated — `.../lib/src/database.g.dart`.
**Interfaces:** Produces: `EncartaDatabase` (drift, read-only-safe) and the `fts5`-aware codegen pipeline that every later query task extends.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/skeleton_test.dart`:
  ```dart
  import 'package:drift/drift.dart';
  import 'package:drift/native.dart';
  import 'package:encarta_data/src/database.dart';
  import 'package:test/test.dart';

  void main() {
    test('EncartaDatabase wires drift codegen and runs a trivial query', () async {
      final db = EncartaDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final row = await db.customSelect('SELECT 1 AS v').getSingle();
      expect(row.read<int>('v'), 1);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/skeleton_test.dart
  ```
  Expected FAIL: `Error: Couldn't resolve the package 'encarta_data'` / missing `src/database.dart` (package + codegen not created yet).

- [ ] **Step 3: Write minimal implementation.**
  Create `packages/encarta_data/pubspec.yaml`:
  ```yaml
  name: encarta_data
  description: >-
    Read-only, typed access to the recovered Encarta 2009 corpus
    (drift over the sqlite3 FFI). Pure Dart — no Flutter.
  publish_to: none
  version: 0.1.0
  resolution: workspace

  environment:
    sdk: '>=3.12.0-0 <4.0.0'

  dependencies:
    drift: ^2.20.0
    sqlite3: ^2.4.0

  dev_dependencies:
    build_runner: ^2.4.0
    drift_dev: ^2.20.0
    lints: ^5.0.0
    test: ^1.25.0
  ```
  Create `packages/encarta_data/analysis_options.yaml`:
  ```yaml
  include: package:lints/recommended.yaml

  analyzer:
    exclude:
      - "lib/**/*.g.dart"
      - "lib/**/*.drift.dart"
    language:
      strict-casts: true
      strict-raw-types: true
  ```
  Create `packages/encarta_data/build.yaml` (enables the `fts5` analyzer module so `MATCH`/`bm25` validate at build time):
  ```yaml
  targets:
    $default:
      builders:
        drift_dev:
          options:
            sqlite:
              version: "3.44"
              modules:
                - fts5
  ```
  Create `packages/encarta_data/lib/src/tables.drift` — the existing read-only schema (column types must match the real DB so queries validate). Tables are declared for drift's analyzer only; we never call `createAll`:
  ```sql
  CREATE TABLE article (
    refid  INTEGER NOT NULL PRIMARY KEY,
    source TEXT,
    title  TEXT,
    xml    BLOB
  );

  CREATE TABLE asset (
    baggage_id TEXT NOT NULL PRIMARY KEY,
    hash       TEXT,
    kind       TEXT,
    ext        TEXT,
    path       TEXT,
    source     TEXT
  );

  CREATE TABLE media (
    refid   INTEGER NOT NULL PRIMARY KEY,
    "group" TEXT,
    title   TEXT,
    credit  TEXT,
    caption TEXT,
    source  TEXT
  );

  CREATE TABLE media_file (
    media_refid INTEGER NOT NULL,
    role        TEXT NOT NULL,
    baggage_id  TEXT,
    ext         TEXT,
    PRIMARY KEY (media_refid, role)
  );

  CREATE TABLE article_media (
    article_refid INTEGER NOT NULL,
    media_refid   INTEGER NOT NULL,
    PRIMARY KEY (article_refid, media_refid)
  );

  CREATE TABLE xref (
    refid        INTEGER NOT NULL,
    target_refid INTEGER NOT NULL,
    PRIMARY KEY (refid, target_refid)
  );

  CREATE VIRTUAL TABLE article_fts USING fts5(
    body,
    content='',
    contentless_delete=1,
    tokenize='unicode61'
  );
  ```
  Create `packages/encarta_data/lib/src/database.dart`:
  ```dart
  import 'package:drift/drift.dart';

  part 'database.g.dart';

  /// drift database over the EXISTING, read-only Encarta corpus.
  ///
  /// The corpus is never created or migrated by us, so the migration strategy
  /// is a no-op. A read-only-safe open path (interceptor that swallows the
  /// `PRAGMA user_version =` write) lives in [EncartaDb.open]; see encarta_db.dart.
  @DriftDatabase(include: {'tables.drift', 'queries.drift'})
  class EncartaDatabase extends _$EncartaDatabase {
    EncartaDatabase(super.e);

    @override
    int get schemaVersion => 1;

    @override
    MigrationStrategy get migration => MigrationStrategy(
          // Never CREATE anything: the schema already exists on disk.
          onCreate: (m) async {},
          onUpgrade: (m, from, to) async {},
        );
  }
  ```
  Create `packages/encarta_data/lib/src/queries.drift` (empty stub for now; grown later):
  ```sql
  -- Named queries are added by later tasks. Keep this file present so the
  -- `include:` in database.dart resolves.
  ```
  Create `packages/encarta_data/lib/encarta_data.dart` (barrel; grown later):
  ```dart
  /// Public API for read-only access to the recovered Encarta 2009 corpus.
  library;

  // Public surface is exported by later tasks (EncartaDb, models, encartaSnippet).
  ```

- [ ] **Step 4: Generate code, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && dart pub get
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/skeleton_test.dart
  ```
  Expected: workspace `pub get` succeeds (encarta_data now exists), codegen writes `lib/src/database.g.dart` with `_$EncartaDatabase`, test PASSES (`SELECT 1` → 1).

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data pubspec.lock && git commit -m "feat(data): scaffold encarta_data drift package with fts5 codegen"
  ```

---

### Task 3: Build & commit the test fixture `.sqlite`

**Files:** Create — `packages/encarta_data/tool/build_fixture.dart`, `packages/encarta_data/test/fixtures/encarta_fixture.sqlite` (generated, committed), `packages/encarta_data/test/fixture_test.dart`.
**Interfaces:** Produces: `test/fixtures/encarta_fixture.sqlite` — a ~43-article slice (4 source tiers + 3 media-rich articles + 10 `home`-group media rows) with `article_fts` populated at `rowid == refid`. Every later test opens this fixture.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/fixture_test.dart`:
  ```dart
  import 'dart:ffi';
  import 'dart:io';

  import 'package:sqlite3/open.dart';
  import 'package:sqlite3/sqlite3.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    test('fixture exists, has articles, and fts rowid == article.refid', () {
      // The fixture must be opened with an fts5-capable sqlite3.
      for (final p in const [
        '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
        '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
      ]) {
        if (File(p).existsSync()) {
          open.overrideForAll(() => DynamicLibrary.open(p));
          break;
        }
      }
      expect(File(fixturePath).existsSync(), isTrue,
          reason: 'run: dart run tool/build_fixture.dart');
      final db = sqlite3.open(fixturePath, mode: OpenMode.readOnly);
      addTearDown(db.dispose);

      final articleN = db.select('SELECT count(*) AS n FROM article').first['n'] as int;
      expect(articleN, greaterThanOrEqualTo(30));

      // Every fts rowid maps to a real article.refid (the invariant under test).
      final unmapped = db.select(
        'SELECT count(*) AS n FROM article_fts f '
        'WHERE NOT EXISTS (SELECT 1 FROM article a WHERE a.refid = f.rowid)',
      ).first['n'] as int;
      expect(unmapped, 0);

      // home-group media is present so featured()'s probe has something to read.
      final home = db.select(
        "SELECT count(*) AS n FROM media WHERE \"group\" = 'home'",
      ).first['n'] as int;
      expect(home, greaterThan(0));
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/fixture_test.dart
  ```
  Expected FAIL: `fixture exists` expectation fails — `test/fixtures/encarta_fixture.sqlite` does not exist yet.

- [ ] **Step 3: Write minimal implementation.**
  Create `packages/encarta_data/tool/build_fixture.dart` (one-shot dev tool; copies a slice from the real DB via `ATTACH`, then builds the contentless FTS in Dart so `rowid == refid`):
  ```dart
  // Builds test/fixtures/encarta_fixture.sqlite from the real corpus.
  // Run once, from the package root, with the real DB present:
  //   dart run tool/build_fixture.dart
  import 'dart:convert';
  import 'dart:ffi';
  import 'dart:io';

  import 'package:sqlite3/open.dart';
  import 'package:sqlite3/sqlite3.dart';

  const srcDb =
      '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';
  const outDb = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    // fts5 lives only in an fts5-enabled libsqlite3 (NOT macOS system sqlite3).
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
      stderr.writeln('No fts5-capable libsqlite3 found (install: brew install sqlite).');
      exit(1);
    }
    if (!File(srcDb).existsSync()) {
      stderr.writeln('Real corpus not found at $srcDb');
      exit(1);
    }

    final out = File(outDb);
    if (out.existsSync()) out.deleteSync();
    out.parent.createSync(recursive: true);

    final dst = sqlite3.open(outDb);
    dst.execute("ATTACH DATABASE '$srcDb' AS src");

    dst.execute('''
      CREATE TABLE article (refid INTEGER PRIMARY KEY, source TEXT, title TEXT, xml BLOB);
      CREATE TABLE asset (baggage_id TEXT PRIMARY KEY, hash TEXT, kind TEXT, ext TEXT, path TEXT, source TEXT);
      CREATE TABLE media (refid INTEGER PRIMARY KEY, "group" TEXT, title TEXT, credit TEXT, caption TEXT, source TEXT);
      CREATE TABLE media_file (media_refid INTEGER, role TEXT, baggage_id TEXT, ext TEXT, PRIMARY KEY(media_refid, role));
      CREATE TABLE article_media (article_refid INTEGER, media_refid INTEGER, PRIMARY KEY(article_refid, media_refid));
      CREATE TABLE xref (refid INTEGER, target_refid INTEGER, PRIMARY KEY(refid, target_refid));
      CREATE VIRTUAL TABLE article_fts USING fts5(body, content='', contentless_delete=1, tokenize='unicode61');
    ''');

    // Pick the slice: 10 titled articles per source tier ...
    final ids = <int>{};
    for (final tier in const ['CONTDLX.AKC', 'CONTSTD.AKC', 'CONTSTC.AKC', 'CONTKDC.AKC']) {
      for (final r in dst.select(
          'SELECT refid FROM src.article WHERE source = ? AND title IS NOT NULL '
          'ORDER BY refid LIMIT 10',
          [tier])) {
        ids.add(r['refid'] as int);
      }
    }
    // ... plus the 3 most media-rich articles (so mediaForArticle has real data).
    for (final r in dst.select(
        'SELECT a.refid AS refid FROM src.article_media am '
        'JOIN src.article a ON a.refid = am.article_refid '
        'WHERE a.title IS NOT NULL GROUP BY a.refid ORDER BY count(*) DESC LIMIT 3')) {
      ids.add(r['refid'] as int);
    }
    final inC = ids.join(',');

    dst.execute('INSERT INTO article SELECT * FROM src.article WHERE refid IN ($inC)');
    dst.execute('INSERT INTO article_media SELECT * FROM src.article_media WHERE article_refid IN ($inC)');
    dst.execute('INSERT INTO media SELECT * FROM src.media WHERE refid IN (SELECT media_refid FROM article_media)');
    dst.execute("INSERT OR IGNORE INTO media SELECT * FROM src.media WHERE \"group\" = 'home' ORDER BY refid LIMIT 10");
    dst.execute('INSERT INTO media_file SELECT * FROM src.media_file WHERE media_refid IN (SELECT refid FROM media)');
    dst.execute('INSERT INTO asset SELECT * FROM src.asset WHERE baggage_id IN (SELECT baggage_id FROM media_file)');
    // Keep only xrefs whose target is also in the slice, so outboundXrefs JOINs resolve.
    dst.execute('INSERT INTO xref SELECT * FROM src.xref WHERE refid IN ($inC) AND target_refid IN ($inC)');

    // Build the contentless FTS in Dart, with rowid == refid (the invariant).
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
    final n = dst.select('SELECT count(*) AS n FROM article').first['n'];
    dst.dispose();
    stdout.writeln('Wrote $outDb with $n articles.');
  }
  ```

- [ ] **Step 4: Run the tool, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run tool/build_fixture.dart
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/fixture_test.dart
  ```
  Expected: tool prints `Wrote test/fixtures/encarta_fixture.sqlite with 43 articles.` (count may vary slightly); test PASSES.

- [ ] **Step 5: Commit (including the binary fixture).**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add -f packages/encarta_data/tool/build_fixture.dart packages/encarta_data/test/fixtures/encarta_fixture.sqlite packages/encarta_data/test/fixture_test.dart && git commit -m "test(data): build and commit encarta fixture sqlite (rowid==refid)"
  ```

---

### Task 4: fts5 loader + read-only `EncartaDb.open` / `close`

**Files:** Create — `packages/encarta_data/lib/src/encarta_db.dart`, `packages/encarta_data/test/open_close_test.dart`. Modify — `packages/encarta_data/lib/encarta_data.dart`.
**Interfaces:** Consumes: `EncartaDatabase` (Task 2). Produces: `static Future<EncartaDb> open(String dbPath)`, `Future<void> close()`; the `QueryInterceptor` that keeps drift from writing `user_version` to a read-only DB; the `_loadFts5Sqlite()` loader reused by every query method.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/open_close_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    test('open() opens the fixture read-only and runs a query without writing', () async {
      final db = await EncartaDb.open(fixturePath);
      addTearDown(db.close);
      // A successful query proves: fts5 lib loaded, read-only open, and that
      // drift did not blow up trying to write user_version to the DB.
      final n = await db.debugArticleCount();
      expect(n, greaterThanOrEqualTo(30));
    });

    test('close() can be called and reopened', () async {
      final db = await EncartaDb.open(fixturePath);
      await db.close();
      final db2 = await EncartaDb.open(fixturePath);
      addTearDown(db2.close);
      expect(await db2.debugArticleCount(), greaterThanOrEqualTo(30));
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/open_close_test.dart
  ```
  Expected FAIL: `EncartaDb` is undefined (encarta_db.dart not created / not exported).

- [ ] **Step 3: Write minimal implementation.**
  Create `packages/encarta_data/lib/src/encarta_db.dart`:
  ```dart
  import 'dart:ffi';
  import 'dart:io';

  import 'package:drift/drift.dart';
  import 'package:drift/native.dart';
  import 'package:sqlite3/open.dart';
  import 'package:sqlite3/sqlite3.dart';

  import 'database.dart';

  bool _fts5LoaderInstalled = false;

  /// Point the `sqlite3` package at an fts5-capable libsqlite3.
  ///
  /// macOS system sqlite3 ships WITHOUT fts5 (`no such module: fts5`); the
  /// Homebrew build does. We override the global open hook once. If no such
  /// library is found we leave the default in place — non-fts queries still
  /// work, and [EncartaDb.search] will surface a clear "no such module" error.
  void _loadFts5Sqlite() {
    if (_fts5LoaderInstalled) return;
    for (final p in const [
      '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
      '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
    ]) {
      if (File(p).existsSync()) {
        open.overrideForAll(() => DynamicLibrary.open(p));
        break;
      }
    }
    _fts5LoaderInstalled = true;
  }

  /// Swallows the `PRAGMA user_version = N` write drift would otherwise issue
  /// when it sees `user_version == 0` on first open. The corpus is read-only,
  /// so that write must never reach the file. All reads pass through untouched.
  class _ReadOnlyInterceptor extends QueryInterceptor {
    @override
    Future<void> runCustom(
      QueryExecutor executor,
      String statement,
      List<Object?> args,
    ) {
      final s = statement.trimLeft().toLowerCase();
      if (s.startsWith('pragma user_version =')) {
        return Future<void>.value();
      }
      return super.runCustom(executor, statement, args);
    }
  }

  /// Read-only typed access to the recovered Encarta 2009 corpus.
  class EncartaDb {
    EncartaDb._(this._db);

    final EncartaDatabase _db;

    /// Opens [dbPath] READ-ONLY. Loads an fts5-capable sqlite3 first.
    static Future<EncartaDb> open(String dbPath) async {
      _loadFts5Sqlite();
      final raw = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final executor = NativeDatabase.opened(raw).interceptWith(_ReadOnlyInterceptor());
      return EncartaDb._(EncartaDatabase(executor));
    }

    Future<void> close() => _db.close();

    /// Test-only: row count, used to prove the connection is live.
    Future<int> debugArticleCount() async {
      final row = await _db.customSelect('SELECT count(*) AS n FROM article').getSingle();
      return row.read<int>('n');
    }
  }
  ```
  Replace `packages/encarta_data/lib/encarta_data.dart` with:
  ```dart
  /// Public API for read-only access to the recovered Encarta 2009 corpus.
  library;

  export 'src/encarta_db.dart' show EncartaDb;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/open_close_test.dart
  ```
  Expected PASS: both tests green (read-only open works; no read-only-write error).

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): read-only EncartaDb.open/close with fts5 loader + user_version guard"
  ```

---

### Task 5: Runtime verification — `article_fts` rowid == `article.refid`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/fts_mapping_test.dart`.
**Interfaces:** Consumes: `EncartaDb.open`. Produces: `Future<bool> verifyFtsRowidMapping()` — the invariant on which `search()` depends. This is the contract's mandated open-question #1.

> **Why this task is mandatory.** The fts5 table is contentless, so `search()` returns `article_fts.rowid` and we treat it as `article.refid`. If the ETL did not store `rowid == refid`, every search result would point at the wrong article. The macOS `sqlite3` CLI cannot even open this table (no fts5), so the check can ONLY run through drift's fts5-loaded FFI — here. The check has two parts: (a) **no fts rowid is orphaned** (every rowid is a real refid), and (b) a **positive lookup** (searching a token from a known article returns that article's refid). If the invariant ever fails, the fallback is documented in Step 3.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/fts_mapping_test.dart`:
  ```dart
  import 'dart:io';

  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';
  const realDbPath =
      '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';

  void main() {
    test('fixture: every fts rowid maps to an article.refid', () async {
      final db = await EncartaDb.open(fixturePath);
      addTearDown(db.close);
      expect(await db.verifyFtsRowidMapping(), isTrue);
    });

    test('REAL DB: fts rowid == article.refid (skipped if corpus absent)', () async {
      if (!File(realDbPath).existsSync()) {
        markTestSkipped('real corpus not present');
        return;
      }
      final db = await EncartaDb.open(realDbPath);
      addTearDown(db.close);
      expect(await db.verifyFtsRowidMapping(), isTrue,
          reason: 'fts rowid is NOT article.refid — enable the mapping fallback');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/fts_mapping_test.dart
  ```
  Expected FAIL: `verifyFtsRowidMapping` is undefined on `EncartaDb`.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  -- Counts fts rows whose rowid is NOT a valid article.refid. Must be 0.
  ftsRowidUnmapped:
  SELECT count(*) AS unmapped FROM article_fts f
  WHERE NOT EXISTS (SELECT 1 FROM article a WHERE a.refid = f.rowid);
  ```
  Add to `EncartaDb` (inside `lib/src/encarta_db.dart`, before the closing brace):
  ```dart
    /// Verifies the contentless-FTS invariant: `article_fts.rowid == article.refid`.
    ///
    /// Returns true when no fts rowid is orphaned. If this ever returns false,
    /// the corpus ETL did not align rowids with refids; the fallback is to stop
    /// trusting the rowid and instead resolve each hit through a refid-mapping
    /// table emitted by the ETL (quarry), or to rebuild the FTS index with an
    /// explicit `INSERT INTO article_fts(rowid, body)` keyed by refid (as the
    /// fixture builder already does). Until then `search()` must not be trusted.
    Future<bool> verifyFtsRowidMapping() async {
      final unmapped = await _db.ftsRowidUnmapped().getSingle();
      return unmapped == 0;
    }
  ```
  (drift names the scalar-count query method `ftsRowidUnmapped()` returning `Selectable<int>`.)

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/fts_mapping_test.dart
  ```
  Expected PASS: fixture test green; real-DB test green if the corpus is present (else skipped). Record the real-DB result in the PR/notes — this is the runtime confirmation of open-question #1.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): verify article_fts rowid == article.refid at runtime"
  ```

---

### Task 6: `Article` data class

**Files:** Create — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/test/article_test.dart`. Modify — `packages/encarta_data/lib/encarta_data.dart`.
**Interfaces:** Produces: `Article { int refid; String title; String source; Uint8List xmlBytes; }` (immutable, const constructor).

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/article_test.dart`:
  ```dart
  import 'dart:typed_data';

  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    test('Article holds fields and supports value equality', () {
      final a = Article(
        refid: 1,
        title: 'Atom',
        source: 'CONTDLX.AKC',
        xmlBytes: Uint8List.fromList(const [60, 99, 62]),
      );
      final b = Article(
        refid: 1,
        title: 'Atom',
        source: 'CONTDLX.AKC',
        xmlBytes: Uint8List.fromList(const [60, 99, 62]),
      );
      expect(a.refid, 1);
      expect(a.title, 'Atom');
      expect(a.source, 'CONTDLX.AKC');
      expect(a.xmlBytes, [60, 99, 62]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/article_test.dart
  ```
  Expected FAIL: `Article` is undefined.

- [ ] **Step 3: Write minimal implementation.**
  Create `packages/encarta_data/lib/src/models.dart`:
  ```dart
  import 'dart:typed_data';

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// One article: identity, resolved title, source tier, and raw XML body bytes.
  class Article {
    const Article({
      required this.refid,
      required this.title,
      required this.source,
      required this.xmlBytes,
    });

    final int refid;
    final String title;
    final String source;
    final Uint8List xmlBytes;

    @override
    bool operator ==(Object other) =>
        other is Article &&
        other.refid == refid &&
        other.title == title &&
        other.source == source &&
        _bytesEqual(other.xmlBytes, xmlBytes);

    @override
    int get hashCode => Object.hash(refid, title, source, xmlBytes.length);
  }
  ```
  Add to `packages/encarta_data/lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart' show Article;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/article_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): add Article data class"
  ```

---

### Task 7: `getArticle(refid)`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/get_article_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `Article`. Produces: `Future<Article?> getArticle(int refid)`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/get_article_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('getArticle returns the row for a known refid', () async {
      // Pick any titled refid from the fixture via the A-Z index (Task 17).
      final any = (await db.titlesIndex(limit: 1)).single;
      final article = await db.getArticle(any.refid);
      expect(article, isNotNull);
      expect(article!.refid, any.refid);
      expect(article.title, any.title);
      expect(article.xmlBytes, isNotEmpty);
    });

    test('getArticle returns null for an absent refid', () async {
      expect(await db.getArticle(-1), isNull);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/get_article_test.dart
  ```
  Expected FAIL: `getArticle` (and `titlesIndex`) undefined. (This task adds `getArticle`; `titlesIndex` arrives in Task 17 — to keep this task independently runnable, temporarily fetch a refid via `debugArticleCount`-style raw query instead. See note.)
  > Note: to keep Task 7 self-contained, replace the `titlesIndex` line with a one-off raw fetch helper already available: add a private test seam is unnecessary — instead use `getArticle` against a refid obtained from `db.firstTitledRefid()` introduced below.

  Revise the test's known-refid block to not depend on Task 17:
  ```dart
    test('getArticle returns the row for a known refid', () async {
      final refid = await db.firstTitledRefid();
      final article = await db.getArticle(refid);
      expect(article, isNotNull);
      expect(article!.refid, refid);
      expect(article.xmlBytes, isNotEmpty);
    });
  ```

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  getArticleByRefid:
  SELECT refid, title, source, xml FROM article WHERE refid = :refid;

  -- Test seam: smallest titled refid, used by unit tests to pick a real row.
  firstTitledRefid:
  SELECT refid FROM article WHERE title IS NOT NULL ORDER BY refid LIMIT 1;
  ```
  Add to `EncartaDb`:
  ```dart
    /// Loads one article by id, or null if absent. Missing titles map to ''.
    Future<Article?> getArticle(int refid) async {
      final row = await _db.getArticleByRefid(refid).getSingleOrNull();
      if (row == null) return null;
      return Article(
        refid: row.refid,
        title: row.title ?? '',
        source: row.source ?? '',
        xmlBytes: row.xml ?? Uint8List(0),
      );
    }

    /// Test seam: the smallest titled refid in the corpus.
    Future<int> firstTitledRefid() => _db.firstTitledRefid().getSingle();
  ```
  Add `import 'dart:typed_data';` to the top of `encarta_db.dart` (for `Uint8List`), and `import 'models.dart';`.

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/get_article_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): getArticle(refid) -> Article"
  ```

---

### Task 8: `SearchHit` data class

**Files:** Modify — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/lib/encarta_data.dart`. Create — `packages/encarta_data/test/search_hit_test.dart`.
**Interfaces:** Produces: `SearchHit { int refid; String title; double rank; }`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/search_hit_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    test('SearchHit holds fields and supports value equality', () {
      const a = SearchHit(refid: 42, title: 'Mars', rank: -1.5);
      const b = SearchHit(refid: 42, title: 'Mars', rank: -1.5);
      expect(a.refid, 42);
      expect(a.title, 'Mars');
      expect(a.rank, -1.5);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/search_hit_test.dart
  ```
  Expected FAIL: `SearchHit` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/models.dart`:
  ```dart
  /// A search result: target article id, its title, and the bm25 rank
  /// (lower = more relevant; bm25 returns negative scores).
  class SearchHit {
    const SearchHit({required this.refid, required this.title, required this.rank});

    final int refid;
    final String title;
    final double rank;

    @override
    bool operator ==(Object other) =>
        other is SearchHit &&
        other.refid == refid &&
        other.title == title &&
        other.rank == rank;

    @override
    int get hashCode => Object.hash(refid, title, rank);
  }
  ```
  Update the export in `lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart' show Article, SearchHit;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/search_hit_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): add SearchHit data class"
  ```

---

### Task 9: `encartaSnippet()` — Dart contentless-FTS snippet generation

**Files:** Create — `packages/encarta_data/lib/src/snippet.dart`, `packages/encarta_data/test/snippet_test.dart`. Modify — `packages/encarta_data/lib/encarta_data.dart`.
**Interfaces:** Produces: `String encartaSnippet(String xmlText, String query, {int radius = 120})` — exposed because contentless fts5 cannot return `snippet()`/`highlight()`; the Search screen calls this over `Article.xmlBytes`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/snippet_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    const xml =
        '<text><pkey>The <i>quartz</i> mineral is a common rock-forming '
        'silicate found across the planet in many forms.</pkey></text>';

    test('strips tags and centers on the first query hit', () {
      final s = encartaSnippet(xml, 'quartz', radius: 12);
      expect(s, contains('quartz'));
      expect(s, isNot(contains('<')));
      expect(s, startsWith('…')); // leading ellipsis: hit not at the very start
    });

    test('decodes basic entities and collapses whitespace', () {
      final s = encartaSnippet('<p>Tom &amp;   Jerry</p>', 'jerry');
      expect(s, contains('Tom & Jerry'));
    });

    test('no hit -> returns a leading excerpt', () {
      final s = encartaSnippet(xml, 'zzz', radius: 8);
      expect(s, startsWith('The quartz')); // first chars of stripped text
      expect(s, isNot(contains('<')));
    });

    test('empty body -> empty string', () {
      expect(encartaSnippet('', 'x'), isEmpty);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/snippet_test.dart
  ```
  Expected FAIL: `encartaSnippet` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Create `packages/encarta_data/lib/src/snippet.dart`:
  ```dart
  final _tagRe = RegExp(r'<[^>]*>');
  final _wsRe = RegExp(r'\s+');

  /// Builds a search snippet from raw article XML.
  ///
  /// The fts5 table is contentless, so SQLite's `snippet()`/`highlight()` return
  /// nothing — we generate snippets ourselves: strip tags, decode the few common
  /// XML entities, then window `radius` characters around the first hit of the
  /// query's first token. Returns a leading excerpt when there is no hit.
  String encartaSnippet(String xmlText, String query, {int radius = 120}) {
    final text = xmlText
        .replaceAll(_tagRe, ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll(_wsRe, ' ')
        .trim();
    if (text.isEmpty) return '';

    final term = query
        .split(_wsRe)
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');

    String excerpt() =>
        text.length <= radius * 2 ? text : '${text.substring(0, radius * 2).trim()}…';

    if (term.isEmpty) return excerpt();

    final idx = text.toLowerCase().indexOf(term.toLowerCase());
    if (idx < 0) return excerpt();

    var start = idx - radius;
    var end = idx + term.length + radius;
    final hasLead = start > 0;
    final hasTrail = end < text.length;
    if (start < 0) start = 0;
    if (end > text.length) end = text.length;

    final core = text.substring(start, end).trim();
    return '${hasLead ? '…' : ''}$core${hasTrail ? '…' : ''}';
  }
  ```
  Add to `lib/encarta_data.dart`:
  ```dart
  export 'src/snippet.dart' show encartaSnippet;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/snippet_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): encartaSnippet() Dart snippet generation for contentless FTS"
  ```

---

### Task 10: `search(query, {limit, offset})`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/search_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `SearchHit`. Produces: `Future<List<SearchHit>> search(String query, {int limit = 25, int offset = 0})` — bm25-ranked, paginated, joined to titles. Depends on the rowid invariant verified in Task 5.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/search_test.dart`:
  ```dart
  import 'dart:convert';

  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('search returns ranked hits whose refids resolve to real articles', () async {
      // Derive a guaranteed-present token from the first fixture article's body.
      final refid = await db.firstTitledRefid();
      final article = (await db.getArticle(refid))!;
      final body = utf8.decode(article.xmlBytes, allowMalformed: true);
      final token = RegExp(r'[A-Za-z]{5,}')
          .allMatches(body)
          .map((m) => m.group(0)!)
          .first;

      final hits = await db.search(token, limit: 10);
      expect(hits, isNotEmpty);
      // Each hit maps to a loadable article (rowid==refid invariant in practice).
      final first = await db.getArticle(hits.first.refid);
      expect(first, isNotNull);
      // Results are sorted by bm25 ascending (more relevant first).
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i].rank, greaterThanOrEqualTo(hits[i - 1].rank));
      }
    });

    test('search paginates with limit/offset', () async {
      final page1 = await db.search('a', limit: 2, offset: 0);
      final page2 = await db.search('a', limit: 2, offset: 2);
      expect(page1.length, lessThanOrEqualTo(2));
      final overlap = page1.map((h) => h.refid).toSet()
        ..retainAll(page2.map((h) => h.refid).toSet());
      expect(overlap, isEmpty);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/search_test.dart
  ```
  Expected FAIL: `search` undefined on `EncartaDb`.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  -- Contentless FTS: returns rowid (== article.refid), title, and bm25 rank.
  -- Lower bm25 = more relevant. CAST keeps drift's inferred type a double.
  searchArticles:
  SELECT f.rowid AS refid, a.title AS title, CAST(bm25(article_fts) AS REAL) AS rank
  FROM article_fts f
  JOIN article a ON a.refid = f.rowid
  WHERE article_fts MATCH :query
  ORDER BY rank
  LIMIT :limit OFFSET :offset;
  ```
  Add to `EncartaDb`:
  ```dart
    /// Full-text search, bm25-ranked (most relevant first), paginated.
    Future<List<SearchHit>> search(
      String query, {
      int limit = 25,
      int offset = 0,
    }) async {
      final rows = await _db.searchArticles(query, limit, offset).get();
      return [
        for (final r in rows)
          SearchHit(refid: r.refid, title: r.title ?? '', rank: r.rank),
      ];
    }
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/search_test.dart
  ```
  Expected PASS. (If build_runner errors on `bm25`/`MATCH`, confirm `build.yaml` lists `modules: [fts5]`.)

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): search() bm25-ranked paginated FTS over titles"
  ```

---

### Task 11: `MediaItem` data class

**Files:** Modify — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/lib/encarta_data.dart`. Create — `packages/encarta_data/test/media_item_test.dart`.
**Interfaces:** Produces: `MediaItem { int mediaRefid; String role; String group; String? title; String? caption; String? credit; String assetPath; String ext; String kind; }`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/media_item_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    test('MediaItem holds fields and supports value equality', () {
      const a = MediaItem(
        mediaRefid: 7,
        role: 'image',
        group: 'media',
        title: 'Eagle',
        caption: 'A bald eagle',
        credit: 'NPS',
        assetPath: 'image/abc123.jpg',
        ext: '.jpg',
        kind: 'image',
      );
      const b = MediaItem(
        mediaRefid: 7,
        role: 'image',
        group: 'media',
        title: 'Eagle',
        caption: 'A bald eagle',
        credit: 'NPS',
        assetPath: 'image/abc123.jpg',
        ext: '.jpg',
        kind: 'image',
      );
      expect(a.assetPath, 'image/abc123.jpg');
      expect(a.title, 'Eagle');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/media_item_test.dart
  ```
  Expected FAIL: `MediaItem` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/models.dart`:
  ```dart
  /// One media slot for an article: its role + group, optional editorial text,
  /// and the resolved asset (`assetPath` is RELATIVE to `<dataDir>/assets/`).
  class MediaItem {
    const MediaItem({
      required this.mediaRefid,
      required this.role,
      required this.group,
      required this.title,
      required this.caption,
      required this.credit,
      required this.assetPath,
      required this.ext,
      required this.kind,
    });

    final int mediaRefid;
    final String role;
    final String group;
    final String? title;
    final String? caption;
    final String? credit;
    final String assetPath;
    final String ext;
    final String kind;

    @override
    bool operator ==(Object other) =>
        other is MediaItem &&
        other.mediaRefid == mediaRefid &&
        other.role == role &&
        other.group == group &&
        other.title == title &&
        other.caption == caption &&
        other.credit == credit &&
        other.assetPath == assetPath &&
        other.ext == ext &&
        other.kind == kind;

    @override
    int get hashCode => Object.hash(
        mediaRefid, role, group, title, caption, credit, assetPath, ext, kind);
  }
  ```
  Update the export in `lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart' show Article, SearchHit, MediaItem;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/media_item_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): add MediaItem data class"
  ```

---

### Task 12: `mediaForArticle(refid)`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/media_for_article_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `MediaItem`. Produces: `Future<List<MediaItem>> mediaForArticle(int refid)` over the verified `article_media → media_file → asset` + `media` join.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/media_for_article_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('mediaForArticle returns resolved assets for a media-rich article', () async {
      // The fixture deliberately includes the 3 most media-rich articles.
      final refid = await db.mostMediaRefid();
      final media = await db.mediaForArticle(refid);
      expect(media, isNotEmpty);
      final first = media.first;
      expect(first.assetPath, isNotEmpty); // relative to <dataDir>/assets/
      expect(first.ext, startsWith('.'));
      expect(first.role, isNotEmpty);
    });

    test('mediaForArticle returns empty for an article with no media', () async {
      expect(await db.mediaForArticle(-1), isEmpty);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/media_for_article_test.dart
  ```
  Expected FAIL: `mediaForArticle` / `mostMediaRefid` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  mediaForArticle:
  SELECT
    m.refid    AS mediaRefid,
    mf.role    AS role,
    m."group"  AS mgroup,
    m.title    AS title,
    m.caption  AS caption,
    m.credit   AS credit,
    a.path     AS assetPath,
    a.ext      AS ext,
    a.kind     AS kind
  FROM article_media am
  JOIN media m       ON m.refid = am.media_refid
  JOIN media_file mf ON mf.media_refid = am.media_refid
  JOIN asset a       ON a.baggage_id = mf.baggage_id
  WHERE am.article_refid = :refid
  ORDER BY mf.role;

  -- Test seam: the article carrying the most media in the fixture.
  mostMediaRefid:
  SELECT a.refid AS refid FROM article_media am
  JOIN article a ON a.refid = am.article_refid
  GROUP BY a.refid ORDER BY count(*) DESC LIMIT 1;
  ```
  Add to `EncartaDb`:
  ```dart
    /// All media slots for an article via article_media → media_file → asset.
    /// `assetPath` is relative to `<dataDir>/assets/`.
    Future<List<MediaItem>> mediaForArticle(int refid) async {
      final rows = await _db.mediaForArticle(refid).get();
      return [
        for (final r in rows)
          MediaItem(
            mediaRefid: r.mediaRefid,
            role: r.role,
            group: r.mgroup ?? '',
            title: r.title,
            caption: r.caption,
            credit: r.credit,
            assetPath: r.assetPath ?? '',
            ext: r.ext ?? '',
            kind: r.kind ?? '',
          ),
      ];
    }

    /// Test seam: the most media-rich article id in the corpus.
    Future<int> mostMediaRefid() => _db.mostMediaRefid().getSingle();
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/media_for_article_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): mediaForArticle() via article_media->media_file->asset join"
  ```

---

### Task 13: `AssetRow` data class + `assetByBaggageId(baggageId)`

**Files:** Modify — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`, `packages/encarta_data/lib/encarta_data.dart`. Create — `packages/encarta_data/test/asset_by_baggage_id_test.dart`.
**Interfaces:** Produces: `AssetRow { String baggageId; String hash; String kind; String ext; String path; }` (immutable, const) and `Future<AssetRow?> assetByBaggageId(String baggageId)`.

> **Cross-plan note (for `encarta_assets`).** `inlinebmp type=27` carries an `id` that is an `asset.baggage_id`. The assets package resolves those inline images by looking the baggage_id up directly in the `asset` table — this method is its data-layer entry point. `path` is relative to `<dataDir>/assets/`. The fixture already contains real `asset` rows (copied via the `media_file → asset` join in Task 3's builder), so a known baggage_id exists; this task adds an `anyBaggageId` test seam to fetch one without hardcoding.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/asset_by_baggage_id_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('assetByBaggageId returns the row for a known baggage_id', () async {
      final known = await db.anyBaggageId(); // a real asset row in the fixture
      expect(known, isNotNull);
      final row = await db.assetByBaggageId(known!);
      expect(row, isNotNull);
      expect(row!.baggageId, known);
      expect(row.path, isNotEmpty); // relative to <dataDir>/assets/
      expect(row.ext, startsWith('.'));
      expect(row.kind, isNotEmpty);
    });

    test('assetByBaggageId returns null for an unknown baggage_id', () async {
      expect(await db.assetByBaggageId('no-such-baggage-id'), isNull);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/asset_by_baggage_id_test.dart
  ```
  Expected FAIL: `AssetRow` / `assetByBaggageId` / `anyBaggageId` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/models.dart`:
  ```dart
  /// One row of the `asset` table: the stored binary's identity and location.
  /// `path` is RELATIVE to `<dataDir>/assets/`. Used by encarta_assets to
  /// resolve `inlinebmp type=27` (whose `id` is an `asset.baggage_id`).
  class AssetRow {
    const AssetRow({
      required this.baggageId,
      required this.hash,
      required this.kind,
      required this.ext,
      required this.path,
    });

    final String baggageId;
    final String hash;
    final String kind;
    final String ext;
    final String path;

    @override
    bool operator ==(Object other) =>
        other is AssetRow &&
        other.baggageId == baggageId &&
        other.hash == hash &&
        other.kind == kind &&
        other.ext == ext &&
        other.path == path;

    @override
    int get hashCode => Object.hash(baggageId, hash, kind, ext, path);
  }
  ```
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  assetByBaggageId:
  SELECT baggage_id, hash, kind, ext, path FROM asset WHERE baggage_id = :id;

  -- Test seam: any baggage_id present in the (fixture) asset table.
  anyBaggageId:
  SELECT baggage_id FROM asset LIMIT 1;
  ```
  Add to `EncartaDb`:
  ```dart
    /// Looks up a single asset by its baggage_id (the `inlinebmp type=27` id),
    /// or null if absent. `path` is relative to `<dataDir>/assets/`.
    Future<AssetRow?> assetByBaggageId(String baggageId) async {
      final row = await _db.assetByBaggageId(baggageId).getSingleOrNull();
      if (row == null) return null;
      return AssetRow(
        baggageId: row.baggageId,
        hash: row.hash ?? '',
        kind: row.kind ?? '',
        ext: row.ext ?? '',
        path: row.path ?? '',
      );
    }

    /// Test seam: any baggage_id present in the asset table, or null.
    Future<String?> anyBaggageId() => _db.anyBaggageId().getSingleOrNull();
  ```
  Update the export line in `packages/encarta_data/lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart' show Article, SearchHit, MediaItem, AssetRow;
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/asset_by_baggage_id_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): AssetRow + assetByBaggageId() for inlinebmp asset resolution"
  ```

---

### Task 14: `XrefTarget` data class

**Files:** Modify — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/lib/encarta_data.dart`. Create — `packages/encarta_data/test/xref_target_test.dart`.
**Interfaces:** Produces: `XrefTarget { int targetRefid; String title; }`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/xref_target_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    test('XrefTarget holds fields and supports value equality', () {
      const a = XrefTarget(targetRefid: 99, title: 'Gravity');
      const b = XrefTarget(targetRefid: 99, title: 'Gravity');
      expect(a.targetRefid, 99);
      expect(a.title, 'Gravity');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/xref_target_test.dart
  ```
  Expected FAIL: `XrefTarget` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/models.dart`:
  ```dart
  /// An outbound cross-reference target: the linked article id + its title.
  class XrefTarget {
    const XrefTarget({required this.targetRefid, required this.title});

    final int targetRefid;
    final String title;

    @override
    bool operator ==(Object other) =>
        other is XrefTarget &&
        other.targetRefid == targetRefid &&
        other.title == title;

    @override
    int get hashCode => Object.hash(targetRefid, title);
  }
  ```
  Update the export in `lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart'
      show Article, SearchHit, MediaItem, AssetRow, XrefTarget;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/xref_target_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): add XrefTarget data class"
  ```

---

### Task 15: `outboundXrefs(refid)`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/outbound_xrefs_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `XrefTarget`. Produces: `Future<List<XrefTarget>> outboundXrefs(int refid)`. The JOIN to `article` filters out dead links (targets absent from the corpus).

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/outbound_xrefs_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('outboundXrefs returns only targets that exist as articles', () async {
      // Find a refid that actually has an in-fixture xref (fixture keeps only
      // xrefs whose target is also present), else assert the empty-safe path.
      final src = await db.anyXrefSourceRefid();
      if (src == null) {
        expect(await db.outboundXrefs(-1), isEmpty);
        return;
      }
      final targets = await db.outboundXrefs(src);
      expect(targets, isNotEmpty);
      for (final t in targets) {
        expect(t.title, isNotEmpty); // came from a JOIN to article -> resolvable
        expect(await db.getArticle(t.targetRefid), isNotNull);
      }
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/outbound_xrefs_test.dart
  ```
  Expected FAIL: `outboundXrefs` / `anyXrefSourceRefid` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  outboundXrefs:
  SELECT x.target_refid AS targetRefid, a.title AS title
  FROM xref x
  JOIN article a ON a.refid = x.target_refid
  WHERE x.refid = :refid AND a.title IS NOT NULL
  ORDER BY a.title;

  -- Test seam: any source refid that has at least one resolvable xref.
  anyXrefSourceRefid:
  SELECT x.refid AS refid FROM xref x
  JOIN article a ON a.refid = x.target_refid
  LIMIT 1;
  ```
  Add to `EncartaDb`:
  ```dart
    /// Outbound cross-references for an article. Targets absent from the corpus
    /// are dropped by the JOIN, so callers never get dead links.
    Future<List<XrefTarget>> outboundXrefs(int refid) async {
      final rows = await _db.outboundXrefs(refid).get();
      return [
        for (final r in rows)
          XrefTarget(targetRefid: r.targetRefid, title: r.title ?? ''),
      ];
    }

    /// Test seam: any refid with at least one resolvable outbound xref, or null.
    Future<int?> anyXrefSourceRefid() => _db.anyXrefSourceRefid().getSingleOrNull();
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/outbound_xrefs_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): outboundXrefs() with dead-link filtering"
  ```

---

### Task 16: `TitleRef` data class

**Files:** Modify — `packages/encarta_data/lib/src/models.dart`, `packages/encarta_data/lib/encarta_data.dart`. Create — `packages/encarta_data/test/title_ref_test.dart`.
**Interfaces:** Produces: `TitleRef { int refid; String title; }` (used by `titlesIndex` and `featured`).

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/title_ref_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  void main() {
    test('TitleRef holds fields and supports value equality', () {
      const a = TitleRef(refid: 5, title: 'Atom');
      const b = TitleRef(refid: 5, title: 'Atom');
      expect(a.refid, 5);
      expect(a.title, 'Atom');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/title_ref_test.dart
  ```
  Expected FAIL: `TitleRef` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/models.dart`:
  ```dart
  /// A lightweight title pointer for browse/index lists: article id + title.
  class TitleRef {
    const TitleRef({required this.refid, required this.title});

    final int refid;
    final String title;

    @override
    bool operator ==(Object other) =>
        other is TitleRef && other.refid == refid && other.title == title;

    @override
    int get hashCode => Object.hash(refid, title);
  }
  ```
  Update the export in `lib/encarta_data.dart`:
  ```dart
  export 'src/models.dart'
      show Article, SearchHit, MediaItem, AssetRow, XrefTarget, TitleRef;
  ```

- [ ] **Step 4: Run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/title_ref_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): add TitleRef data class"
  ```

---

### Task 17: `titlesIndex({prefix, limit, offset})` — A–Z browse

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/titles_index_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `TitleRef`. Produces: `Future<List<TitleRef>> titlesIndex({String? prefix, int limit = 100, int offset = 0})`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/titles_index_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('titlesIndex returns titled refs sorted by title', () async {
      final all = await db.titlesIndex(limit: 100);
      expect(all, isNotEmpty);
      for (var i = 1; i < all.length; i++) {
        expect(all[i].title.compareTo(all[i - 1].title), greaterThanOrEqualTo(0));
      }
    });

    test('titlesIndex filters case-insensitively by prefix', () async {
      final all = await db.titlesIndex(limit: 200);
      final letter = all.first.title[0].toUpperCase();
      final filtered = await db.titlesIndex(prefix: letter, limit: 200);
      expect(filtered, isNotEmpty);
      for (final t in filtered) {
        expect(t.title.toUpperCase(), startsWith(letter));
      }
    });

    test('titlesIndex paginates with limit/offset', () async {
      final page1 = await db.titlesIndex(limit: 3, offset: 0);
      final page2 = await db.titlesIndex(limit: 3, offset: 3);
      final overlap = page1.map((t) => t.refid).toSet()
        ..retainAll(page2.map((t) => t.refid).toSet());
      expect(overlap, isEmpty);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/titles_index_test.dart
  ```
  Expected FAIL: `titlesIndex` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift` (one query; `:prefix` is `''` to match everything — SQLite `LIKE` is ASCII case-insensitive by default, giving A–Z browse):
  ```sql
  titlesIndex:
  SELECT refid, title FROM article
  WHERE title IS NOT NULL AND title LIKE :prefix || '%'
  ORDER BY title
  LIMIT :limit OFFSET :offset;
  ```
  Add to `EncartaDb`:
  ```dart
    /// A–Z browse over article titles. `prefix` is matched case-insensitively;
    /// null/empty returns the full alphabetical list (paginated).
    Future<List<TitleRef>> titlesIndex({
      String? prefix,
      int limit = 100,
      int offset = 0,
    }) async {
      final rows = await _db.titlesIndex(prefix ?? '', limit, offset).get();
      return [
        for (final r in rows) TitleRef(refid: r.refid, title: r.title ?? ''),
      ];
    }
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/titles_index_test.dart
  ```
  Expected PASS.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): titlesIndex() A-Z browse with prefix/pagination"
  ```

---

### Task 18: `randomArticle()`

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/random_article_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `Article`. Produces: `Future<Article?> randomArticle()`.

> Performance note: `ORDER BY random()` would full-scan 116k rows. Instead we pick a random point in the `refid` (INTEGER PRIMARY KEY = rowid) range and take the next titled article via an index range scan — O(log n). `min`/`max` on the PK are index-resolved.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/random_article_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('randomArticle returns a titled, loadable article', () async {
      final a = await db.randomArticle();
      expect(a, isNotNull);
      expect(a!.title, isNotEmpty);
      expect(a.xmlBytes, isNotEmpty);
      expect(await db.getArticle(a.refid), isNotNull);
    });

    test('randomArticle eventually varies (sampled 25x)', () async {
      final seen = <int>{};
      for (var i = 0; i < 25; i++) {
        seen.add((await db.randomArticle())!.refid);
      }
      expect(seen.length, greaterThan(1)); // not pinned to one row
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/random_article_test.dart
  ```
  Expected FAIL: `randomArticle` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  -- Random pick: jump to a random point in the refid range, take the next
  -- titled article. Fast (index range scan), uniform enough for "I'm feeling
  -- lucky". Returns nothing only if the random point lands past the last
  -- titled refid; randomArticleFallback covers that.
  randomArticleInRange:
  SELECT refid, title, source, xml FROM article
  WHERE refid >= (
    SELECT min(refid) + abs(random()) % (max(refid) - min(refid) + 1) FROM article
  ) AND title IS NOT NULL
  ORDER BY refid LIMIT 1;

  randomArticleFallback:
  SELECT refid, title, source, xml FROM article
  WHERE title IS NOT NULL ORDER BY refid LIMIT 1;
  ```
  Add to `EncartaDb`:
  ```dart
    /// A random titled article, or null if the corpus has none.
    Future<Article?> randomArticle() async {
      var row = await _db.randomArticleInRange().getSingleOrNull();
      row ??= await _db.randomArticleFallback().getSingleOrNull();
      if (row == null) return null;
      return Article(
        refid: row.refid,
        title: row.title ?? '',
        source: row.source ?? '',
        xmlBytes: row.xml ?? Uint8List(0),
      );
    }
  ```

- [ ] **Step 4: Regenerate, then run test to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/random_article_test.dart
  ```
  Expected PASS. (With ~43 fixture rows the "varies" test is reliable; in the rare event a tiny fixture pins one row, re-run the fixture builder to widen the slice.)

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): randomArticle() with fast range-pick + fallback"
  ```

---

### Task 19: `featured({limit})` — probe `media."group"='home'`, fall back to high-media articles

**Files:** Modify — `packages/encarta_data/lib/src/queries.drift`, `packages/encarta_data/lib/src/encarta_db.dart`. Create — `packages/encarta_data/test/featured_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `TitleRef`. Produces: `Future<List<TitleRef>> featured({int limit = 12})`.

> **Verified ambiguity (open-question #2).** The `home` group IS real curated content (rows "Animals", "Science", "The Arts"…), but at the data level it does **not** map to navigable articles: `home`-group media have **zero** `article_media` links, and `media.refid` **never** overlaps `article.refid` (both confirmed against the real DB). So `featured()` first *probes* the home group through the article join (as the contract specifies); finding nothing navigable, it uses the spec's documented fallback — top articles by media count (rich, recognizable entries like "United States History", "William Shakespeare"). This keeps every returned `TitleRef.refid` a real, openable `/article/:refid`.

- [ ] **Step 1: Write the failing test.**
  Create `packages/encarta_data/test/featured_test.dart`:
  ```dart
  import 'package:encarta_data/encarta_data.dart';
  import 'package:test/test.dart';

  const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

  void main() {
    late EncartaDb db;
    setUp(() async => db = await EncartaDb.open(fixturePath));
    tearDown(() => db.close());

    test('featured returns navigable article TitleRefs (via fallback)', () async {
      final feats = await db.featured(limit: 5);
      expect(feats, isNotEmpty);
      expect(feats.length, lessThanOrEqualTo(5));
      for (final f in feats) {
        expect(f.title, isNotEmpty);
        // Every featured ref MUST resolve to a real article (no orphan tiles).
        expect(await db.getArticle(f.refid), isNotNull);
      }
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test test/featured_test.dart
  ```
  Expected FAIL: `featured` undefined.

- [ ] **Step 3: Write minimal implementation.**
  Append to `packages/encarta_data/lib/src/queries.drift`:
  ```sql
  -- Primary probe: articles reachable from home-group media. (Verified empty in
  -- the current corpus — home media have no article_media links — but kept so
  -- the behavior auto-upgrades if the ETL ever wires home content to articles.)
  featuredHomeArticles:
  SELECT a.refid AS refid, a.title AS title
  FROM media m
  JOIN article_media am ON am.media_refid = m.refid
  JOIN article a ON a.refid = am.article_refid
  WHERE m."group" = 'home' AND a.title IS NOT NULL
  GROUP BY a.refid
  ORDER BY m.refid
  LIMIT :limit;

  -- Fallback: most media-rich articles (recognizable, image-heavy entries).
  featuredByMediaCount:
  SELECT a.refid AS refid, a.title AS title
  FROM article_media am
  JOIN article a ON a.refid = am.article_refid
  WHERE a.title IS NOT NULL
  GROUP BY a.refid
  ORDER BY count(*) DESC
  LIMIT :limit;
  ```
  Add to `EncartaDb`:
  ```dart
    /// Home-portal featured articles. Probes `media."group"='home'` first; if
    /// that yields no navigable articles (the verified current state), falls
    /// back to the most media-rich articles. Every result is a real article.
    Future<List<TitleRef>> featured({int limit = 12}) async {
      final home = await _db.featuredHomeArticles(limit).get();
      final rows = home.isNotEmpty
          ? home
          : await _db.featuredByMediaCount(limit).get();
      return [
        for (final r in rows) TitleRef(refid: r.refid, title: r.title ?? ''),
      ];
    }
  ```
  Add the final public exports to `lib/encarta_data.dart` (facade is already exported; confirm the barrel reads):
  ```dart
  /// Public API for read-only access to the recovered Encarta 2009 corpus.
  library;

  export 'src/encarta_db.dart' show EncartaDb;
  export 'src/models.dart'
      show Article, SearchHit, MediaItem, AssetRow, XrefTarget, TitleRef;
  export 'src/snippet.dart' show encartaSnippet;
  ```

- [ ] **Step 4: Regenerate, then run the FULL package suite to verify it passes.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart run build_runner build --delete-conflicting-outputs
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart test
  cd /Users/nexus/projects/experiments/strata/reader/packages/encarta_data && dart analyze
  ```
  Expected: all test files green; `dart analyze` reports no issues.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/nexus/projects/experiments/strata/reader && git add packages/encarta_data && git commit -m "feat(data): featured() probing home group with high-media fallback"
  ```

---

## Self-review notes

**Spec sections covered by this unit:**
- §3 architecture — the pub workspace root and the `encarta_data` member (the other three members are appended by their own units).
- §4 `encarta_data` — drift in existing-database read-only mode on the sqlite3 FFI, `.drift` files with the `fts5` analyzer module, build_runner codegen, all five locked data classes, and all locked API methods (`open`, `close`, `getArticle`, `search`, `mediaForArticle`, `outboundXrefs`, `titlesIndex`, `randomArticle`, `featured`). Plus one cross-plan addition agreed with the coordinator: `AssetRow` + `assetByBaggageId(baggageId)` (Task 13), the data-layer entry point `encarta_assets` uses to resolve `inlinebmp type=27` images by `asset.baggage_id`.
- §10 graceful degradation — missing titles → `''`; broken xrefs filtered by JOIN; `featured()` fallback; `randomArticle()` fallback.
- §11 open-question #1 (FTS rowid == refid) — Task 5 runtime verification, including the documented mapping fallback.
- §11 open-question #2 (`home` group) — Task 19 verified that home media do not map to articles and implemented the documented high-media fallback.

**Verified-at-runtime assumptions (confirmed on this machine, 2026-06-25):**
- macOS system/CLI `sqlite3` lacks fts5 (`no such module: fts5`); Homebrew's `/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib` provides fts5. The loader override is the contract's "fts5 only via the bundled FFI" requirement made concrete.
- The real DB's `user_version` is `0`, which would make drift attempt a `PRAGMA user_version = 1` write on open. The `_ReadOnlyInterceptor` swallows that write so the corpus stays untouched; Task 4 proves a read-only open succeeds.
- The `article_media → media_file → asset` + `media` join returns real, resolvable rows; `asset.path` is relative to `<dataDir>/assets/`.
- `home`-group media have zero `article_media` links and `media.refid` never equals `article.refid`.

**Judgment calls / spec ambiguities (flag for the caller):**
1. **Workspace member list.** The contract sketched `workspace: [packages/*, app/*]`, but `dart pub` does not support globs in `workspace:` and fails if a listed member directory is missing. To keep `dart pub get` green at every commit, the root lists only `packages/encarta_data` now, with an inline instruction (and this note) telling later units to append their own paths. Net effect matches the intended `packages/* + app/*` once all units land.
2. **`featured()` return semantics.** The contract locks `featured() → List<TitleRef>` and says it "probes `media."group"='home'`". Runtime verification shows home media are NOT navigable to articles, so the implementation probes home first (future-proof) then falls back to high-media articles so every `TitleRef.refid` is a real `/article/:refid`. If a later ETL wires home content to articles, the primary probe activates automatically with no API change.
3. **Snippet exposure.** `SearchHit` (locked) has no snippet field, and contentless fts5 cannot emit one, so snippet generation is a standalone exported function `encartaSnippet(xmlText, query)` rather than a method on `EncartaDb`/`SearchHit`. The Search screen composes `search()` + `getArticle()` + `encartaSnippet()`.
4. **"8 public API methods" count.** The contract's `EncartaDb` lists nine members; this plan treats `open`+`close` as one lifecycle task and the seven query methods as seven tasks (eight method-tasks total), which matches the prompt's "8 public API methods" while still covering every member. The cross-plan `assetByBaggageId` + `AssetRow` (Task 13) is an addition beyond the locked contract surface, agreed with the coordinator for `encarta_assets`'s `inlinebmp` resolution; the plan now has **19 tasks**.
5. **Two private "test seam" queries** (`firstTitledRefid`, `mostMediaRefid`, `anyXrefSourceRefid`) were added so unit tests pick real fixture rows without hardcoding refids that change when the fixture is rebuilt. They are exposed as plain methods on `EncartaDb` (not part of the locked public surface, but harmless); they can be moved behind a `@visibleForTesting` annotation if strict surface minimalism is desired.
