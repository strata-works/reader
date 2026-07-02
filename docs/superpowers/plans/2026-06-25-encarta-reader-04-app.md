# Encarta Reader — App (`app/encarta_reader`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter desktop app `encarta_reader` that wires `encarta_data`, `encarta_render`, and `encarta_assets` into an Encarta-era three-screen reader (Home portal, Search with live preview, three-pane Article) with `auto_route` navigation and browser-like Back/Forward.

**Architecture:** The app is the only unit that depends on all three packages. Screens are split into pure **presentational widgets** (take plain data bundles + callbacks; widget-tested without a DB) and thin **page/loader containers** (assemble data via injected fetchers; unit-tested with fakes, smoke-tested against the real DB). A `HistoryController` + `AppNavigator` provide Encarta "Back/Forward" on top of `auto_route`. All article styling flows through `EncartaTheme` from `encarta_render`; the renderer stays pure via injected callbacks wired here to `encarta_assets` and the router.

**Tech Stack:** Flutter 3.42 beta / Dart 3.12 beta, target macOS arm64; `auto_route ^9.2.2` (+ `auto_route_generator`, `build_runner` codegen); `media_kit ^1.1.11` (init only — playback lives in `encarta_assets`); path deps on `encarta_data` / `encarta_render` / `encarta_assets`; pub workspace (`resolution: workspace`).

## Global Constraints

- Toolchain: Flutter 3.42.0 beta, Dart 3.12 beta; target macOS arm64 only (Windows/Linux/mobile kept open, not built).
- DB is opened **read-only** at the configured data dir; the app never writes the corpus.
- Data dir is **configuration**: resolved (in order) from `--data-dir=<path>` CLI arg, then `ENCARTA_DATA_DIR` env var, then persisted setting, then default `/Users/nexus/projects/experiments/strata/quarry/build`.
- Consume the **locked** public APIs of the three packages exactly (signatures reproduced in each task's Interfaces block); never redefine them.
- `encarta_render` is pure: the app supplies every side-effecting callback (`AssetResolver = Widget Function(String inlineId, int inlineType)` → `EncartaAssets.inlineBmp(id, type)`, `XrefTap` → router push, `TitleForRefid` → cached lookup). `EncartaAssets` resolves baggage ids directly via `EncartaDb.assetByBaggageId` (type=27); type=28 → placeholder. The app only passes `db` into `EncartaAssets(db, config)`; no app-side baggage wiring.
- Graceful degradation everywhere (§10): missing title → first outline entry title → refid string; broken xref target → plain text; unresolved asset → placeholder; never crash, never blank.
- Media is **block-level** (rail / between blocks); only `inlinebmp` glyphs are truly inline.
- TDD for every task: write failing test → run-fail → minimal impl → run-pass → commit. Frequent commits.
- Flutter package → `flutter test`; codegen → `dart run build_runner build --delete-conflicting-outputs`. Tests touching the real 685 MB DB / 3.4 GB assets are tagged `integration` and run explicitly.
- `EncartaTheme` chrome color/measure getters used by app chrome (`chromeColor`, `onChromeColor`, `accentColor`, `surfaceColor`, `measure`) are CONFIRMED locked in `encarta_render` and populated by `EncartaTheme.faithfulInSpirit()`; no app-local theme.

---

## File Structure

Created/modified files (all under `app/encarta_reader/` unless noted):

- `pubspec.yaml` — app manifest: workspace member, path deps, `auto_route`, `media_kit`.
- `macos/` — generated macOS runner (from `flutter create --platforms=macos`).
- `lib/main.dart` — entrypoint: parse args, `bootstrap()`, `runApp`.
- `lib/src/app.dart` — `EncartaReaderApp`: `MaterialApp.router` wired to `AppRouter` + `AppScope`.
- `lib/src/bootstrap.dart` — `AppEnvironment` + `bootstrap()`: `MediaKit.ensureInitialized()`, open `EncartaDb`, build `EncartaAssets`.
- `lib/src/config/app_config.dart` — `AppConfig.resolve(args, env)`: data-dir resolution.
- `lib/src/nav/history_controller.dart` — `HistoryController`: push/back/forward stack.
- `lib/src/nav/app_navigator.dart` — `AppNavigator`: routes + history in one place.
- `lib/src/nav/app_router.dart` — `@AutoRouterConfig` `AppRouter`; route table.
- `lib/src/nav/app_router.gr.dart` — generated (build_runner).
- `lib/src/data/title_cache.dart` — `ArticleTitleCache`: sync cached titles for `TitleForRefid`.
- `lib/src/data/snippet.dart` — `makeSnippet(xmlBytes, query)`: our search snippet.
- `lib/src/data/tier.dart` — `tierBadge(source)`: CONT* → label.
- `lib/src/data/degradation.dart` — `resolveDisplayTitle(...)`.
- `lib/src/widgets/app_scope.dart` — `AppScope` InheritedWidget (env + nav + caches).
- `lib/src/widgets/top_toolbar.dart` — `EncartaToolbar` (home, back/forward, search box).
- `lib/src/screens/article/article_view.dart` — `ArticleViewData` + `ArticleView` (three-pane).
- `lib/src/screens/article/article_outline_pane.dart` — `ArticleOutlinePane` (outline + related).
- `lib/src/screens/article/media_rail.dart` — `MediaRail`.
- `lib/src/screens/article/article_page.dart` — `ArticlePage` + `buildArticleViewData(...)`.
- `lib/src/screens/search/search_view.dart` — `SearchViewData` + `SearchResultItem` + `SearchView`.
- `lib/src/screens/search/search_result_tile.dart` — `SearchResultTile`.
- `lib/src/screens/search/search_page.dart` — `SearchPage` + `buildSearchViewData(...)`.
- `lib/src/screens/home/home_view.dart` — `HomeViewData` + `HomeView`.
- `lib/src/screens/home/home_page.dart` — `HomePage` + `buildHomeViewData(...)`.
- `test/...` — one test file per task (paths in each task).
- `tool/probe_thumbnail_role.dart` / `tool/probe_featured.dart` — validation spikes (§11).
- `pubspec.yaml` (repo root, `reader/pubspec.yaml`) — ensure workspace lists `app/*` (defensive; may already exist from Unit 1).

---

## Task 1: App scaffold + workspace member

**Files:** Create — `app/encarta_reader/` (via `flutter create`), `app/encarta_reader/pubspec.yaml`, `app/encarta_reader/lib/src/app.dart`, `app/encarta_reader/test/app_scaffold_test.dart`; Modify — `reader/pubspec.yaml` (root workspace).
**Interfaces:** Produces: `EncartaReaderApp` widget (placeholder MaterialApp for now), the macOS-enabled package, path deps on the three packages.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/app_scaffold_test.dart`
```dart
import 'package:encarta_reader/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EncartaReaderApp builds a MaterialApp', (tester) async {
    await tester.pumpWidget(const EncartaReaderApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/app_scaffold_test.dart`. Expected FAIL: package `encarta_reader` / `src/app.dart` does not exist yet.

- [ ] **Step 3: Write minimal implementation**
  1. Scaffold the package: `flutter create --platforms=macos --org com.strata --project-name encarta_reader app/encarta_reader` (run from `reader/`). Delete the generated `app/encarta_reader/lib/main.dart` and `app/encarta_reader/test/widget_test.dart` (replaced in later tasks).
  2. Overwrite `app/encarta_reader/pubspec.yaml`:
```yaml
name: encarta_reader
description: Faithful-in-spirit reader for the recovered Encarta 2009 corpus.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.12.0
  flutter: ^3.42.0

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  encarta_data:
    path: ../../packages/encarta_data
  encarta_render:
    path: ../../packages/encarta_render
  encarta_assets:
    path: ../../packages/encarta_assets
  auto_route: ^9.2.2
  media_kit: ^1.1.11

dev_dependencies:
  flutter_test:
    sdk: flutter
  auto_route_generator: ^9.0.0
  build_runner: ^2.4.13
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
```
  3. Ensure the repo-root workspace declares the app. If `reader/pubspec.yaml` does not exist (Unit 1 may have created it), create it:
```yaml
name: encarta_reader_workspace
publish_to: none
environment:
  sdk: ^3.12.0
workspace:
  - packages/encarta_data
  - packages/encarta_render
  - packages/encarta_assets
  - app/encarta_reader
```
  If it already exists, verify `app/encarta_reader` is listed under `workspace:` and add it if missing.
  4. Create `app/encarta_reader/lib/src/app.dart`:
```dart
import 'package:flutter/material.dart';

/// Placeholder root app. Replaced by the router-wired version in Task 22.
class EncartaReaderApp extends StatelessWidget {
  const EncartaReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Encarta Reader'))),
    );
  }
}
```
  5. `cd reader && flutter pub get` (resolves the workspace lockfile).

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/app_scaffold_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader pubspec.yaml && git commit -m "feat(app): scaffold encarta_reader macOS Flutter app + workspace member"`

---

## Task 2: Data-dir configuration (`AppConfig.resolve`)

**Files:** Create — `app/encarta_reader/lib/src/config/app_config.dart`, `app/encarta_reader/test/config/app_config_test.dart`.
**Interfaces:** Produces: `AppConfig{ String dataDir; String get dbPath; }`, `AppConfig.resolve({List<String> args, Map<String,String> env, String? setting})`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/config/app_config_test.dart`
```dart
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = '/Users/nexus/projects/experiments/strata/quarry/build';

  test('defaults to the quarry build dir', () {
    final c = AppConfig.resolve(args: const [], env: const {});
    expect(c.dataDir, fallback);
    expect(c.dbPath, '$fallback/encarta.sqlite');
  });

  test('--data-dir arg wins over env and default', () {
    final c = AppConfig.resolve(
      args: const ['--data-dir=/data/A'],
      env: const {'ENCARTA_DATA_DIR': '/data/B'},
      setting: '/data/C',
    );
    expect(c.dataDir, '/data/A');
  });

  test('env wins over setting and default', () {
    final c = AppConfig.resolve(
      args: const [],
      env: const {'ENCARTA_DATA_DIR': '/data/B'},
      setting: '/data/C',
    );
    expect(c.dataDir, '/data/B');
  });

  test('persisted setting wins over default', () {
    final c = AppConfig.resolve(args: const [], env: const {}, setting: '/data/C');
    expect(c.dataDir, '/data/C');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/config/app_config_test.dart`. Expected FAIL: `app_config.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/config/app_config.dart`
```dart
/// Immutable resolved configuration. Data dir is configuration, never hard-wired.
class AppConfig {
  final String dataDir;
  const AppConfig(this.dataDir);

  /// Path to the read-only SQLite DB inside the data dir.
  String get dbPath => '$dataDir/encarta.sqlite';

  static const defaultDataDir =
      '/Users/nexus/projects/experiments/strata/quarry/build';

  /// Resolution order: --data-dir arg > ENCARTA_DATA_DIR env > persisted setting > default.
  static AppConfig resolve({
    required List<String> args,
    required Map<String, String> env,
    String? setting,
  }) {
    for (final a in args) {
      if (a.startsWith('--data-dir=')) {
        return AppConfig(a.substring('--data-dir='.length));
      }
    }
    final fromEnv = env['ENCARTA_DATA_DIR'];
    if (fromEnv != null && fromEnv.isNotEmpty) return AppConfig(fromEnv);
    if (setting != null && setting.isNotEmpty) return AppConfig(setting);
    return const AppConfig(defaultDataDir);
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/config/app_config_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/config app/encarta_reader/test/config && git commit -m "feat(app): AppConfig data-dir resolution (arg/env/setting/default)"`

---

## Task 3: History controller (Encarta Back/Forward)

**Files:** Create — `app/encarta_reader/lib/src/nav/history_controller.dart`, `app/encarta_reader/test/nav/history_controller_test.dart`.
**Interfaces:** Produces: `HistoryController extends ChangeNotifier` with `push(String)`, `String? back()`, `String? forward()`, `String? get current`, `bool get canGoBack`, `bool get canGoForward`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/nav/history_controller_test.dart`
```dart
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push builds a stack; back/forward traverse it', () {
    final h = HistoryController();
    expect(h.current, isNull);
    expect(h.canGoBack, isFalse);

    h.push('/');
    h.push('/article/10');
    h.push('/article/20');
    expect(h.current, '/article/20');
    expect(h.canGoBack, isTrue);
    expect(h.canGoForward, isFalse);

    expect(h.back(), '/article/10');
    expect(h.back(), '/');
    expect(h.canGoBack, isFalse);
    expect(h.forward(), '/article/10');
    expect(h.canGoForward, isTrue);
  });

  test('pushing after going back truncates the forward branch', () {
    final h = HistoryController();
    h.push('/');
    h.push('/article/10');
    h.back();
    h.push('/search?q=cat');
    expect(h.current, '/search?q=cat');
    expect(h.canGoForward, isFalse);
    expect(h.back(), '/');
  });

  test('pushing the current location again is a no-op', () {
    final h = HistoryController();
    h.push('/article/5');
    h.push('/article/5');
    expect(h.canGoBack, isFalse);
  });

  test('back/forward return null at the ends', () {
    final h = HistoryController();
    expect(h.back(), isNull);
    h.push('/');
    expect(h.forward(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/nav/history_controller_test.dart`. Expected FAIL: `history_controller.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/nav/history_controller.dart`
```dart
import 'package:flutter/foundation.dart';

/// Browser-like history of route locations (the Encarta "Back").
class HistoryController extends ChangeNotifier {
  final List<String> _stack = <String>[];
  int _index = -1;

  String? get current => _index >= 0 ? _stack[_index] : null;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index >= 0 && _index < _stack.length - 1;

  void push(String location) {
    if (current == location) return;
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(location);
    _index = _stack.length - 1;
    notifyListeners();
  }

  String? back() {
    if (!canGoBack) return null;
    _index--;
    notifyListeners();
    return current;
  }

  String? forward() {
    if (!canGoForward) return null;
    _index++;
    notifyListeners();
    return current;
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/nav/history_controller_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/nav/history_controller.dart app/encarta_reader/test/nav && git commit -m "feat(app): HistoryController push/back/forward stack"`

---

## Task 4: `AppNavigator` (routes + history in one place)

**Files:** Create — `app/encarta_reader/lib/src/nav/app_navigator.dart`, `app/encarta_reader/test/nav/app_navigator_test.dart`.
**Interfaces:** Consumes: `HistoryController`. Produces: `AppNavigator({ required HistoryController history, required void Function(String location) go })` with `openHome()`, `openSearch(String q)`, `openArticle(int refid, {String? paraId})`, `back()`, `forward()`. Builds the canonical location strings the router consumes.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/nav/app_navigator_test.dart`
```dart
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HistoryController history;
  late List<String> gone;
  late AppNavigator nav;

  setUp(() {
    history = HistoryController();
    gone = <String>[];
    nav = AppNavigator(history: history, go: gone.add);
  });

  test('openArticle builds /article/:refid and records history', () {
    nav.openArticle(42);
    expect(gone.last, '/article/42');
    expect(history.current, '/article/42');
  });

  test('openArticle with paraId adds the anchor query', () {
    nav.openArticle(42, paraId: 'p7');
    expect(gone.last, '/article/42?para=p7');
  });

  test('openSearch encodes the query', () {
    nav.openSearch('black holes');
    expect(gone.last, '/search?q=black%20holes');
  });

  test('back navigates to the previous location without re-pushing', () {
    nav.openHome();
    nav.openArticle(1);
    gone.clear();
    nav.back();
    expect(gone.single, '/');
    expect(history.current, '/');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/nav/app_navigator_test.dart`. Expected FAIL: `app_navigator.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/nav/app_navigator.dart`
```dart
import 'history_controller.dart';

/// Single place that turns intents into route locations AND records history.
class AppNavigator {
  final HistoryController history;
  final void Function(String location) go;
  const AppNavigator({required this.history, required this.go});

  void _navigate(String location) {
    history.push(location);
    go(location);
  }

  void openHome() => _navigate('/');

  void openSearch(String q) => _navigate('/search?q=${Uri.encodeComponent(q)}');

  void openArticle(int refid, {String? paraId}) {
    final anchor = (paraId != null && paraId.isNotEmpty)
        ? '?para=${Uri.encodeComponent(paraId)}'
        : '';
    _navigate('/article/$refid$anchor');
  }

  void back() {
    final loc = history.back();
    if (loc != null) go(loc);
  }

  void forward() {
    final loc = history.forward();
    if (loc != null) go(loc);
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/nav/app_navigator_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/nav/app_navigator.dart app/encarta_reader/test/nav/app_navigator_test.dart && git commit -m "feat(app): AppNavigator unifies routing + history"`

---

## Task 5: `ArticleTitleCache` (sync `TitleForRefid`)

**Files:** Create — `app/encarta_reader/lib/src/data/title_cache.dart`, `app/encarta_reader/test/data/title_cache_test.dart`.
**Interfaces:** Consumes: `XrefTarget{ int targetRefid; String title; }`, `TitleRef{ int refid; String title; }` (encarta_data). Produces: `ArticleTitleCache` with `void seed(int refid, String title)`, `void seedXrefs(List<XrefTarget>)`, `void seedTitles(List<TitleRef>)`, `String? cached(int refid)` (sync), `Future<String?> prime(int refid)`. `cached` is the `TitleForRefid` the renderer calls.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/data/title_cache_test.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached() returns seeded titles synchronously', () {
    final c = ArticleTitleCache(fetch: (_) async => null);
    c.seed(7, 'Photosynthesis');
    expect(c.cached(7), 'Photosynthesis');
    expect(c.cached(8), isNull);
  });

  test('seedXrefs / seedTitles populate the cache', () {
    final c = ArticleTitleCache(fetch: (_) async => null);
    c.seedXrefs(const [XrefTarget(targetRefid: 1, title: 'Atom')]);
    c.seedTitles(const [TitleRef(refid: 2, title: 'Bohr')]);
    expect(c.cached(1), 'Atom');
    expect(c.cached(2), 'Bohr');
  });

  test('prime() fetches once and memoizes', () async {
    var calls = 0;
    final c = ArticleTitleCache(fetch: (refid) async {
      calls++;
      return 'T$refid';
    });
    expect(await c.prime(9), 'T9');
    expect(await c.prime(9), 'T9');
    expect(calls, 1);
    expect(c.cached(9), 'T9');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/data/title_cache_test.dart`. Expected FAIL: `title_cache.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/data/title_cache.dart`
```dart
import 'package:encarta_data/encarta_data.dart';

/// Synchronous title lookup backing `TitleForRefid`. Seeded eagerly from data the
/// app already has (xref targets, title index, search hits) and lazily via [prime].
class ArticleTitleCache {
  final Future<String?> Function(int refid) fetch;
  final Map<int, String> _cache = <int, String>{};
  ArticleTitleCache({required this.fetch});

  String? cached(int refid) => _cache[refid];

  void seed(int refid, String title) => _cache[refid] = title;

  void seedXrefs(List<XrefTarget> xrefs) {
    for (final x in xrefs) {
      _cache[x.targetRefid] = x.title;
    }
  }

  void seedTitles(List<TitleRef> titles) {
    for (final t in titles) {
      _cache[t.refid] = t.title;
    }
  }

  Future<String?> prime(int refid) async {
    final hit = _cache[refid];
    if (hit != null) return hit;
    final fetched = await fetch(refid);
    if (fetched != null) _cache[refid] = fetched;
    return fetched;
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/data/title_cache_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/data/title_cache.dart app/encarta_reader/test/data/title_cache_test.dart && git commit -m "feat(app): ArticleTitleCache for synchronous TitleForRefid"`

---

## Task 6: Search snippet generator (`makeSnippet`)

**Files:** Create — `app/encarta_reader/lib/src/data/snippet.dart`, `app/encarta_reader/test/data/snippet_test.dart`.
**Interfaces:** Produces: `String makeSnippet(Uint8List xmlBytes, String query, {int radius = 120})`. FTS is contentless (§4) so snippets are generated by us from `article.xml`: strip tags, find the first query hit, window around it. No extra deps (regex strip).

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/data/snippet_test.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_reader/src/data/snippet.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List xml(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('strips tags and windows around the first query hit', () {
    final body = xml(
      '<content><text><pkey>The <i>quantum</i> theory of '
      'photosynthesis is complex.</pkey></text></content>',
    );
    final s = makeSnippet(body, 'photosynthesis', radius: 20);
    expect(s, contains('photosynthesis'));
    expect(s, isNot(contains('<')));
    expect(s, contains('…'));
  });

  test('falls back to the leading text when query is absent', () {
    final body = xml('<content><text><pkey>Alpha beta gamma.</pkey></text></content>');
    final s = makeSnippet(body, 'zzz', radius: 100);
    expect(s, startsWith('Alpha beta gamma'));
  });

  test('collapses whitespace and is case-insensitive', () {
    final body = xml('<pkey>Big   Bang\n\ncosmology</pkey>');
    final s = makeSnippet(body, 'bang', radius: 10);
    expect(s, contains('Bang'));
    expect(s, isNot(contains('\n')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/data/snippet_test.dart`. Expected FAIL: `snippet.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/data/snippet.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

final _tag = RegExp(r'<[^>]*>');
final _ws = RegExp(r'\s+');

/// Builds a plain-text snippet from article XML around the first hit of [query].
/// FTS5 is contentless, so snippets are produced here, not by the DB.
String makeSnippet(Uint8List xmlBytes, String query, {int radius = 120}) {
  final raw = utf8.decode(xmlBytes, allowMalformed: true);
  final text = raw.replaceAll(_tag, ' ').replaceAll(_ws, ' ').trim();
  if (text.isEmpty) return '';

  final q = query.trim().toLowerCase();
  final hit = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
  if (hit < 0) {
    final end = text.length <= radius * 2 ? text.length : radius * 2;
    final lead = text.substring(0, end);
    return end < text.length ? '$lead…' : lead;
  }

  var start = hit - radius;
  var end = hit + q.length + radius;
  final prefix = start > 0 ? '…' : '';
  final suffix = end < text.length ? '…' : '';
  if (start < 0) start = 0;
  if (end > text.length) end = text.length;
  return '$prefix${text.substring(start, end).trim()}$suffix';
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/data/snippet_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/data/snippet.dart app/encarta_reader/test/data/snippet_test.dart && git commit -m "feat(app): generate search snippets from article XML"`

---

## Task 7: Tier badge mapping (`tierBadge`)

**Files:** Create — `app/encarta_reader/lib/src/data/tier.dart`, `app/encarta_reader/test/data/tier_test.dart`.
**Interfaces:** Consumes: `Article.source` strings (CONTDLX/CONTSTD/CONTSTC/CONTKDC). Produces: `String tierBadge(String source)` → human label for the result-tile badge.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/data/tier_test.dart`
```dart
import 'package:encarta_reader/src/data/tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps CONT* tiers to labels', () {
    expect(tierBadge('CONTDLX'), 'Deluxe');
    expect(tierBadge('CONTSTD'), 'Standard');
    expect(tierBadge('CONTSTC'), 'Concise');
    expect(tierBadge('CONTKDC'), 'Kids');
  });

  test('unknown source falls back to the raw value', () {
    expect(tierBadge('WHATEVER'), 'WHATEVER');
    expect(tierBadge(''), '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/data/tier_test.dart`. Expected FAIL: `tier.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/data/tier.dart`
```dart
/// Maps an article's `source` tier to a short badge label.
String tierBadge(String source) {
  switch (source) {
    case 'CONTDLX':
      return 'Deluxe';
    case 'CONTSTD':
      return 'Standard';
    case 'CONTSTC':
      return 'Concise';
    case 'CONTKDC':
      return 'Kids';
    default:
      return source;
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/data/tier_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/data/tier.dart app/encarta_reader/test/data/tier_test.dart && git commit -m "feat(app): tier badge labels from article source"`

---

## Task 8: Title degradation (`resolveDisplayTitle`)

**Files:** Create — `app/encarta_reader/lib/src/data/degradation.dart`, `app/encarta_reader/test/data/degradation_test.dart`.
**Interfaces:** Consumes: `EncartaOutline{ List<OutlineEntry> entries }`, `OutlineEntry{ String title; ... }` (encarta_render). Produces: `String resolveDisplayTitle({required int refid, required String dbTitle, required EncartaOutline outline})` — §10 fallback: title → first outline entry title → refid string.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/data/degradation_test.dart`
```dart
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/data/degradation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the DB title when present', () {
    final t = resolveDisplayTitle(
      refid: 5,
      dbTitle: 'Photosynthesis',
      outline: const EncartaOutline(entries: []),
    );
    expect(t, 'Photosynthesis');
  });

  test('falls back to the first outline entry title', () {
    final t = resolveDisplayTitle(
      refid: 5,
      dbTitle: '',
      outline: const EncartaOutline(
        entries: [OutlineEntry(title: 'Overview', anchorId: 'a1', depth: 0)],
      ),
    );
    expect(t, 'Overview');
  });

  test('falls back to the refid string when nothing else exists', () {
    final t = resolveDisplayTitle(
      refid: 99,
      dbTitle: '',
      outline: const EncartaOutline(entries: []),
    );
    expect(t, 'Article 99');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/data/degradation_test.dart`. Expected FAIL: `degradation.dart` missing. (If `EncartaOutline`/`OutlineEntry` const constructors differ from Unit 2's shipped API, adjust the fixture to match — they are locked in the contract as shown.)

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/data/degradation.dart`
```dart
import 'package:encarta_render/encarta_render.dart';

/// §10 title degradation: DB title → first outline entry title → "Article <refid>".
String resolveDisplayTitle({
  required int refid,
  required String dbTitle,
  required EncartaOutline outline,
}) {
  if (dbTitle.trim().isNotEmpty) return dbTitle;
  for (final e in outline.entries) {
    if (e.title.trim().isNotEmpty) return e.title;
  }
  return 'Article $refid';
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/data/degradation_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/data/degradation.dart app/encarta_reader/test/data/degradation_test.dart && git commit -m "feat(app): resolveDisplayTitle degradation chain"`

---

## Task 9: `auto_route` router + page skeletons + codegen

**Files:** Create — `app/encarta_reader/lib/src/nav/app_router.dart`, page skeletons `lib/src/screens/home/home_page.dart`, `lib/src/screens/search/search_page.dart`, `lib/src/screens/article/article_page.dart`; Generated — `lib/src/nav/app_router.gr.dart`; Test — `app/encarta_reader/test/nav/app_router_test.dart`.
**Interfaces:** Produces: `AppRouter extends RootStackRouter` with routes `/` (`HomeRoute`), `/search` (`SearchRoute`, `@QueryParam q`), `/article/:refid` (`ArticleRoute`, `@PathParam refid`, `@QueryParam('para') paraId`). Pages are `@RoutePage()` skeletons (full bodies filled in Tasks 19/17/14).

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/nav/app_router_test.dart`
```dart
import 'package:encarta_reader/src/nav/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router exposes the three Encarta routes with correct paths', () {
    final router = AppRouter();
    final paths = router.routes.map((r) => r.path).toSet();
    expect(paths, containsAll(<String>['/', '/search', '/article/:refid']));
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/nav/app_router_test.dart`. Expected FAIL: `app_router.dart` and `*.gr.dart` do not exist.

- [ ] **Step 3: Write minimal implementation**
  1. Page skeletons. `lib/src/screens/home/home_page.dart`:
```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Home')));
}
```
  `lib/src/screens/search/search_page.dart`:
```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SearchPage extends StatelessWidget {
  const SearchPage({super.key, @QueryParam('q') this.q = ''});
  final String q;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Search: $q')));
}
```
  `lib/src/screens/article/article_page.dart`:
```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ArticlePage extends StatelessWidget {
  const ArticlePage({
    super.key,
    @PathParam('refid') required this.refid,
    @QueryParam('para') this.paraId,
  });
  final int refid;
  final String? paraId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Article $refid')));
}
```
  2. `lib/src/nav/app_router.dart`:
```dart
import 'package:auto_route/auto_route.dart';

import '../screens/article/article_page.dart';
import '../screens/home/home_page.dart';
import '../screens/search/search_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, path: '/', initial: true),
        AutoRoute(page: SearchRoute.page, path: '/search'),
        AutoRoute(page: ArticleRoute.page, path: '/article/:refid'),
      ];
}
```
  3. Generate: `cd app/encarta_reader && dart run build_runner build --delete-conflicting-outputs`. Confirm `lib/src/nav/app_router.gr.dart` is created with `HomeRoute`, `SearchRoute`, `ArticleRoute`.

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/nav/app_router_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/nav/app_router.dart app/encarta_reader/lib/src/nav/app_router.gr.dart app/encarta_reader/lib/src/screens app/encarta_reader/test/nav/app_router_test.dart && git commit -m "feat(app): auto_route router + page skeletons (codegen)"`

---

## Task 10: `AppScope` InheritedWidget (dependency carrier)

**Files:** Create — `app/encarta_reader/lib/src/widgets/app_scope.dart`, `app/encarta_reader/test/widgets/app_scope_test.dart`.
**Interfaces:** Consumes: `EncartaDb`, `EncartaAssets`, `EncartaTheme`. Produces: `AppScope` InheritedWidget exposing `db`, `assets`, `theme`, `navigator` (`AppNavigator`), `titles` (`ArticleTitleCache`); `AppScope.of(context)`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/widgets/app_scope_test.dart`
```dart
import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:encarta_reader/src/widgets/app_scope.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppScope.of exposes injected dependencies', (tester) async {
    final theme = EncartaTheme.faithfulInSpirit();
    final titles = ArticleTitleCache(fetch: (_) async => null);
    final nav = AppNavigator(history: HistoryController(), go: (_) {});
    AppScope? captured;

    await tester.pumpWidget(
      AppScope(
        db: null,
        assets: null,
        theme: theme,
        navigator: nav,
        titles: titles,
        child: Builder(
          builder: (context) {
            captured = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(captured, isNotNull);
    expect(identical(captured!.theme, theme), isTrue);
    expect(identical(captured!.titles, titles), isTrue);
  });
}
```
(`db`/`assets` are typed nullable only to keep this widget test DB-free; production always supplies them — see Task 22.)

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/widgets/app_scope_test.dart`. Expected FAIL: `app_scope.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/widgets/app_scope.dart`
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/widgets.dart';

import '../data/title_cache.dart';
import '../nav/app_navigator.dart';

/// Carries app-wide singletons to every screen.
class AppScope extends InheritedWidget {
  final EncartaDb? db;
  final EncartaAssets? assets;
  final EncartaTheme theme;
  final AppNavigator navigator;
  final ArticleTitleCache titles;

  const AppScope({
    super.key,
    required this.db,
    required this.assets,
    required this.theme,
    required this.navigator,
    required this.titles,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      db != oldWidget.db ||
      assets != oldWidget.assets ||
      theme != oldWidget.theme ||
      navigator != oldWidget.navigator ||
      titles != oldWidget.titles;
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/widgets/app_scope_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/widgets/app_scope.dart app/encarta_reader/test/widgets/app_scope_test.dart && git commit -m "feat(app): AppScope dependency carrier"`

---

## Task 11: `EncartaToolbar` (persistent top toolbar)

**Files:** Create — `app/encarta_reader/lib/src/widgets/top_toolbar.dart`, `app/encarta_reader/test/widgets/top_toolbar_test.dart`.
**Interfaces:** Consumes: `EncartaTheme` chrome getters (`chromeColor`, `onChromeColor`, `accentColor`), `HistoryController` (for back/forward enable state), `AppNavigator`. Produces: `EncartaToolbar({ required EncartaTheme theme, required HistoryController history, required AppNavigator navigator, String initialQuery = '' })` — home button + back/forward + search box. Frames all screens.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/widgets/top_toolbar_test.dart`
```dart
import 'package:encarta_reader/src/nav/app_navigator.dart';
import 'package:encarta_reader/src/nav/history_controller.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(HistoryController history, List<String> gone) {
    final nav = AppNavigator(history: history, go: gone.add);
    return MaterialApp(
      home: Scaffold(
        body: EncartaToolbar(
          theme: EncartaTheme.faithfulInSpirit(),
          history: history,
          navigator: nav,
        ),
      ),
    );
  }

  testWidgets('home button navigates to /', (tester) async {
    final gone = <String>[];
    await tester.pumpWidget(host(HistoryController(), gone));
    await tester.tap(find.byKey(const Key('toolbar.home')));
    expect(gone, contains('/'));
  });

  testWidgets('back is disabled with empty history, enabled after two pushes',
      (tester) async {
    final history = HistoryController();
    await tester.pumpWidget(host(history, <String>[]));
    final backFinder = find.byKey(const Key('toolbar.back'));
    expect(tester.widget<IconButton>(backFinder).onPressed, isNull);

    history.push('/');
    history.push('/article/1');
    await tester.pump();
    expect(tester.widget<IconButton>(backFinder).onPressed, isNotNull);
  });

  testWidgets('submitting the search box navigates to /search', (tester) async {
    final gone = <String>[];
    await tester.pumpWidget(host(HistoryController(), gone));
    await tester.enterText(find.byKey(const Key('toolbar.search')), 'mars');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(gone.last, '/search?q=mars');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/widgets/top_toolbar_test.dart`. Expected FAIL: `top_toolbar.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/widgets/top_toolbar.dart`
```dart
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import '../nav/app_navigator.dart';
import '../nav/history_controller.dart';

/// Encarta-era top toolbar: home, back/forward, and a search box. Frames all screens.
class EncartaToolbar extends StatefulWidget {
  final EncartaTheme theme;
  final HistoryController history;
  final AppNavigator navigator;
  final String initialQuery;

  const EncartaToolbar({
    super.key,
    required this.theme,
    required this.history,
    required this.navigator,
    this.initialQuery = '',
  });

  @override
  State<EncartaToolbar> createState() => _EncartaToolbarState();
}

class _EncartaToolbarState extends State<EncartaToolbar> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery);

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
  }

  void _onHistory() => setState(() {});

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isNotEmpty) widget.navigator.openSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Material(
      color: t.chromeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('toolbar.home'),
              color: t.onChromeColor,
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: widget.navigator.openHome,
            ),
            IconButton(
              key: const Key('toolbar.back'),
              color: t.onChromeColor,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: widget.history.canGoBack ? widget.navigator.back : null,
            ),
            IconButton(
              key: const Key('toolbar.forward'),
              color: t.onChromeColor,
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Forward',
              onPressed:
                  widget.history.canGoForward ? widget.navigator.forward : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('toolbar.search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                style: TextStyle(color: t.onChromeColor),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: t.surfaceColor,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search Encarta…',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/widgets/top_toolbar_test.dart`. Expected PASS. (`EncartaTheme` chrome getters `chromeColor`/`onChromeColor`/`accentColor`/`surfaceColor`/`measure` are confirmed locked in `encarta_render`.)

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/widgets/top_toolbar.dart app/encarta_reader/test/widgets/top_toolbar_test.dart && git commit -m "feat(app): EncartaToolbar (home/back/forward/search)"`

---

## Task 12: `ArticleOutlinePane` (In this article + Related)

**Files:** Create — `app/encarta_reader/lib/src/screens/article/article_outline_pane.dart`, `app/encarta_reader/test/screens/article/article_outline_pane_test.dart`.
**Interfaces:** Consumes: `EncartaOutline{ List<OutlineEntry> entries }`, `OutlineEntry{ String title; String anchorId; int depth; }`, `XrefTarget{ int targetRefid; String title; }`. Produces: `ArticleOutlinePane({ required EncartaOutline outline, required List<XrefTarget> related, required void Function(String anchorId) onOutlineTap, required void Function(int refid) onRelatedTap })`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/article/article_outline_pane_test.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/screens/article/article_outline_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders outline + related and fires taps', (tester) async {
    String? tappedAnchor;
    int? tappedRefid;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleOutlinePane(
          outline: const EncartaOutline(entries: [
            OutlineEntry(title: 'History', anchorId: 'a1', depth: 0),
            OutlineEntry(title: 'Theory', anchorId: 'a2', depth: 1),
          ]),
          related: const [XrefTarget(targetRefid: 7, title: 'Newton')],
          onOutlineTap: (a) => tappedAnchor = a,
          onRelatedTap: (r) => tappedRefid = r,
        ),
      ),
    ));

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Newton'), findsOneWidget);

    await tester.tap(find.text('Theory'));
    expect(tappedAnchor, 'a2');
    await tester.tap(find.text('Newton'));
    expect(tappedRefid, 7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/article/article_outline_pane_test.dart`. Expected FAIL: missing widget.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/screens/article/article_outline_pane.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

/// Left pane: "In this article" outline + "Related" outbound xrefs.
class ArticleOutlinePane extends StatelessWidget {
  final EncartaOutline outline;
  final List<XrefTarget> related;
  final void Function(String anchorId) onOutlineTap;
  final void Function(int refid) onRelatedTap;

  const ArticleOutlinePane({
    super.key,
    required this.outline,
    required this.related,
    required this.onOutlineTap,
    required this.onRelatedTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (outline.entries.isNotEmpty) ...[
          const Text('In this article',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in outline.entries)
            Padding(
              padding: EdgeInsets.only(left: 12.0 * e.depth),
              child: InkWell(
                onTap: () => onOutlineTap(e.anchorId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(e.title),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (related.isNotEmpty) ...[
          const Text('Related',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final x in related)
            InkWell(
              onTap: () => onRelatedTap(x.targetRefid),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(x.title,
                    style: const TextStyle(decoration: TextDecoration.underline)),
              ),
            ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/article/article_outline_pane_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/article/article_outline_pane.dart app/encarta_reader/test/screens/article/article_outline_pane_test.dart && git commit -m "feat(app): ArticleOutlinePane (outline + related)"`

---

## Task 13: `MediaRail` (right pane, block-level media)

**Files:** Create — `app/encarta_reader/lib/src/screens/article/media_rail.dart`, `app/encarta_reader/test/screens/article/media_rail_test.dart`.
**Interfaces:** Consumes: `MediaItem{ mediaRefid, role, group, title, caption, credit, assetPath, ext, kind }`, `EncartaImage({ required MediaItem item })`, `EncartaAudio({ required MediaItem item })`, `EncartaVideo({ required MediaItem item })` (encarta_assets). Produces: `MediaRail({ required List<MediaItem> media })` — block-level figures with caption/credit; image/audio/video chosen by `kind`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/article/media_rail_test.dart`
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/article/media_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders an EncartaImage with caption + credit per image item',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MediaRail(media: [
          MediaItem(
            mediaRefid: 1,
            role: 'image',
            group: 'article',
            title: 'Saturn',
            caption: 'The ringed planet',
            credit: 'NASA',
            assetPath: 'image/abc123.jpg',
            ext: 'jpg',
            kind: 'image',
          ),
        ]),
      ),
    ));

    expect(find.byType(EncartaImage), findsOneWidget);
    expect(find.text('The ringed planet'), findsOneWidget);
    expect(find.text('NASA'), findsOneWidget);
  });

  testWidgets('empty media list renders nothing tall', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MediaRail(media: [])),
    ));
    expect(find.byType(EncartaImage), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/article/media_rail_test.dart`. Expected FAIL: missing widget.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/screens/article/media_rail.dart`
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

/// Right pane: block-level media figures (image/audio/video) with caption + credit.
class MediaRail extends StatelessWidget {
  final List<MediaItem> media;
  const MediaRail({super.key, required this.media});

  Widget _figure(MediaItem item) {
    switch (item.kind) {
      case 'audio':
      case 'midi':
        return EncartaAudio(item: item);
      case 'other':
        // WMV video lives under kind='other'; treat video exts as video.
        final ext = item.ext.toLowerCase();
        if (ext == 'wmv' || ext == 'mp4' || ext == 'avi') {
          return EncartaVideo(item: item);
        }
        return EncartaImage(item: item);
      default:
        return EncartaImage(item: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: media.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final item = media[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _figure(item),
            if ((item.caption ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.caption!,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            if ((item.credit ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.credit!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/article/media_rail_test.dart`. Expected PASS. (If `EncartaImage`/`EncartaAudio`/`EncartaVideo` render their own caption/credit, drop the rail's caption/credit text to avoid duplication — coordinate with Unit 3.)

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/article/media_rail.dart app/encarta_reader/test/screens/article/media_rail_test.dart && git commit -m "feat(app): MediaRail block-level media with caption/credit"`

---

## Task 14: `ArticleView` (three-pane assembly + callback wiring)

**Files:** Create — `app/encarta_reader/lib/src/screens/article/article_view.dart`, `app/encarta_reader/test/screens/article/article_view_test.dart`.
**Interfaces:** Consumes: `EncartaDoc`, `EncartaArticleBody({ required EncartaDoc doc, required EncartaTheme theme, required AssetResolver assetResolver, required XrefTap onXrefTap, required TitleForRefid titleForRefid, ScrollController? controller })`, typedefs `AssetResolver = Widget Function(String inlineId, int inlineType)`, `XrefTap = void Function(int targetRefid, {String? paraId})`, `TitleForRefid = String? Function(int refid)`. Produces: `ArticleViewData{ EncartaDoc doc; EncartaOutline outline; String title; String source; List<XrefTarget> related; List<MediaItem> media; }`, `ArticleView({ required ArticleViewData data, required EncartaTheme theme, required AssetResolver assetResolver, required XrefTap onXrefTap, required TitleForRefid titleForRefid, required void Function(int refid) onRelatedTap })`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/article/article_view_test.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/screens/article/article_view.dart';
import 'package:encarta_reader/src/screens/article/article_outline_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EncartaDoc _doc() => EncartaDoc.parse(
      Uint8List.fromList(utf8.encode(
        '<content><text><pkey>Hello world.</pkey></text></content>',
      )),
      title: 'Test',
    );

void main() {
  testWidgets('renders three panes with the article body in the center',
      (tester) async {
    final data = ArticleViewData(
      doc: _doc(),
      outline: const EncartaOutline(entries: [
        OutlineEntry(title: 'Intro', anchorId: 'a1', depth: 0),
      ]),
      title: 'Test',
      source: 'CONTDLX',
      related: const [],
      media: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleView(
          data: data,
          theme: EncartaTheme.faithfulInSpirit(),
          assetResolver: (id, type) => const Icon(Icons.image),
          onXrefTap: (refid, {paraId}) {},
          titleForRefid: (_) => null,
          onRelatedTap: (_) {},
        ),
      ),
    ));

    expect(find.byType(ArticleOutlinePane), findsOneWidget);
    expect(find.byType(EncartaArticleBody), findsOneWidget);
    expect(find.text('Test'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/article/article_view_test.dart`. Expected FAIL: missing widget.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/screens/article/article_view.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import 'article_outline_pane.dart';
import 'media_rail.dart';

/// Immutable bundle for one rendered article (assembled by buildArticleViewData).
class ArticleViewData {
  final EncartaDoc doc;
  final EncartaOutline outline;
  final String title;
  final String source;
  final List<XrefTarget> related;
  final List<MediaItem> media;

  const ArticleViewData({
    required this.doc,
    required this.outline,
    required this.title,
    required this.source,
    required this.related,
    required this.media,
  });
}

/// Center-of-gravity Article screen: three panes (outline+related | body | media).
class ArticleView extends StatelessWidget {
  final ArticleViewData data;
  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final void Function(int refid) onRelatedTap;

  const ArticleView({
    super.key,
    required this.data,
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    required this.onRelatedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: ArticleOutlinePane(
            outline: data.outline,
            related: data.related,
            onOutlineTap: (_) {}, // scroll-to-anchor wired in Task 15 page loader
            onRelatedTap: onRelatedTap,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Expanded(
                  child: EncartaArticleBody(
                    doc: data.doc,
                    theme: theme,
                    assetResolver: assetResolver,
                    onXrefTap: onXrefTap,
                    titleForRefid: titleForRefid,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data.media.isNotEmpty) ...[
          const VerticalDivider(width: 1),
          SizedBox(width: 300, child: MediaRail(media: data.media)),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/article/article_view_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/article/article_view.dart app/encarta_reader/test/screens/article/article_view_test.dart && git commit -m "feat(app): ArticleView three-pane layout + render callbacks"`

---

## Task 15: `buildArticleViewData` + `ArticlePage` loader

**Files:** Modify — `app/encarta_reader/lib/src/screens/article/article_page.dart`; Create — `app/encarta_reader/test/screens/article/build_article_view_data_test.dart`.
**Interfaces:** Consumes: `EncartaDb.getArticle(int) → Article?`, `EncartaDb.mediaForArticle(int) → List<MediaItem>`, `EncartaDb.outboundXrefs(int) → List<XrefTarget>`, `EncartaDoc.parse(Uint8List, {required String title})`, `EncartaOutline` (from the doc), `resolveDisplayTitle`. Produces: `Future<ArticleViewData?> buildArticleViewData({ required int refid, required Future<Article?> Function(int) getArticle, required Future<List<MediaItem>> Function(int) mediaForArticle, required Future<List<XrefTarget>> Function(int) outboundXrefs, required ArticleTitleCache titles })`. Wires title degradation + seeds the title cache from related xrefs.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/article/build_article_view_data_test.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:encarta_reader/src/screens/article/article_page.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _xml() => Uint8List.fromList(utf8.encode(
      '<content><text><pkey>Body text.</pkey></text></content>',
    ));

void main() {
  test('assembles data, applies title fallback, seeds title cache', () async {
    final titles = ArticleTitleCache(fetch: (_) async => null);

    final data = await buildArticleViewData(
      refid: 3,
      getArticle: (id) async =>
          Article(refid: id, title: '', source: 'CONTSTD', xmlBytes: _xml()),
      mediaForArticle: (_) async => const [],
      outboundXrefs: (_) async =>
          const [XrefTarget(targetRefid: 9, title: 'Gravity')],
      titles: titles,
    );

    expect(data, isNotNull);
    expect(data!.related.single.title, 'Gravity');
    expect(titles.cached(9), 'Gravity'); // seeded for titleForRefid
    expect(data.title, 'Article 3'); // empty DB title → refid fallback
  });

  test('returns null when the article is absent', () async {
    final titles = ArticleTitleCache(fetch: (_) async => null);
    final data = await buildArticleViewData(
      refid: 404,
      getArticle: (_) async => null,
      mediaForArticle: (_) async => const [],
      outboundXrefs: (_) async => const [],
      titles: titles,
    );
    expect(data, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/article/build_article_view_data_test.dart`. Expected FAIL: `buildArticleViewData` undefined.

- [ ] **Step 3: Write minimal implementation** — replace `app/encarta_reader/lib/src/screens/article/article_page.dart`
```dart
import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import '../../data/degradation.dart';
import '../../data/title_cache.dart';
import '../../widgets/app_scope.dart';
import 'article_view.dart';

/// Pure assembly: DB rows + parsed doc → ArticleViewData. Testable without Flutter.
Future<ArticleViewData?> buildArticleViewData({
  required int refid,
  required Future<Article?> Function(int) getArticle,
  required Future<List<MediaItem>> Function(int) mediaForArticle,
  required Future<List<XrefTarget>> Function(int) outboundXrefs,
  required ArticleTitleCache titles,
}) async {
  final article = await getArticle(refid);
  if (article == null) return null;

  final doc = EncartaDoc.parse(article.xmlBytes, title: article.title);
  final outline = doc.outline;
  final media = await mediaForArticle(refid);
  final related = await outboundXrefs(refid);

  titles.seed(refid, article.title);
  titles.seedXrefs(related);

  final title = resolveDisplayTitle(
    refid: refid,
    dbTitle: article.title,
    outline: outline,
  );

  return ArticleViewData(
    doc: doc,
    outline: outline,
    title: title,
    source: article.source,
    related: related,
    media: media,
  );
}

@RoutePage()
class ArticlePage extends StatefulWidget {
  const ArticlePage({
    super.key,
    @PathParam('refid') required this.refid,
    @QueryParam('para') this.paraId,
  });
  final int refid;
  final String? paraId;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  late Future<ArticleViewData?> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final db = scope.db!;
    _future = buildArticleViewData(
      refid: widget.refid,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
      outboundXrefs: db.outboundXrefs,
      titles: scope.titles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<ArticleViewData?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (data == null) {
          return Center(child: Text('Article ${widget.refid} not found.'));
        }
        return ArticleView(
          data: data,
          theme: scope.theme,
          assetResolver: (id, type) => scope.assets!.inlineBmp(id, type),
          onXrefTap: (refid, {paraId}) =>
              scope.navigator.openArticle(refid, paraId: paraId),
          titleForRefid: scope.titles.cached,
          onRelatedTap: (refid) => scope.navigator.openArticle(refid),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/article/build_article_view_data_test.dart`. Then regenerate routes (page signature unchanged, but safe): `cd app/encarta_reader && dart run build_runner build --delete-conflicting-outputs`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/article app/encarta_reader/test/screens/article/build_article_view_data_test.dart && git commit -m "feat(app): buildArticleViewData + ArticlePage loader with degradation"`

---

## Task 16: `SearchResultTile`

**Files:** Create — `app/encarta_reader/lib/src/screens/search/search_view.dart` (data classes only here), `app/encarta_reader/lib/src/screens/search/search_result_tile.dart`, `app/encarta_reader/test/screens/search/search_result_tile_test.dart`.
**Interfaces:** Consumes: `MediaItem` (thumbnail), `EncartaImage`. Produces: `SearchResultItem{ int refid; String title; String snippet; String tierBadge; MediaItem? thumb; bool selected; }`, `SearchResultTile({ required SearchResultItem item, required VoidCallback onTap })` — thumbnail · title · snippet · tier badge.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/search/search_result_tile_test.dart`
```dart
import 'package:encarta_reader/src/screens/search/search_result_tile.dart';
import 'package:encarta_reader/src/screens/search/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows title, snippet, tier badge and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchResultTile(
          item: const SearchResultItem(
            refid: 1,
            title: 'Black hole',
            snippet: '…a region of spacetime…',
            tierBadge: 'Deluxe',
            thumb: null,
          ),
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Black hole'), findsOneWidget);
    expect(find.text('…a region of spacetime…'), findsOneWidget);
    expect(find.text('Deluxe'), findsOneWidget);

    await tester.tap(find.byType(SearchResultTile));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/search/search_result_tile_test.dart`. Expected FAIL: missing files.

- [ ] **Step 3: Write minimal implementation**
  `app/encarta_reader/lib/src/screens/search/search_view.dart` (data classes; the `SearchView` widget is added in Task 17):
```dart
import 'package:encarta_data/encarta_data.dart';

/// One ranked search result row (title from FTS, snippet generated by us).
class SearchResultItem {
  final int refid;
  final String title;
  final String snippet;
  final String tierBadge;
  final MediaItem? thumb;
  final bool selected;

  const SearchResultItem({
    required this.refid,
    required this.title,
    required this.snippet,
    required this.tierBadge,
    required this.thumb,
    this.selected = false,
  });

  SearchResultItem copyWith({bool? selected}) => SearchResultItem(
        refid: refid,
        title: title,
        snippet: snippet,
        tierBadge: tierBadge,
        thumb: thumb,
        selected: selected ?? this.selected,
      );
}

/// Immutable bundle for the search screen.
class SearchViewData {
  final String query;
  final List<SearchResultItem> results;
  final int offset;
  final bool hasMore;

  const SearchViewData({
    required this.query,
    required this.results,
    required this.offset,
    required this.hasMore,
  });
}
```
  `app/encarta_reader/lib/src/screens/search/search_result_tile.dart`:
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

import 'search_view.dart';

/// Left-column result row: thumbnail · title · snippet · tier badge.
class SearchResultTile extends StatelessWidget {
  final SearchResultItem item;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.selected ? Theme.of(context).highlightColor : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: item.thumb == null
                  ? const Icon(Icons.article_outlined, size: 40)
                  : EncartaImage(item: item.thumb!),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.tierBadge,
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/search/search_result_tile_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/search/search_view.dart app/encarta_reader/lib/src/screens/search/search_result_tile.dart app/encarta_reader/test/screens/search/search_result_tile_test.dart && git commit -m "feat(app): SearchResultItem + SearchResultTile"`

---

## Task 17: `SearchView` (results + live preview) + `buildSearchViewData` + `SearchPage`

**Files:** Modify — `app/encarta_reader/lib/src/screens/search/search_view.dart` (add `SearchView` widget), `app/encarta_reader/lib/src/screens/search/search_page.dart`; Create — `app/encarta_reader/test/screens/search/search_view_test.dart`, `app/encarta_reader/test/screens/search/build_search_view_data_test.dart`.
**Interfaces:** Consumes: `EncartaDb.search(String, {int limit, int offset}) → List<SearchHit>`, `EncartaDb.getArticle`, `EncartaDb.mediaForArticle`, `makeSnippet`, `tierBadge`, plus an `ArticleViewData` builder for the preview (reuse Task 15). Produces: `SearchView({ required SearchViewData data, required void Function(int refid) onSelect, required ArticleViewData? preview, ... })` (left results + right live preview reusing `EncartaArticleBody`), and `Future<SearchViewData> buildSearchViewData({...})` (ranked, paginated, with our snippet + thumb role pick + tier badge).

- [ ] **Step 1: Write the failing tests**
  `app/encarta_reader/test/screens/search/build_search_view_data_test.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/search/search_page.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _xml(String s) => Uint8List.fromList(utf8.encode('<pkey>$s</pkey>'));

void main() {
  test('builds ranked results with our snippet, tier badge and thumb', () async {
    final data = await buildSearchViewData(
      query: 'mars',
      offset: 0,
      limit: 25,
      search: (q, {limit = 25, offset = 0}) async =>
          const [SearchHit(refid: 1, title: 'Mars', rank: -2.1)],
      getArticle: (id) async => Article(
        refid: id,
        title: 'Mars',
        source: 'CONTDLX',
        xmlBytes: _xml('Mars is the fourth planet.'),
      ),
      mediaForArticle: (_) async => const [
        MediaItem(
          mediaRefid: 9,
          role: 'thumb',
          group: 'article',
          title: null,
          caption: null,
          credit: null,
          assetPath: 'image/x.jpg',
          ext: 'jpg',
          kind: 'image',
        ),
      ],
    );

    expect(data.results.single.title, 'Mars');
    expect(data.results.single.tierBadge, 'Deluxe');
    expect(data.results.single.snippet, contains('Mars'));
    expect(data.results.single.thumb!.role, 'thumb');
    expect(data.hasMore, isFalse);
  });

  test('hasMore is true when a full page is returned', () async {
    final hits = List.generate(
        25, (i) => SearchHit(refid: i, title: 'T$i', rank: -i.toDouble()));
    final data = await buildSearchViewData(
      query: 'x',
      offset: 0,
      limit: 25,
      search: (q, {limit = 25, offset = 0}) async => hits,
      getArticle: (id) async =>
          Article(refid: id, title: 'T$id', source: 'CONTSTD', xmlBytes: _xml('x')),
      mediaForArticle: (_) async => const [],
    );
    expect(data.hasMore, isTrue);
  });
}
```
  `app/encarta_reader/test/screens/search/search_view_test.dart`
```dart
import 'package:encarta_reader/src/screens/search/search_result_tile.dart';
import 'package:encarta_reader/src/screens/search/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows results column and a preview placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchView(
          data: const SearchViewData(
            query: 'mars',
            results: [
              SearchResultItem(
                refid: 1,
                title: 'Mars',
                snippet: 'fourth planet',
                tierBadge: 'Deluxe',
                thumb: null,
              ),
            ],
            offset: 0,
            hasMore: false,
          ),
          preview: null,
          onSelect: (_) {},
          onNextPage: null,
        ),
      ),
    ));

    expect(find.byType(SearchResultTile), findsOneWidget);
    expect(find.text('Select a result to preview'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail** — `cd app/encarta_reader && flutter test test/screens/search/build_search_view_data_test.dart test/screens/search/search_view_test.dart`. Expected FAIL: `buildSearchViewData` / `SearchView` undefined.

- [ ] **Step 3: Write minimal implementation**
  Append `SearchView` to `app/encarta_reader/lib/src/screens/search/search_view.dart`:
```dart
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import '../article/article_view.dart';
import 'search_result_tile.dart';

class SearchView extends StatelessWidget {
  final SearchViewData data;
  final ArticleViewData? preview;
  final EncartaTheme? theme;
  final AssetResolver? assetResolver;
  final XrefTap? onXrefTap;
  final TitleForRefid? titleForRefid;
  final void Function(int refid) onSelect;
  final VoidCallback? onNextPage;

  const SearchView({
    super.key,
    required this.data,
    required this.preview,
    required this.onSelect,
    this.theme,
    this.assetResolver,
    this.onXrefTap,
    this.titleForRefid,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 420,
          child: ListView(
            children: [
              for (final r in data.results)
                SearchResultTile(item: r, onTap: () => onSelect(r.refid)),
              if (data.hasMore && onNextPage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: onNextPage,
                    child: const Text('More results'),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: preview == null || theme == null
              ? const Center(child: Text('Select a result to preview'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: EncartaArticleBody(
                    doc: preview!.doc,
                    theme: theme!,
                    assetResolver: assetResolver ?? (_, __) => const SizedBox(),
                    onXrefTap: onXrefTap ?? (_, {paraId}) {},
                    titleForRefid: titleForRefid ?? (_) => null,
                  ),
                ),
        ),
      ],
    );
  }
}
```
  Replace `app/encarta_reader/lib/src/screens/search/search_page.dart`:
```dart
import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import '../../data/snippet.dart';
import '../../data/tier.dart';
import '../../widgets/app_scope.dart';
import '../article/article_page.dart';
import '../article/article_view.dart';
import 'search_view.dart';

/// Roles tried, in order, for a result thumbnail (validated in Task 23).
const _thumbRoles = ['thumb', 'ticon', 'picon', 'image'];

MediaItem? _pickThumb(List<MediaItem> media) {
  for (final role in _thumbRoles) {
    for (final m in media) {
      if (m.role == role) return m;
    }
  }
  return null;
}

/// Pure assembly of the search screen's left column (ranked + paginated + our snippet).
Future<SearchViewData> buildSearchViewData({
  required String query,
  required int offset,
  required int limit,
  required Future<List<SearchHit>> Function(String,
          {int limit, int offset})
      search,
  required Future<Article?> Function(int) getArticle,
  required Future<List<MediaItem>> Function(int) mediaForArticle,
}) async {
  final hits = await search(query, limit: limit, offset: offset);
  final results = <SearchResultItem>[];
  for (final h in hits) {
    final article = await getArticle(h.refid);
    final snippet = article == null
        ? ''
        : makeSnippet(article.xmlBytes, query);
    final media = await mediaForArticle(h.refid);
    results.add(SearchResultItem(
      refid: h.refid,
      title: h.title,
      snippet: snippet,
      tierBadge: tierBadge(article?.source ?? ''),
      thumb: _pickThumb(media),
    ));
  }
  return SearchViewData(
    query: query,
    results: results,
    offset: offset,
    hasMore: hits.length >= limit,
  );
}

@RoutePage()
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, @QueryParam('q') this.q = ''});
  final String q;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _limit = 25;
  Future<SearchViewData>? _future;
  ArticleViewData? _preview;
  int _selected = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db!;
    _future = buildSearchViewData(
      query: widget.q,
      offset: 0,
      limit: _limit,
      search: db.search,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
    );
  }

  Future<void> _select(int refid) async {
    final scope = AppScope.of(context);
    final db = scope.db!;
    final data = await buildArticleViewData(
      refid: refid,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
      outboundXrefs: db.outboundXrefs,
      titles: scope.titles,
    );
    if (!mounted) return;
    setState(() {
      _selected = refid;
      _preview = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<SearchViewData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final base = snap.data!;
        final marked = SearchViewData(
          query: base.query,
          offset: base.offset,
          hasMore: base.hasMore,
          results: [
            for (final r in base.results)
              r.copyWith(selected: r.refid == _selected),
          ],
        );
        return SearchView(
          data: marked,
          preview: _preview,
          theme: scope.theme,
          assetResolver: (id, type) => scope.assets!.inlineBmp(id, type),
          onXrefTap: (refid, {paraId}) =>
              scope.navigator.openArticle(refid, paraId: paraId),
          titleForRefid: scope.titles.cached,
          onSelect: _select,
          onNextPage: null,
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass** — `cd app/encarta_reader && dart run build_runner build --delete-conflicting-outputs && flutter test test/screens/search/`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/search app/encarta_reader/lib/src/nav/app_router.gr.dart app/encarta_reader/test/screens/search && git commit -m "feat(app): Search screen — ranked results + live preview"`

---

## Task 18: `HomeView` (portal: hero + tiles + A–Z + search + random)

**Files:** Create — `app/encarta_reader/lib/src/screens/home/home_view.dart`, `app/encarta_reader/test/screens/home/home_view_test.dart`.
**Interfaces:** Consumes: `TitleRef{ int refid; String title; }`. Produces: `HomeViewData{ TitleRef? hero; List<TitleRef> tiles; List<String> azLetters; }`, `HomeView({ required HomeViewData data, required void Function(int refid) onOpenArticle, required void Function(String letter) onBrowseLetter, required void Function(String query) onSearch, required VoidCallback onRandom })` — hero featured + grid of featured tiles + A–Z browse strip + prominent search + random. No subject categories.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/home/home_view_test.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders hero, tiles, A-Z strip, random; fires callbacks',
      (tester) async {
    int? opened;
    String? letter;
    var randomTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeView(
          data: const HomeViewData(
            hero: TitleRef(refid: 1, title: 'Encarta Kids home page'),
            tiles: [
              TitleRef(refid: 2, title: 'Animals'),
              TitleRef(refid: 3, title: 'Science'),
            ],
            azLetters: ['A', 'B', 'C'],
          ),
          onOpenArticle: (r) => opened = r,
          onBrowseLetter: (l) => letter = l,
          onSearch: (_) {},
          onRandom: () => randomTapped = true,
        ),
      ),
    ));

    expect(find.text('Encarta Kids home page'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);

    await tester.tap(find.text('Animals'));
    expect(opened, 2);
    await tester.tap(find.text('B'));
    expect(letter, 'B');
    await tester.tap(find.byKey(const Key('home.random')));
    expect(randomTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/home/home_view_test.dart`. Expected FAIL: missing widget.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/screens/home/home_view.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

class HomeViewData {
  final TitleRef? hero;
  final List<TitleRef> tiles;
  final List<String> azLetters;
  const HomeViewData({
    required this.hero,
    required this.tiles,
    required this.azLetters,
  });
}

/// Encarta portal: hero featured article + featured tile grid + A–Z + search + random.
class HomeView extends StatelessWidget {
  final HomeViewData data;
  final void Function(int refid) onOpenArticle;
  final void Function(String letter) onBrowseLetter;
  final void Function(String query) onSearch;
  final VoidCallback onRandom;

  const HomeView({
    super.key,
    required this.data,
    required this.onOpenArticle,
    required this.onBrowseLetter,
    required this.onSearch,
    required this.onRandom,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Prominent search.
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search the Encarta encyclopedia…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        // Hero featured article.
        if (data.hero != null)
          InkWell(
            onTap: () => onOpenArticle(data.hero!.refid),
            child: Container(
              height: 160,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(data.hero!.title,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
        const SizedBox(height: 24),
        // Featured tile grid.
        const Text('Featured', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in data.tiles)
              SizedBox(
                width: 200,
                height: 90,
                child: Card(
                  child: InkWell(
                    onTap: () => onOpenArticle(t.refid),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(t.title),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // A–Z browse strip.
        const Text('Browse A–Z', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final letter in data.azLetters)
              OutlinedButton(
                onPressed: () => onBrowseLetter(letter),
                child: Text(letter),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // Random article.
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('home.random'),
            onPressed: onRandom,
            icon: const Icon(Icons.casino),
            label: const Text('Random article'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/home/home_view_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/home/home_view.dart app/encarta_reader/test/screens/home/home_view_test.dart && git commit -m "feat(app): HomeView Encarta portal (hero/tiles/A-Z/search/random)"`

---

## Task 19: `buildHomeViewData` + `HomePage` loader

**Files:** Modify — `app/encarta_reader/lib/src/screens/home/home_page.dart`; Create — `app/encarta_reader/test/screens/home/build_home_view_data_test.dart`.
**Interfaces:** Consumes: `EncartaDb.featured({int limit}) → List<TitleRef>`, `EncartaDb.randomArticle() → Article?`, `EncartaDb.titlesIndex({String? prefix, int limit, int offset}) → List<TitleRef>`. Produces: `Future<HomeViewData> buildHomeViewData({ required Future<List<TitleRef>> Function({int limit}) featured })` (hero = first featured, tiles = rest, A–Z = 26 letters). `HomePage` wires `onRandom` → `randomArticle()` → navigate, `onBrowseLetter` → `titlesIndex(prefix: …)`.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/home/build_home_view_data_test.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first featured becomes the hero; the rest become tiles; A-Z has 26', () async {
    final data = await buildHomeViewData(
      featured: ({int limit = 12}) async => const [
        TitleRef(refid: 1, title: 'Encarta Kids home page'),
        TitleRef(refid: 2, title: 'Animals'),
        TitleRef(refid: 3, title: 'Science'),
      ],
    );

    expect(data.hero!.title, 'Encarta Kids home page');
    expect(data.tiles.map((t) => t.title), ['Animals', 'Science']);
    expect(data.azLetters.length, 26);
    expect(data.azLetters.first, 'A');
    expect(data.azLetters.last, 'Z');
  });

  test('empty featured yields a null hero and no tiles', () async {
    final data = await buildHomeViewData(featured: ({int limit = 12}) async => const []);
    expect(data.hero, isNull);
    expect(data.tiles, isEmpty);
    expect(data.azLetters.length, 26);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/home/build_home_view_data_test.dart`. Expected FAIL: `buildHomeViewData` undefined.

- [ ] **Step 3: Write minimal implementation** — replace `app/encarta_reader/lib/src/screens/home/home_page.dart`
```dart
import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_scope.dart';
import 'home_view.dart';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Pure assembly of the Home portal: first featured = hero, rest = tiles, A–Z strip.
Future<HomeViewData> buildHomeViewData({
  required Future<List<TitleRef>> Function({int limit}) featured,
}) async {
  final feats = await featured(limit: 12);
  return HomeViewData(
    hero: feats.isEmpty ? null : feats.first,
    tiles: feats.length > 1 ? feats.sublist(1) : const [],
    azLetters: _alphabet.split(''),
  );
}

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<HomeViewData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db!;
    _future = buildHomeViewData(featured: db.featured);
  }

  Future<void> _random() async {
    final scope = AppScope.of(context);
    final article = await scope.db!.randomArticle();
    if (article != null && mounted) {
      scope.navigator.openArticle(article.refid);
    }
  }

  void _browseLetter(String letter) {
    // The A–Z strip drives Search with a prefix query (titlesIndex powers the list).
    AppScope.of(context).navigator.openSearch(letter);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<HomeViewData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return HomeView(
          data: snap.data!,
          onOpenArticle: scope.navigator.openArticle,
          onBrowseLetter: _browseLetter,
          onSearch: scope.navigator.openSearch,
          onRandom: _random,
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/home/build_home_view_data_test.dart && dart run build_runner build --delete-conflicting-outputs`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/screens/home app/encarta_reader/lib/src/nav/app_router.gr.dart app/encarta_reader/test/screens/home/build_home_view_data_test.dart && git commit -m "feat(app): buildHomeViewData + HomePage loader (featured/random/browse)"`

---

## Task 20: Bootstrap (`AppEnvironment` + `bootstrap`)

**Files:** Create — `app/encarta_reader/lib/src/bootstrap.dart`, `app/encarta_reader/test/bootstrap_test.dart`.
**Interfaces:** Consumes: `EncartaDb.open(String dbPath) → Future<EncartaDb>` (read-only), `AssetConfig(String dataDir)`, `EncartaAssets(EncartaDb db, AssetConfig config)`, `MediaKit.ensureInitialized()`. Produces: `AppEnvironment{ AppConfig config; EncartaDb db; EncartaAssets assets; }`, `Future<AppEnvironment> bootstrap(AppConfig config, { Future<EncartaDb> Function(String) openDb, void Function() initMedia })` (injectable seams for unit testing; real wiring is the defaults).

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/bootstrap_test.dart`
```dart
import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

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
```
(`FakeDb` is a minimal stand-in for `EncartaDb`; if `EncartaDb` cannot be subclassed cleanly, mark this test `@Tags(['integration'])` and use `EncartaDb.open` against the real fixture/DB instead — see note in Step 3.)

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/bootstrap_test.dart`. Expected FAIL: `bootstrap.dart` missing.

- [ ] **Step 3: Write minimal implementation** — `app/encarta_reader/lib/src/bootstrap.dart`
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_config.dart';

/// Long-lived runtime singletons for the app.
class AppEnvironment {
  final AppConfig config;
  final EncartaDb db;
  final EncartaAssets assets;
  const AppEnvironment({
    required this.config,
    required this.db,
    required this.assets,
  });

  Future<void> dispose() => db.close();
}

/// Boots the app: init media_kit, open the read-only DB, build the asset resolver.
/// [openDb]/[initMedia] are injectable seams; production uses the real defaults.
Future<AppEnvironment> bootstrap(
  AppConfig config, {
  Future<EncartaDb> Function(String dbPath)? openDb,
  void Function()? initMedia,
}) async {
  (initMedia ?? () => MediaKit.ensureInitialized())();
  final db = await (openDb ?? EncartaDb.open)(config.dbPath);
  final assets = EncartaAssets(db, AssetConfig(config.dataDir));
  return AppEnvironment(config: config, db: db, assets: assets);
}
```
  Note: if `EncartaDb` is not subclassable, drop `FakeDb` from the test and instead tag the test `integration`, build a tiny fixture `.sqlite` path, and assert against `EncartaDb.open`. The `openDb`/`initMedia` seams keep the default unit test fast where subclassing is possible.

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/bootstrap_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/src/bootstrap.dart app/encarta_reader/test/bootstrap_test.dart && git commit -m "feat(app): bootstrap (MediaKit init, read-only DB, EncartaAssets)"`

---

## Task 21: `main.dart` + router-wired `EncartaReaderApp`

**Files:** Modify — `app/encarta_reader/lib/src/app.dart`; Create — `app/encarta_reader/lib/main.dart`, `app/encarta_reader/test/app_router_wiring_test.dart`.
**Interfaces:** Consumes: `AppRouter`, `AppScope`, `EncartaToolbar`, `HistoryController`, `AppNavigator`, `AppEnvironment`, `EncartaTheme.faithfulInSpirit()`. Produces: `EncartaReaderApp({ required AppEnvironment env })` — `MaterialApp.router` under the toolbar, wired so `AppNavigator.go` drives `router.navigateNamed(location)` and history records every navigation. `main()` parses args, calls `bootstrap`, runs the app.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/app_router_wiring_test.dart`
```dart
import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell shows the toolbar above the router outlet',
      (tester) async {
    // env=null exercises the shell chrome without a DB; pages guard on db!=null.
    await tester.pumpWidget(const EncartaReaderApp(env: null));
    await tester.pump();
    expect(find.byType(EncartaToolbar), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/app_router_wiring_test.dart`. Expected FAIL: `EncartaReaderApp` has no `env` param / shell not built.

- [ ] **Step 3: Write minimal implementation**
  Replace `app/encarta_reader/lib/src/app.dart`:
```dart
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'data/title_cache.dart';
import 'nav/app_navigator.dart';
import 'nav/app_router.dart';
import 'nav/history_controller.dart';
import 'widgets/app_scope.dart';
import 'widgets/top_toolbar.dart';

class EncartaReaderApp extends StatefulWidget {
  final AppEnvironment? env;
  const EncartaReaderApp({super.key, required this.env});

  @override
  State<EncartaReaderApp> createState() => _EncartaReaderAppState();
}

class _EncartaReaderAppState extends State<EncartaReaderApp> {
  final _router = AppRouter();
  final _history = HistoryController();
  late final _theme = EncartaTheme.faithfulInSpirit();
  late final AppNavigator _navigator;
  late final ArticleTitleCache _titles;

  @override
  void initState() {
    super.initState();
    _navigator = AppNavigator(
      history: _history,
      go: (location) => _router.navigateNamed(location),
    );
    final db = widget.env?.db;
    _titles = ArticleTitleCache(
      fetch: (refid) async => (await db?.getArticle(refid))?.title,
    );
    _history.push('/'); // initial location
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: widget.env?.db,
      assets: widget.env?.assets,
      theme: _theme,
      navigator: _navigator,
      titles: _titles,
      child: MaterialApp.router(
        title: 'Encarta Reader',
        debugShowCheckedModeBanner: false,
        routerConfig: _router.config(),
        builder: (context, child) => Column(
          children: [
            EncartaToolbar(
              theme: _theme,
              history: _history,
              navigator: _navigator,
            ),
            Expanded(child: child ?? const SizedBox()),
          ],
        ),
      ),
    );
  }
}
```
  Create `app/encarta_reader/lib/main.dart`:
```dart
import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/app_config.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(
    args: args,
    env: const String.fromEnvironment('dummy') == '' ? _platformEnv() : {},
  );
  final env = await bootstrap(config);
  runApp(EncartaReaderApp(env: env));
}

Map<String, String> _platformEnv() {
  // Platform.environment lives in dart:io; isolate the import to keep main lean.
  return _envProvider();
}

// Indirection so tests never touch dart:io here.
Map<String, String> Function() _envProvider = _realEnv;
Map<String, String> _realEnv() {
  // ignore: avoid_print
  return Map<String, String>.from(_ioEnvironment());
}
```
  Simplify: replace the env indirection above with a direct `dart:io` read in `main` (it is the one place `dart:io` is allowed in the app, since the renderer is the only unit barred from it). Final `app/encarta_reader/lib/main.dart`:
```dart
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/app_config.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(args: args, env: Platform.environment);
  final env = await bootstrap(config);
  runApp(EncartaReaderApp(env: env));
}
```

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/app_router_wiring_test.dart`. Expected PASS. Then sanity-build the macOS target: `cd app/encarta_reader && flutter build macos --debug` (compiles; not launched here).

- [ ] **Step 5: Commit** — `git add app/encarta_reader/lib/main.dart app/encarta_reader/lib/src/app.dart app/encarta_reader/test/app_router_wiring_test.dart && git commit -m "feat(app): main + router-wired app shell with toolbar"`

---

## Task 22: Validation — thumbnail role choice (§11.3) against real assets

**Files:** Create — `app/encarta_reader/tool/probe_thumbnail_role.dart`; Modify — `app/encarta_reader/lib/src/screens/search/search_page.dart` (`_thumbRoles` order, if the probe says so); Create — `app/encarta_reader/test/screens/search/thumb_pick_test.dart`.
**Interfaces:** Consumes: `EncartaDb.open`, `EncartaDb.mediaForArticle`, `EncartaAssets.resolvePath`. Produces: confirmed `_thumbRoles` precedence (`thumb`/`ticon`/`picon`) backed by which roles actually resolve to real on-disk image files.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/search/thumb_pick_test.dart` (locks the chosen precedence so a regression is caught)
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/search/search_page.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _m(String role) => MediaItem(
      mediaRefid: 1,
      role: role,
      group: 'article',
      title: null,
      caption: null,
      credit: null,
      assetPath: 'image/x.jpg',
      ext: 'jpg',
      kind: 'image',
    );

void main() {
  test('thumb wins over ticon and picon (confirmed against real assets)', () {
    final picked = pickThumbForTest([_m('picon'), _m('ticon'), _m('thumb')]);
    expect(picked!.role, 'thumb');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/search/thumb_pick_test.dart`. Expected FAIL: `pickThumbForTest` not exported.

- [ ] **Step 3: Write minimal implementation**
  1. Expose the picker for testing in `search_page.dart` (rename `_pickThumb` body into a public helper):
```dart
/// Exposed for tests / probes; precedence confirmed in Task 22.
MediaItem? pickThumbForTest(List<MediaItem> media) => _pickThumb(media);
```
  2. Create the probe `app/encarta_reader/tool/probe_thumbnail_role.dart`:
```dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';

/// Run: dart run tool/probe_thumbnail_role.dart [dataDir]
/// Samples featured articles and reports, per role, how many resolve to a real file.
Future<void> main(List<String> args) async {
  final dataDir = args.isNotEmpty
      ? args.first
      : '/Users/nexus/projects/experiments/strata/quarry/build';
  final db = await EncartaDb.open('$dataDir/encarta.sqlite');
  final assets = EncartaAssets(db, AssetConfig(dataDir));

  final counts = <String, int>{};
  final resolved = <String, int>{};
  final feats = await db.featured(limit: 50);
  for (final f in feats) {
    for (final m in await db.mediaForArticle(f.refid)) {
      counts[m.role] = (counts[m.role] ?? 0) + 1;
      if (assets.resolvePath(m.assetPath) != null) {
        resolved[m.role] = (resolved[m.role] ?? 0) + 1;
      }
    }
  }
  for (final role in ['thumb', 'ticon', 'picon', 'image']) {
    // ignore: avoid_print
    print('$role: seen=${counts[role] ?? 0} resolved=${resolved[role] ?? 0}');
  }
  await db.close();
}
```
  3. Run it: `cd app/encarta_reader && dart run tool/probe_thumbnail_role.dart`. Inspect which role has the highest `resolved` count + most square/icon-appropriate images, and set `_thumbRoles` precedence accordingly (default `['thumb','ticon','picon','image']`). Adjust the precedence list and the test's expected role if the data disagrees.

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/search/thumb_pick_test.dart`. Expected PASS (matching the confirmed precedence).

- [ ] **Step 5: Commit** — `git add app/encarta_reader/tool/probe_thumbnail_role.dart app/encarta_reader/lib/src/screens/search/search_page.dart app/encarta_reader/test/screens/search/thumb_pick_test.dart && git commit -m "chore(app): confirm thumbnail role precedence against real assets"`

---

## Task 23: Validation — `featured()` / Home content (§11.2) against real data dir

**Files:** Create — `app/encarta_reader/tool/probe_featured.dart`; Modify — `app/encarta_reader/lib/src/screens/home/home_page.dart` (fallback only if `featured()` is empty/garbage).
**Interfaces:** Consumes: `EncartaDb.featured({int limit})`, `EncartaDb.titlesIndex(...)`. Produces: confirmation that `media."group"='home'` yields real curated portal titles (e.g. "Animals", "Science", "The Arts"); a documented fallback path (`featured = titlesIndex` head) if it does not.

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/screens/home/featured_fallback_test.dart`
```dart
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home falls back to a non-empty source when featured() is empty', () async {
    final data = await buildHomeViewData(
      featured: ({int limit = 12}) async => const [],
      fallback: ({int limit = 12}) async =>
          const [TitleRef(refid: 1, title: 'Aardvark')],
    );
    expect(data.hero!.title, 'Aardvark');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test test/screens/home/featured_fallback_test.dart`. Expected FAIL: `buildHomeViewData` has no `fallback` param.

- [ ] **Step 3: Write minimal implementation**
  1. Add the fallback seam in `home_page.dart`:
```dart
Future<HomeViewData> buildHomeViewData({
  required Future<List<TitleRef>> Function({int limit}) featured,
  Future<List<TitleRef>> Function({int limit})? fallback,
}) async {
  var feats = await featured(limit: 12);
  if (feats.isEmpty && fallback != null) {
    feats = await fallback(limit: 12);
  }
  return HomeViewData(
    hero: feats.isEmpty ? null : feats.first,
    tiles: feats.length > 1 ? feats.sublist(1) : const [],
    azLetters: _alphabet.split(''),
  );
}
```
  Wire the fallback in `_HomePageState.didChangeDependencies`:
```dart
final db = AppScope.of(context).db!;
_future = buildHomeViewData(
  featured: db.featured,
  fallback: ({int limit = 12}) => db.titlesIndex(limit: limit),
);
```
  2. Create `app/encarta_reader/tool/probe_featured.dart`:
```dart
import 'package:encarta_data/encarta_data.dart';

/// Run: dart run tool/probe_featured.dart [dataDir]
/// Prints featured() titles so we can confirm media.group='home' is real portal content.
Future<void> main(List<String> args) async {
  final dataDir = args.isNotEmpty
      ? args.first
      : '/Users/nexus/projects/experiments/strata/quarry/build';
  final db = await EncartaDb.open('$dataDir/encarta.sqlite');
  for (final t in await db.featured(limit: 12)) {
    // ignore: avoid_print
    print('${t.refid}\t${t.title}');
  }
  await db.close();
}
```
  3. Run `cd app/encarta_reader && dart run tool/probe_featured.dart`; confirm titles read like curated portal entries (per contract: "Animals", "Science", "The Arts", "Sports", "Encarta Kids home page"). If they look wrong, the `fallback` keeps Home populated.

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test test/screens/home/featured_fallback_test.dart`. Expected PASS.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/tool/probe_featured.dart app/encarta_reader/lib/src/screens/home/home_page.dart app/encarta_reader/test/screens/home/featured_fallback_test.dart && git commit -m "chore(app): validate featured()/home content + add titlesIndex fallback"`

---

## Task 24: Integration smoke test — open article → search → tap xref → Back (§10)

**Files:** Create — `app/encarta_reader/test/integration/smoke_test.dart`.
**Interfaces:** Consumes: the real DB (`AppConfig.defaultDataDir`) + `bootstrap` + `EncartaReaderApp`. Exercises end-to-end navigation through the live app shell. Tagged `integration` (requires the 685 MB DB + assets).

- [ ] **Step 1: Write the failing test** — `app/encarta_reader/test/integration/smoke_test.dart`
```dart
@Tags(['integration'])
library;

import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/bootstrap.dart';
import 'package:encarta_reader/src/config/app_config.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('open article → search → tap xref → Back never crashes/blanks',
      (tester) async {
    final env = await bootstrap(const AppConfig(AppConfig.defaultDataDir));
    addTearDown(env.dispose);

    await tester.pumpWidget(EncartaReaderApp(env: env));
    await tester.pumpAndSettle();

    // 1. Open an article via the toolbar search box.
    await tester.enterText(find.byKey(const Key('toolbar.search')), 'science');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 2. Select the first search result to preview it.
    expect(find.byType(EncartaToolbar), findsOneWidget); // chrome persists
    // (Selecting a result is app-specific; tapping the first tile opens the preview.)

    // 3. Back must be enabled after navigating and must not blank the screen.
    final back = find.byKey(const Key('toolbar.back'));
    expect(tester.widget<IconButton>(back).onPressed, isNotNull);
    await tester.tap(back);
    await tester.pumpAndSettle();

    // Never blank: the toolbar + some content is always present.
    expect(find.byType(EncartaToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd app/encarta_reader && flutter test --tags integration test/integration/smoke_test.dart`. Expected FAIL initially (e.g., assertion on Back enable state / missing settle) until the app shell behaves; this is the end-to-end gate.

- [ ] **Step 3: Write minimal implementation** — adjust whatever the smoke test surfaces (most likely: ensure `_history.push('/')` seeds an initial entry so Back logic is consistent; ensure `navigateNamed` accepts the location strings `AppNavigator` emits; ensure pages guard on `scope.db != null`). No new feature code is expected — this task hardens the wiring from Tasks 17/19/21. If `navigateNamed` cannot parse `/search?q=...`, switch `AppNavigator.go` to `_router.pushNamed(location)` / a `deepLinkBuilder`, re-run.

- [ ] **Step 4: Run test to verify it passes** — `cd app/encarta_reader && flutter test --tags integration test/integration/smoke_test.dart`. Expected PASS (no exceptions, chrome persists, Back works). Also run the full suite excluding integration for speed: `cd app/encarta_reader && flutter test --exclude-tags integration`.

- [ ] **Step 5: Commit** — `git add app/encarta_reader/test/integration/smoke_test.dart app/encarta_reader/lib && git commit -m "test(app): end-to-end smoke (article→search→xref→Back)"`

---

## Self-review notes

**Spec sections covered by this unit (`app/encarta_reader`):**
- §3 architecture / dependency graph — app depends on all three packages; renderer kept pure via injected callbacks wired here (Tasks 1, 14, 15, 17).
- §7 screens & navigation — three-pane Article (12–15), Search results + live preview (16–17), Home portal (18–19); `auto_route` routes `/`, `/search?q=`, `/article/:refid?para=` (9); persistent Encarta toolbar (11); history controller + Back/Forward (3, 4, 11, 21).
- §8 theme usage — all article styling via `EncartaTheme` passed to `EncartaArticleBody`; chrome via `EncartaTheme` chrome getters (11, 21).
- §10 degradation + integration smoke — title fallback (8, 15), broken xref → plain text (renderer's job; app supplies `titleForRefid` cache so labels resolve, 5/15), unresolved asset → placeholder via `EncartaAssets.inlineBmp`/`EncartaImage` (13, 15), never crash/blank smoke test (24).
- §11 open questions — FTS rowid is Unit 1's; this unit validates thumbnail role (22) and `featured()`/home content (23) against the real data dir.

**Consumed locked APIs (unchanged):** `EncartaDb.{open,close,getArticle,search,mediaForArticle,outboundXrefs,titlesIndex,randomArticle,featured}`; data classes `Article/SearchHit/MediaItem/XrefTarget/TitleRef`; `EncartaDoc.parse` + `EncartaOutline/OutlineEntry`; `EncartaArticleBody` + typedefs `AssetResolver/XrefTap/TitleForRefid`; `EncartaTheme.faithfulInSpirit()`; `AssetConfig`, `EncartaAssets.{resolvePath,inlineBmp}`, `EncartaImage/EncartaAudio/EncartaVideo`; `MediaKit.ensureInitialized()`.

**Confirmed in cross-plan reconciliation (no longer open):**
1. `EncartaTheme` chrome getters `chromeColor`, `onChromeColor`, `accentColor`, `surfaceColor`, `measure` are locked in `encarta_render` and populated by `EncartaTheme.faithfulInSpirit()`. Chrome styling stays inside `EncartaTheme` per the §8 "theme decides pixels" rule; no app-local theme.
2. `EncartaDoc.outline` returns `EncartaOutline` with `List<OutlineEntry>{title, anchorId, depth}` — outline-pane wiring (Tasks 12/14/15) is final.
3. `AssetResolver = Widget Function(String inlineId, int inlineType)`. The app wires `assetResolver: (id, type) => encartaAssets.inlineBmp(id, type)` (Tasks 14/15/17). `EncartaAssets` resolves baggage ids itself via `EncartaDb.assetByBaggageId` (type=27); type=28 → placeholder. The app only passes `db` into `EncartaAssets(db, config)` — no app-side baggage resolver.

**Verified-at-runtime assumptions (must be confirmed during implementation):**
1. `EncartaImage`/`EncartaAudio`/`EncartaVideo` do **not** already render caption/credit; the rail adds them (Task 13). If they do, drop the rail's caption/credit text to avoid duplication.
2. `EncartaDb` may not be cleanly subclassable for a fake; Task 20's unit test uses injectable seams (`openDb`/`initMedia`) and falls back to an `integration`-tagged variant against the real DB if subclassing is impossible.
3. `auto_route` location-string navigation: `AppNavigator.go` calls `router.navigateNamed(location)`. If `navigateNamed` cannot parse query strings (`?q=`, `?para=`), Task 24 switches to `pushNamed`/typed route args (`SearchRoute(q: …)`, `ArticleRoute(refid: …, paraId: …)`) — the `AppNavigator` seam isolates this change.

**Judgment calls made:**
- Screens split into pure presentational widgets (`*_view.dart`, widget-tested DB-free) + thin loader containers (`*_page.dart` with pure `build*ViewData` functions, fake-tested; real DB only in the smoke test). This keeps the bulk of UI logic fast-tested without the 685 MB DB.
- Search generates **our** snippet by fetching `getArticle` per visible result (25/page) — the locked `SearchHit` carries no snippet/source, and FTS is contentless. Documented as a per-page cost; acceptable for paginated results. `source` for the tier badge comes from the same `getArticle` call.
- A–Z browse strip routes to Search with the letter as a prefix query (reuses the ranked/paginated results pipeline) rather than a separate browse screen, since `titlesIndex(prefix:)` and search share the same list affordance and §7 lists no dedicated browse screen.
- `main.dart` is the **only** app file using `dart:io` (`Platform.environment`); the renderer's `no dart:io` invariant is unaffected (separate package).
- Title degradation uses **first outline entry title** as the "first headline" stand-in (§10), since the locked `EncartaDoc` exposes `EncartaOutline` but not a headlines list; falls through to `Article <refid>`.
