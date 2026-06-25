# encarta_render Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `encarta_render`, the reusable Flutter package that parses Encarta 2009 article XML (`package:xml`) into a lazily-rendered Flutter widget tree, covering all 32 vocabulary tags, with all pixel styling delegated to an injected `EncartaTheme`.

**Architecture:** Pure presentation layer. `EncartaDoc.parse` turns `Uint8List` XML into a parsed model (top-level blocks + `EncartaOutline`). `EncartaArticleBody` walks the top-level blocks lazily; a `BlockRenderer` maps block tags to vertical widgets and an `InlineBuilder` maps inline tags to `InlineSpan` runs. All storage/format/IO concerns are reached ONLY through three injected callbacks — `AssetResolver`, `XrefTap`, `TitleForRefid`. The package NEVER imports `dart:io`, SQLite, or drift.

**Tech Stack:** Flutter 3.42.0 beta / Dart 3.12 beta; `package:xml` ^6.5.0 (parsing); `package:url_launcher` ^6.3.0 (external `xref type=9`); `flutter_test` golden + widget tests. Target macOS arm64.

## Global Constraints

- Toolchain pinned: **Flutter 3.42.0 beta**, **Dart 3.12 beta**; primary target **macOS arm64**.
- `encarta_render` **NEVER** imports `dart:io`, `sqlite3`, `drift`, `encarta_data`, or `encarta_assets`. Its only outside-world reach is the three injected callbacks.
- Renderer reads styling **only** from `EncartaTheme`. "Theme decides pixels, renderer decides structure" — the renderer assigns semantic roles, never literal colors/sizes.
- **Never drop text / never crash on bad data:** unknown/rare tags render their children with default styling; malformed fragments render what parses.
- Data dir / asset bytes are out of scope here — they arrive via the injected `AssetResolver`.
- Article titles are NOT in the body: `inlinetitle` is empty → substitute the injected `title` (41,282 articles use it; VOCABULARY.md line 56).
- Long-article performance: body rendered **lazily** via a builder over top-level blocks (spec §10).
- **TDD:** every task writes a failing test first, then minimal impl, then commits. Use `flutter test` (this is a Flutter package). Frequent commits — one per task.
- Library is a pub-workspace member (`resolution: workspace`); run `flutter pub get` from the workspace root after scaffolding.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/encarta_render/pubspec.yaml` | Package manifest: deps `xml`, `url_launcher`, `flutter`; NO data/assets/io deps. |
| `packages/encarta_render/analysis_options.yaml` | Lints (`flutter_lints`). |
| `packages/encarta_render/lib/encarta_render.dart` | Public barrel: exports callbacks, `EncartaDoc`/`EncartaOutline`/`OutlineEntry`, `EncartaTheme`, `EncartaArticleBody`. |
| `packages/encarta_render/lib/src/callbacks.dart` | The three injected typedefs: `AssetResolver`, `XrefTap`, `TitleForRefid`. |
| `packages/encarta_render/lib/src/encarta_theme.dart` | `EncartaTheme` (ThemeExtension bag of all concrete styles) + `faithfulInSpirit()` factory. |
| `packages/encarta_render/lib/src/encarta_doc.dart` | `EncartaDoc.parse`, `EncartaOutline`, `OutlineEntry`; content→text→blocks walk + outline build. |
| `packages/encarta_render/lib/src/inline_renderer.dart` | `InlineBuilder`: inline tags → `List<InlineSpan>` (i/b/u/smallcaps/sub/sup/fs/br/xref/inlinebmp/inlinetitle/rare/unknown). |
| `packages/encarta_render/lib/src/block_renderer.dart` | `BlockRenderer`: block tags → vertical widgets (pkey/intro/headline/author/quote/example/section/list/sec*/rule/br). |
| `packages/encarta_render/lib/src/encarta_article_body.dart` | `EncartaArticleBody` widget: lazy `ListView.builder`, `ScrollController?`, anchor keys + `scrollToAnchor`. |
| `packages/encarta_render/test/encarta_doc_test.dart` | parse + outline tests. |
| `packages/encarta_render/test/encarta_theme_test.dart` | theme factory test. |
| `packages/encarta_render/test/inline_renderer_test.dart` | inline-span unit tests (spans 6–11). |
| `packages/encarta_render/test/block_renderer_test.dart` | block widget tests (12–16). |
| `packages/encarta_render/test/encarta_article_body_test.dart` | widget + scroll-anchor test (17). |
| `packages/encarta_render/test/golden_all_tags_test.dart` | golden + fake-callback test exercising all 32 tags (18). |
| `packages/encarta_render/test/goldens/all_tags.png` | golden reference image (generated). |

---

### Task 1: Package scaffold

**Files:** Create — `packages/encarta_render/pubspec.yaml`, `packages/encarta_render/analysis_options.yaml`, `packages/encarta_render/lib/encarta_render.dart`. Test — `packages/encarta_render/test/scaffold_test.dart`.
**Interfaces:** Consumes: nothing. Produces: importable `package:encarta_render/encarta_render.dart` library.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/scaffold_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart' as lib;

void main() {
  test('library is importable', () {
    expect(lib.encartaRenderVersion, '0.1.0');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/scaffold_test.dart`
Expected FAIL: `Target of URI doesn't exist` / `encartaRenderVersion` undefined (no lib yet).

- [ ] **Step 3: Write minimal implementation**
```yaml
# packages/encarta_render/pubspec.yaml
name: encarta_render
description: Faithful-in-spirit renderer turning Encarta 2009 article XML into a Flutter widget tree.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.12.0-0
  flutter: '>=3.42.0'

dependencies:
  flutter:
    sdk: flutter
  xml: ^6.5.0
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```
```yaml
# packages/encarta_render/analysis_options.yaml
include: package:flutter_lints/flutter.yaml
```
```dart
// packages/encarta_render/lib/encarta_render.dart
/// Public API for the Encarta XML renderer.
library encarta_render;

const String encartaRenderVersion = '0.1.0';
```

- [ ] **Step 4: Run test to verify it passes**
`cd /Users/nexus/projects/experiments/strata/reader && flutter pub get && cd packages/encarta_render && flutter test test/scaffold_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): scaffold encarta_render Flutter package"`

---

### Task 2: Injected callback typedefs

**Files:** Create — `packages/encarta_render/lib/src/callbacks.dart`. Modify — `lib/encarta_render.dart` (export). Test — `packages/encarta_render/test/callbacks_test.dart`.
**Interfaces:** Produces (LOCKED contract names): `typedef AssetResolver = Widget Function(String inlineId, int inlineType);`, `typedef XrefTap = void Function(int targetRefid, {String? paraId});`, `typedef TitleForRefid = String? Function(int refid);`.

> Reconciliation note (Unit 3): `inlinebmp` resolution depends on BOTH `id` and `type` — `type=27` carries an asset baggage_id `id` that resolves to a real image; `type=28` carries an original `NAME.DIB` filename that is unresolvable → placeholder. So `AssetResolver` takes `(String inlineId, int inlineType)` and the renderer passes both attributes through verbatim WITHOUT interpreting them.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/callbacks_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

void main() {
  test('callback typedefs have the locked shapes', () {
    final AssetResolver ar = (inlineId, inlineType) => const SizedBox.shrink();
    int? tappedRefid;
    String? tappedPara;
    final XrefTap tap = (refid, {paraId}) {
      tappedRefid = refid;
      tappedPara = paraId;
    };
    final TitleForRefid t = (refid) => refid == 1 ? 'One' : null;

    expect(ar('GLYPH.DIB', 28), isA<Widget>());
    tap(7, paraId: 'p3');
    expect(tappedRefid, 7);
    expect(tappedPara, 'p3');
    expect(t(1), 'One');
    expect(t(2), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/callbacks_test.dart`
Expected FAIL: `AssetResolver`/`XrefTap`/`TitleForRefid` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/callbacks.dart
import 'package:flutter/widgets.dart';

/// Builds an inline image widget for an `inlinebmp`, given its raw `id` attribute
/// (verbatim) and `type` attribute (as int). Resolution depends on both: `type=27`
/// → `id` is an asset baggage_id (resolvable); `type=28` → `id` is an original
/// `NAME.DIB` filename (unresolvable → placeholder). The renderer passes both
/// through and NEVER interprets them; the host injects this.
typedef AssetResolver = Widget Function(String inlineId, int inlineType);

/// Called when an internal `xref` is tapped. [paraId] is the `paraID` deep-link, if any.
typedef XrefTap = void Function(int targetRefid, {String? paraId});

/// Returns the title for a refid, or null if the refid is absent from the corpus
/// (used for `inlinetitle` fallback and to suppress dead `xref` links).
typedef TitleForRefid = String? Function(int refid);
```
Add to `lib/encarta_render.dart`:
```dart
export 'src/callbacks.dart';
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/callbacks_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): injected AssetResolver/XrefTap/TitleForRefid typedefs"`

---

### Task 3: EncartaTheme + faithfulInSpirit factory

**Files:** Create — `packages/encarta_render/lib/src/encarta_theme.dart`. Modify — `lib/encarta_render.dart` (export). Test — `packages/encarta_render/test/encarta_theme_test.dart`.
**Interfaces:** Produces: `class EncartaTheme extends ThemeExtension<EncartaTheme>` with const ctor + `EncartaTheme.faithfulInSpirit()`. The renderer reads `body`, `intro`, `author`, `quote`, `example`, `listItem`, `enumerator`, `xrefStyle`, `ruleColor`, `headlineDefault`, `sectionTitleStyle(int)`, `measure`, `blockSpacing`, `sectionIndentPerDepth`, `fractionFontScale`, `debugUnstyledTags`, `debugUnstyledColor`, `background`, `foreground`. The **app** (Unit 4) reads the chrome/portal getters `chromeColor`, `onChromeColor`, `accentColor`, `surfaceColor`, `measure` for the toolbar and Home/portal — `EncartaTheme` owns ALL pixels per §8.

> Note: spec §8 ("faithful in spirit") lives in this package as the default theme. `headline` `type` values 33/32/36/35/34 (VOCABULARY.md line 42) collapse to one `headlineDefault` style; `section` `type` 4/5/6/7 (line 39) map to four heading levels via `sectionTitleStyle`. These two collapses are judgment calls (see Self-review notes).
> Reconciliation note (Unit 4): `EncartaTheme` exposes chrome/portal styling so the app never hard-codes pixels — `chromeColor` (blue/teal toolbar), `onChromeColor` (toolbar foreground), `accentColor`, `surfaceColor` (light content background), and `measure` (article max content width). The app reads these for the top toolbar and the Home/portal grid.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/encarta_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

void main() {
  test('faithfulInSpirit factory produces a usable, debug-off theme', () {
    final t = EncartaTheme.faithfulInSpirit();
    expect(t, isA<ThemeExtension<EncartaTheme>>());
    expect(t.body.fontSize, isNotNull);
    expect(t.measure, greaterThan(400));
    expect(t.debugUnstyledTags, isFalse);
    // section heading levels are distinct and clamp out of range
    expect(t.sectionTitleStyle(1).fontSize, greaterThan(t.sectionTitleStyle(4).fontSize!));
    expect(t.sectionTitleStyle(99).fontSize, t.sectionTitleStyle(4).fontSize);
    // chrome/portal getters the app consumes are populated (theme owns all pixels)
    expect(t.chromeColor, isA<Color>());
    expect(t.onChromeColor, isA<Color>());
    expect(t.accentColor, isA<Color>());
    expect(t.surfaceColor, isA<Color>());
  });

  test('copyWith can flip debug highlight mode without losing styles', () {
    final t = EncartaTheme.faithfulInSpirit();
    final debug = t.copyWith(debugUnstyledTags: true);
    expect(debug.debugUnstyledTags, isTrue);
    expect(debug.body, t.body);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/encarta_theme_test.dart`
Expected FAIL: `EncartaTheme` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/encarta_theme.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Bag of ALL concrete styling the renderer consumes. The renderer assigns
/// semantic roles; this decides every pixel. ThemeExtension so it can ride a
/// Flutter [ThemeData] if the host wants.
@immutable
class EncartaTheme extends ThemeExtension<EncartaTheme> {
  const EncartaTheme({
    required this.background,
    required this.foreground,
    required this.chromeColor,
    required this.onChromeColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.measure,
    required this.blockSpacing,
    required this.sectionIndentPerDepth,
    required this.body,
    required this.intro,
    required this.author,
    required this.quote,
    required this.example,
    required this.listItem,
    required this.enumerator,
    required this.xrefStyle,
    required this.headlineDefault,
    required this.sectionTitles,
    required this.ruleColor,
    required this.fractionFontScale,
    required this.debugUnstyledTags,
    required this.debugUnstyledColor,
  });

  final Color background;
  final Color foreground;
  final Color chromeColor;              // app toolbar chrome (blue/teal) — read by the app
  final Color onChromeColor;            // foreground on chrome — read by the app
  final Color accentColor;              // accent/highlight — read by the app
  final Color surfaceColor;             // light content surface (portal tiles) — read by the app
  final double measure;                 // max content width — read by renderer + app
  final double blockSpacing;            // vertical gap between blocks
  final double sectionIndentPerDepth;   // indent step for nested sections / enumerators
  final TextStyle body;                 // pkey
  final TextStyle intro;                // intro
  final TextStyle author;               // author byline
  final TextStyle quote;                // block quote
  final TextStyle example;              // worked example
  final TextStyle listItem;             // listitem text
  final TextStyle enumerator;           // sec/seca/secb/secc labels
  final TextStyle xrefStyle;            // link decoration merged onto base
  final TextStyle headlineDefault;      // headline (all type variants)
  final List<TextStyle> sectionTitles;  // by depth 1..n (clamped)
  final Color ruleColor;
  final double fractionFontScale;       // fs type=2 numerator/denominator scale
  final bool debugUnstyledTags;         // highlight unknown/rare tags
  final Color debugUnstyledColor;

  TextStyle sectionTitleStyle(int depth) {
    final i = (depth - 1).clamp(0, sectionTitles.length - 1);
    return sectionTitles[i];
  }

  factory EncartaTheme.faithfulInSpirit() {
    const ink = Color(0xFF1A1A1A);
    const teal = Color(0xFF0B7285);
    const linkBlue = Color(0xFF1B5E9B);
    return const EncartaTheme(
      background: Color(0xFFFBFBF7),
      foreground: ink,
      chromeColor: Color(0xFF1B5E8C),   // Encarta-era blue/teal toolbar
      onChromeColor: Color(0xFFFFFFFF),
      accentColor: teal,
      surfaceColor: Color(0xFFFFFFFF),  // light content/portal-tile surface
      measure: 680,
      blockSpacing: 14,
      sectionIndentPerDepth: 16,
      body: TextStyle(fontSize: 16, height: 1.5, color: ink),
      intro: TextStyle(fontSize: 18, height: 1.5, color: ink, fontWeight: FontWeight.w500),
      author: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF555555)),
      quote: TextStyle(fontSize: 16, height: 1.5, fontStyle: FontStyle.italic, color: Color(0xFF333333)),
      example: TextStyle(fontSize: 15, height: 1.45, color: ink),
      listItem: TextStyle(fontSize: 16, height: 1.45, color: ink),
      enumerator: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: teal),
      xrefStyle: TextStyle(color: linkBlue, decoration: TextDecoration.underline),
      headlineDefault: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      sectionTitles: [
        TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: teal),
        TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: teal),
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      ],
      ruleColor: Color(0xFFCCCCCC),
      fractionFontScale: 0.72,
      debugUnstyledTags: false,
      debugUnstyledColor: Color(0x33FF0000),
    );
  }

  @override
  EncartaTheme copyWith({
    Color? background,
    Color? foreground,
    Color? chromeColor,
    Color? onChromeColor,
    Color? accentColor,
    Color? surfaceColor,
    double? measure,
    double? blockSpacing,
    double? sectionIndentPerDepth,
    TextStyle? body,
    TextStyle? intro,
    TextStyle? author,
    TextStyle? quote,
    TextStyle? example,
    TextStyle? listItem,
    TextStyle? enumerator,
    TextStyle? xrefStyle,
    TextStyle? headlineDefault,
    List<TextStyle>? sectionTitles,
    Color? ruleColor,
    double? fractionFontScale,
    bool? debugUnstyledTags,
    Color? debugUnstyledColor,
  }) {
    return EncartaTheme(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      chromeColor: chromeColor ?? this.chromeColor,
      onChromeColor: onChromeColor ?? this.onChromeColor,
      accentColor: accentColor ?? this.accentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      measure: measure ?? this.measure,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      sectionIndentPerDepth: sectionIndentPerDepth ?? this.sectionIndentPerDepth,
      body: body ?? this.body,
      intro: intro ?? this.intro,
      author: author ?? this.author,
      quote: quote ?? this.quote,
      example: example ?? this.example,
      listItem: listItem ?? this.listItem,
      enumerator: enumerator ?? this.enumerator,
      xrefStyle: xrefStyle ?? this.xrefStyle,
      headlineDefault: headlineDefault ?? this.headlineDefault,
      sectionTitles: sectionTitles ?? this.sectionTitles,
      ruleColor: ruleColor ?? this.ruleColor,
      fractionFontScale: fractionFontScale ?? this.fractionFontScale,
      debugUnstyledTags: debugUnstyledTags ?? this.debugUnstyledTags,
      debugUnstyledColor: debugUnstyledColor ?? this.debugUnstyledColor,
    );
  }

  @override
  EncartaTheme lerp(ThemeExtension<EncartaTheme>? other, double t) {
    if (other is! EncartaTheme) return this;
    return t < 0.5 ? this : other;
  }
}
```
Add to `lib/encarta_render.dart`:
```dart
export 'src/encarta_theme.dart';
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/encarta_theme_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): EncartaTheme bag + faithfulInSpirit factory"`

---

### Task 4: EncartaDoc.parse — content → text → blocks  (tags: `content`, `text`)

**Files:** Create — `packages/encarta_render/lib/src/encarta_doc.dart`. Modify — `lib/encarta_render.dart` (export). Test — `packages/encarta_render/test/encarta_doc_test.dart`.
**Interfaces:** Produces: `class EncartaDoc { String title; List<XmlElement> blocks; EncartaOutline outline; Iterable<String> allAnchorIds(); static EncartaDoc parse(Uint8List xml, {required String title}); }`. Consumes nothing.

> Notes (VOCABULARY.md): `content` is the root (116,119/116,119, attrs `refid`,`revision`, line 36). `text` is the body wrapper (100,074/116,119, attr `xml:space="preserve"`, line 37). ~16k bodies have no `<text>` wrapper → fall back to `<content>`'s block children. `allAnchorIds()` collects every element `id` (e.g. `pkey id` line 38, `section id` line 39) for `paraID` deep-links and outline anchors.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/encarta_doc_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('parse walks content -> text -> blocks and keeps the injected title', () {
    final doc = EncartaDoc.parse(
      _b('<content refid="1" revision="1"><text xml:space="preserve">'
         '<pkey id="p1">Hello</pkey><pkey id="p2">World</pkey></text></content>'),
      title: 'My Title',
    );
    expect(doc.title, 'My Title');
    expect(doc.blocks.length, 2);
    expect(doc.blocks.first.name.local, 'pkey');
    expect(doc.blocks.first.getAttribute('id'), 'p1');
    expect(doc.allAnchorIds(), containsAll(<String>['p1', 'p2']));
  });

  test('parse falls back to <content> children when <text> is absent', () {
    final doc = EncartaDoc.parse(
      _b('<content refid="2" revision="1"><pkey id="x">Body</pkey></content>'),
      title: 'T',
    );
    expect(doc.blocks.single.name.local, 'pkey');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/encarta_doc_test.dart`
Expected FAIL: `EncartaDoc` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/encarta_doc.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:xml/xml.dart';

/// One entry in the "In this article" outline (a section's title).
class OutlineEntry {
  const OutlineEntry({required this.title, required this.anchorId, required this.depth});
  final String title;
  final String anchorId;
  final int depth;
}

/// The section/sectiontitle tree, flattened in document order for the outline pane.
class EncartaOutline {
  const EncartaOutline(this.entries);
  final List<OutlineEntry> entries;
}

/// Parsed, render-ready model of one article body. Pure data over `package:xml`;
/// no IO, no SQLite. The renderer walks [blocks] lazily.
class EncartaDoc {
  EncartaDoc._({required this.title, required this.blocks, required this.outline});

  final String title;
  final List<XmlElement> blocks;
  final EncartaOutline outline;

  static EncartaDoc parse(Uint8List xml, {required String title}) {
    final document = XmlDocument.parse(utf8.decode(xml));
    final content = document.rootElement; // <content>
    final texts = content.findElements('text').toList();
    final XmlElement body = texts.isNotEmpty ? texts.first : content;
    final blocks = body.childElements.toList();
    return EncartaDoc._(title: title, blocks: blocks, outline: const EncartaOutline(<OutlineEntry>[]));
  }

  /// Every element `id` in the body (deduped by the caller), used for paraID
  /// deep-links and section/title anchors.
  Iterable<String> allAnchorIds() sync* {
    for (final b in blocks) {
      final bid = b.getAttribute('id');
      if (bid != null && bid.isNotEmpty) yield bid;
      for (final d in b.descendantElements) {
        final id = d.getAttribute('id');
        if (id != null && id.isNotEmpty) yield id;
      }
    }
  }
}
```
Add to `lib/encarta_render.dart`:
```dart
export 'src/encarta_doc.dart';
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/encarta_doc_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): EncartaDoc.parse content->text->blocks + anchor ids"`

---

### Task 5: EncartaOutline from the section/sectiontitle tree

**Files:** Modify — `lib/src/encarta_doc.dart`. Test — `packages/encarta_render/test/encarta_doc_test.dart` (add cases).
**Interfaces:** Produces: populated `EncartaDoc.outline` (`List<OutlineEntry>`) with nesting `depth` (1-based) and `anchorId` from the `section` `id`.

> Notes: `section` (23,054 articles / 211,296 occurrences, nestable, line 39) each carry one `sectiontitle` (same counts, line 40). Outline `depth` is the actual nesting level (more reliable than the `type` attribute, which is depth/kind); `anchorId` is the `section id` (or a generated `sec-N` fallback). Sections with an empty/absent `sectiontitle` are skipped.
> Reconciliation note (Unit 4): the app's "In this article" pane calls `doc.outline` — the public getter is exactly `EncartaOutline get outline` (the `final EncartaOutline outline;` field on `EncartaDoc`, declared in Task 4). Confirm the name stays `outline`.

- [ ] **Step 1: Write the failing test**  (append to `test/encarta_doc_test.dart`)
```dart
  test('outline captures nested sectiontitles with 1-based depth and anchors', () {
    final doc = EncartaDoc.parse(
      _b('<content><text>'
         '<section type="4" id="s1"><sectiontitle>Top</sectiontitle>'
         '<pkey id="p1">body</pkey>'
         '<section type="5" id="s2"><sectiontitle>Sub</sectiontitle></section>'
         '</section></text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries.map((e) => e.title).toList(), <String>['Top', 'Sub']);
    expect(doc.outline.entries.map((e) => e.depth).toList(), <int>[1, 2]);
    expect(doc.outline.entries.first.anchorId, 's1');
  });

  test('outline skips sections without a sectiontitle', () {
    final doc = EncartaDoc.parse(
      _b('<content><text><section type="4" id="s1"></section></text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries, isEmpty);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/encarta_doc_test.dart`
Expected FAIL: outline is empty (still the placeholder `const EncartaOutline([])`).

- [ ] **Step 3: Write minimal implementation**  (in `encarta_doc.dart`)
Replace the outline construction in `parse`:
```dart
    final blocks = body.childElements.toList();
    return EncartaDoc._(title: title, blocks: blocks, outline: _buildOutline(blocks));
```
Add the helper to `EncartaDoc`:
```dart
  static EncartaOutline _buildOutline(List<XmlElement> blocks) {
    final entries = <OutlineEntry>[];
    void walk(Iterable<XmlElement> els, int depth) {
      for (final el in els) {
        if (el.name.local != 'section') continue;
        final titleEls = el.findElements('sectiontitle').toList();
        final title = titleEls.isNotEmpty ? titleEls.first.innerText.trim() : '';
        if (title.isNotEmpty) {
          final anchorId = el.getAttribute('id') ?? 'sec-${entries.length}';
          entries.add(OutlineEntry(title: title, anchorId: anchorId, depth: depth));
        }
        walk(el.childElements, depth + 1);
      }
    }
    walk(blocks, 1);
    return EncartaOutline(entries);
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/encarta_doc_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): build EncartaOutline from section/sectiontitle tree"`

---

### Task 6: InlineBuilder core — text + `i` `b` `u` `smallcaps` `sub` `sup` `br`

**Files:** Create — `packages/encarta_render/lib/src/inline_renderer.dart`. Test — `packages/encarta_render/test/inline_renderer_test.dart`.
**Interfaces:** Consumes: `EncartaTheme`, `AssetResolver`, `XrefTap`, `TitleForRefid`. Produces: `class InlineBuilder` with `List<InlineSpan> build(XmlElement element, TextStyle base)`; later tasks add `xref`/`inlinebmp`/`fs`/`inlinetitle`/rare branches to `_element`.

> Notes (VOCABULARY.md): `i` italic (31,844 arts / 244,547 occ, line 58), `b` bold (5,824 / 18,798, line 59), `u` underline (1 / 36, rare, line 60), `smallcaps` (4,724 / 14,641, line 61), `sub` subscript (612 / 3,708, line 62), `sup` superscript (689 / 2,819, line 63), `br` line break `<br></br>` (6,318 / 43,745, line 53). `xml:space="preserve"` → keep `XmlText` verbatim. Recognizers (for later xref task) accumulate in an injected `recognizers` list owned by the widget State for disposal.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/inline_renderer_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_render/src/inline_renderer.dart';

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;

InlineBuilder builder({
  String title = 'T',
  AssetResolver? assetResolver,
  XrefTap? onXrefTap,
  TitleForRefid? titleForRefid,
  List<GestureRecognizer>? recognizers,
}) =>
    InlineBuilder(
      theme: EncartaTheme.faithfulInSpirit(),
      assetResolver: assetResolver ?? (inlineId, inlineType) => const SizedBox.shrink(),
      onXrefTap: onXrefTap ?? (refid, {paraId}) {},
      titleForRefid: titleForRefid ?? (refid) => null,
      articleTitle: title,
      recognizers: recognizers ?? <GestureRecognizer>[],
    );

void main() {
  test('plain text passes through with the base style', () {
    final spans = builder().build(el('<pkey>hello</pkey>'), const TextStyle(fontSize: 16));
    final t = spans.whereType<TextSpan>().single;
    expect(t.text, 'hello');
    expect(t.style!.fontSize, 16);
  });

  test('i/b/u/smallcaps produce correctly-styled spans', () {
    final spans = builder().build(
      el('<pkey><i>it</i><b>bd</b><u>un</u><smallcaps>SC</smallcaps></pkey>'),
      const TextStyle(fontSize: 16),
    );
    final texts = spans.whereType<TextSpan>().toList();
    expect(texts.firstWhere((s) => s.text == 'it').style!.fontStyle, FontStyle.italic);
    expect(texts.firstWhere((s) => s.text == 'bd').style!.fontWeight, FontWeight.bold);
    expect(texts.firstWhere((s) => s.text == 'un').style!.decoration, TextDecoration.underline);
    expect(texts.firstWhere((s) => s.text == 'SC').style!.fontFeatures,
        contains(const FontFeature.enableFeature('smcp')));
  });

  test('sub and sup become WidgetSpans (shifted small text)', () {
    final spans = builder().build(el('<pkey>H<sub>2</sub>O e<sup>2</sup></pkey>'),
        const TextStyle(fontSize: 16));
    expect(spans.whereType<WidgetSpan>(), hasLength(2));
  });

  test('br yields a newline text span', () {
    final spans = builder().build(el('<pkey>a<br></br>b</pkey>'), const TextStyle());
    expect(spans.whereType<TextSpan>().any((s) => s.text == '\n'), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: `InlineBuilder` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/inline_renderer.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'callbacks.dart';
import 'encarta_theme.dart';

/// Turns inline XML runs into Flutter [InlineSpan]s. Stateless except for the
/// shared [recognizers] sink, which the host widget disposes.
class InlineBuilder {
  InlineBuilder({
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    required this.articleTitle,
    required this.recognizers,
  });

  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final String articleTitle;
  final List<GestureRecognizer> recognizers;

  List<InlineSpan> build(XmlElement element, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final node in element.children) {
      if (node is XmlText) {
        spans.add(TextSpan(text: node.value, style: base));
      } else if (node is XmlElement) {
        spans.addAll(_element(node, base));
      }
    }
    return spans;
  }

  List<InlineSpan> _element(XmlElement el, TextStyle base) {
    switch (el.name.local) {
      case 'i':
        return build(el, base.copyWith(fontStyle: FontStyle.italic));
      case 'b':
        return build(el, base.copyWith(fontWeight: FontWeight.bold));
      case 'u':
        return build(el, base.copyWith(decoration: TextDecoration.underline));
      case 'smallcaps':
        return build(el, base.copyWith(fontFeatures: const [FontFeature.enableFeature('smcp')]));
      case 'sub':
        return [_shift(el, base, 0.22)];
      case 'sup':
        return [_shift(el, base, -0.40)];
      case 'br':
        return const [TextSpan(text: '\n')];
      default:
        // Never drop text: render children with the inherited style.
        return build(el, base);
    }
  }

  InlineSpan _shift(XmlElement el, TextStyle base, double dyFactor) {
    final fontSize = base.fontSize ?? 16;
    final small = base.copyWith(fontSize: fontSize * 0.75);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Transform.translate(
        offset: Offset(0, fontSize * dyFactor),
        child: Text.rich(TextSpan(children: build(el, small))),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): InlineBuilder core i/b/u/smallcaps/sub/sup/br + text"`

---

### Task 7: `inlinetitle` → substitute injected title

**Files:** Modify — `lib/src/inline_renderer.dart`. Test — `test/inline_renderer_test.dart` (add case).
**Interfaces:** Consumes: `articleTitle`. Produces: `inlinetitle` branch in `_element`.

> Notes: `inlinetitle` is an **empty** placeholder (41,282 arts / 41,285 occ, line 56); substitute the injected `articleTitle`.

- [ ] **Step 1: Write the failing test**  (append to `test/inline_renderer_test.dart`)
```dart
  test('inlinetitle substitutes the injected article title', () {
    final spans = builder(title: 'Mercury (planet)')
        .build(el('<pkey>See <inlinetitle></inlinetitle> now</pkey>'), const TextStyle());
    expect(spans.whereType<TextSpan>().any((s) => s.text == 'Mercury (planet)'), isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: `inlinetitle` renders nothing (empty element → no spans).

- [ ] **Step 3: Write minimal implementation**  (add a case in `_element`, before `default`)
```dart
      case 'inlinetitle':
        return [TextSpan(text: articleTitle, style: base)];
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): inlinetitle substitutes injected article title"`

---

### Task 8: `xref` — external URL / internal tap / dead-link fallback

**Files:** Modify — `lib/src/inline_renderer.dart`. Test — `test/inline_renderer_test.dart` (add cases).
**Interfaces:** Consumes: `XrefTap onXrefTap`, `TitleForRefid titleForRefid`, `recognizers`, `url_launcher`. Produces: `xref` branch in `_element`.

> Notes (VOCABULARY.md lines 54, 69–86): `type=9` external (1,857) carries `URL` → open via `url_launcher`. ALL other types are internal `RefID`-bearing → `onXrefTap(refid, paraId:)`: `type=8` (194,779), `17` (15,238), `15` (6,786), `10` (2,766), `11` (1,983), `14` (1,684), `16` (45). `paraID` (5,490) is the deep-link. A `RefID` absent from corpus (`titleForRefid` returns null) → plain text, no dead link. A `type=9` without a `URL` → plain text.

- [ ] **Step 1: Write the failing test**  (append to `test/inline_renderer_test.dart`)
```dart
  test('xref type=9 external becomes a tappable link span and is recorded', () {
    final recs = <GestureRecognizer>[];
    final spans = builder(recognizers: recs)
        .build(el('<pkey><xref type="9" URL="https://x.org">site</xref></pkey>'), const TextStyle());
    final link = spans.whereType<TextSpan>().firstWhere((s) => s.text == 'site');
    expect(link.recognizer, isA<TapGestureRecognizer>());
    expect(link.style!.decoration, TextDecoration.underline);
    expect(recs, isNotEmpty);
  });

  test('xref internal known refid calls onXrefTap with paraId', () {
    int? tapped;
    String? gotPara;
    final spans = builder(
      titleForRefid: (r) => r == 99 ? 'Target' : null,
      onXrefTap: (r, {paraId}) {
        tapped = r;
        gotPara = paraId;
      },
    ).build(el('<pkey><xref type="17" RefID="99" paraID="p3">go</xref></pkey>'), const TextStyle());
    final link = spans.whereType<TextSpan>().firstWhere((s) => s.text == 'go');
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(tapped, 99);
    expect(gotPara, 'p3');
  });

  test('xref with refid absent from corpus renders plain text (no recognizer)', () {
    final recs = <GestureRecognizer>[];
    final spans = builder(recognizers: recs, titleForRefid: (r) => null)
        .build(el('<pkey><xref type="8" RefID="55555">missing</xref></pkey>'), const TextStyle());
    final s = spans.whereType<TextSpan>().firstWhere((x) => x.text == 'missing');
    expect(s.recognizer, isNull);
    expect(recs, isEmpty);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: `xref` currently falls through `default` → children rendered without recognizer.

- [ ] **Step 3: Write minimal implementation**
Add import at top of `inline_renderer.dart`:
```dart
import 'package:url_launcher/url_launcher.dart';
```
Add a case in `_element` (before `default`):
```dart
      case 'xref':
        return [_xref(el, base)];
```
Add the helper method to `InlineBuilder`:
```dart
  InlineSpan _xref(XmlElement el, TextStyle base) {
    final label = el.innerText;
    final type = int.tryParse(el.getAttribute('type') ?? '');
    final linkStyle = base.merge(theme.xrefStyle);

    // External link.
    if (type == 9) {
      final url = el.getAttribute('URL');
      if (url == null || url.isEmpty) return TextSpan(text: label, style: base);
      final r = TapGestureRecognizer()..onTap = () => unawaitedLaunch(url);
      recognizers.add(r);
      return TextSpan(text: label, style: linkStyle, recognizer: r);
    }

    // Internal link (all other types are RefID-bearing).
    final refid = int.tryParse(el.getAttribute('RefID') ?? '');
    if (refid == null) return TextSpan(text: label, style: base);
    if (titleForRefid(refid) == null) {
      // Dead link: refid absent from corpus -> plain text, no recognizer.
      return TextSpan(text: label, style: base);
    }
    final paraId = el.getAttribute('paraID');
    final r = TapGestureRecognizer()..onTap = () => onXrefTap(refid, paraId: paraId);
    recognizers.add(r);
    return TextSpan(text: label, style: linkStyle, recognizer: r);
  }

  void unawaitedLaunch(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      // Fire-and-forget; failures are swallowed (never crash the reader).
      launchUrl(uri).catchError((_) => false);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): xref external(url_launcher)/internal(onXrefTap)/dead-link"`

---

### Task 9: `inlinebmp` → WidgetSpan via AssetResolver (pass id + type through)

**Files:** Modify — `lib/src/inline_renderer.dart`. Test — `test/inline_renderer_test.dart` (add case).
**Interfaces:** Consumes: `AssetResolver assetResolver` (now `(String inlineId, int inlineType)`). Produces: `inlinebmp` branch in `_element`.

> Notes: `inlinebmp` (310 arts / 2,887 occ, attrs `type`,`id`; `type` 28/27/30; lines 55, 93–95). Per Unit 3 reconciliation, resolution depends on BOTH attributes (`type=27` → `id` is an asset baggage_id, resolvable; `type=28` → `id` is an original `NAME.DIB` filename, unresolvable → placeholder). The renderer parses the `id` attribute (**verbatim string**) and `type` attribute (as int) and passes BOTH to the injected `AssetResolver` WITHOUT interpreting them. The renderer never touches files; placeholder-on-miss is the resolver's job.

- [ ] **Step 1: Write the failing test**  (append to `test/inline_renderer_test.dart`)
```dart
  test('inlinebmp produces a WidgetSpan, passing id and type through verbatim', () {
    String? gotId;
    int? gotType;
    final spans = builder(assetResolver: (inlineId, inlineType) {
      gotId = inlineId;
      gotType = inlineType;
      return const Icon(Icons.image);
    }).build(el('<pkey><inlinebmp id="GLYPH.DIB" type="28"></inlinebmp></pkey>'), const TextStyle());
    expect(spans.whereType<WidgetSpan>(), hasLength(1));
    expect(gotId, 'GLYPH.DIB'); // verbatim id, not a stem
    expect(gotType, 28);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: `inlinebmp` falls through `default` → no WidgetSpan, resolver never called.

- [ ] **Step 3: Write minimal implementation**
Add a case in `_element` (before `default`):
```dart
      case 'inlinebmp':
        return [_inlineBmp(el)];
```
Add the helper to `InlineBuilder`:
```dart
  InlineSpan _inlineBmp(XmlElement el) {
    // Pass both attributes through verbatim; the host resolver interprets them
    // (type=27 -> id is a baggage_id; type=28 -> id is an original NAME.DIB).
    final id = el.getAttribute('id') ?? '';
    final type = int.tryParse(el.getAttribute('type') ?? '') ?? 0;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: assetResolver(id, type),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): inlinebmp -> WidgetSpan via AssetResolver(id, type)"`

---

### Task 10: `fs type=2` fraction layout

**Files:** Modify — `lib/src/inline_renderer.dart`. Test — `test/inline_renderer_test.dart` (add cases).
**Interfaces:** Consumes: `theme.fractionFontScale`. Produces: `fs` branch in `_element`.

> Notes: `fs` special inline (1,072 arts / 3,650 occ, attr `type`; `type=2` = numerator/denominator; lines 63). We render `type=2` as a stacked Column (numerator / hairline / denominator), splitting the inner text on `/`. If there is no `/` (or `type != 2`), fall back to plain inline text — never drop content. The split heuristic is a judgment call pending real-fixture confirmation (Self-review notes).

- [ ] **Step 1: Write the failing test**  (append to `test/inline_renderer_test.dart`)
```dart
  test('fs type=2 builds a stacked numerator/denominator fraction', () {
    final spans = builder().build(el('<pkey><fs type="2">1/2</fs></pkey>'), const TextStyle(fontSize: 16));
    final ws = spans.whereType<WidgetSpan>().single;
    expect(ws.child, isA<Column>());
    final texts = (ws.child as Column).children.whereType<Text>().map((t) => t.data).toList();
    expect(texts, <String>['1', '2']);
  });

  test('fs without a slash falls back to plain text (never dropped)', () {
    final spans = builder().build(el('<pkey><fs type="2">whole</fs></pkey>'), const TextStyle(fontSize: 16));
    expect(spans.whereType<TextSpan>().any((s) => s.text == 'whole'), isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: `fs` falls through `default` → no Column WidgetSpan.

- [ ] **Step 3: Write minimal implementation**
Add a case in `_element` (before `default`):
```dart
      case 'fs':
        return [_fraction(el, base)];
```
Add the helper to `InlineBuilder`:
```dart
  InlineSpan _fraction(XmlElement el, TextStyle base) {
    final text = el.innerText.trim();
    final slash = text.indexOf('/');
    if (slash < 0) return TextSpan(text: text, style: base); // not a fraction: keep text
    final numerator = text.substring(0, slash).trim();
    final denominator = text.substring(slash + 1).trim();
    final fr = base.copyWith(fontSize: (base.fontSize ?? 16) * theme.fractionFontScale);
    final ruleWidth =
        (numerator.length > denominator.length ? numerator.length : denominator.length) *
            (fr.fontSize ?? 12) *
            0.62;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(numerator, style: fr),
          Container(height: 1, width: ruleWidth, color: base.color ?? theme.foreground),
          Text(denominator, style: fr),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): fs type=2 stacked fraction layout"`

---

### Task 11: Rare inline tags `fl` `cq` `item` `notation` + unknown-tag debug highlight

**Files:** Modify — `lib/src/inline_renderer.dart`. Test — `test/inline_renderer_test.dart` (add cases).
**Interfaces:** Consumes: `theme.debugUnstyledTags`, `theme.debugUnstyledColor`. Produces: explicit rare-tag handling + debug highlight in `_element` `default`.

> Notes (VOCABULARY.md lines 64–67): `fl` rare inline format (23 / 71), `cq` (3 / 16, attr `para`), `item` (1 / 2, attr `pos`), `notation` (1 / 1, attr `type`). These have no known styling → render children with the inherited base style (graceful default). Truly-unknown tags also render children; when `theme.debugUnstyledTags` is on, highlight them with `debugUnstyledColor` so authors can spot gaps. "Never drop text."

- [ ] **Step 1: Write the failing test**  (append to `test/inline_renderer_test.dart`)
```dart
  test('rare inline tags render their text with default styling (never dropped)', () {
    final spans = builder().build(
      el('<pkey><fl>fl</fl><cq para="1">cq</cq><item pos="1">it</item><notation type="1">n</notation></pkey>'),
      const TextStyle(),
    );
    final joined = spans.whereType<TextSpan>().map((s) => s.text).join();
    expect(joined, allOf(contains('fl'), contains('cq'), contains('it'), contains('n')));
  });

  test('unknown tag children are rendered; debug mode highlights them', () {
    final plain = builder().build(el('<pkey><wibble>kept</wibble></pkey>'), const TextStyle());
    expect(plain.whereType<TextSpan>().any((s) => s.text == 'kept'), isTrue);

    final debugTheme = EncartaTheme.faithfulInSpirit().copyWith(debugUnstyledTags: true);
    final dbg = InlineBuilder(
      theme: debugTheme,
      assetResolver: (inlineId, inlineType) => const SizedBox.shrink(),
      onXrefTap: (r, {paraId}) {},
      titleForRefid: (r) => null,
      articleTitle: 'T',
      recognizers: <GestureRecognizer>[],
    ).build(el('<pkey><wibble>kept</wibble></pkey>'), const TextStyle());
    final s = dbg.whereType<TextSpan>().firstWhere((x) => x.text == 'kept');
    expect(s.style!.backgroundColor, debugTheme.debugUnstyledColor);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected FAIL: debug-mode case fails — `default` does not apply `debugUnstyledColor`.

- [ ] **Step 3: Write minimal implementation**
Replace the `default` branch in `_element` with explicit rare-tag handling + debug highlight:
```dart
      case 'fl':
      case 'cq':
      case 'item':
      case 'notation':
        // Known-rare, no special styling: render children with the inherited style.
        return build(el, base);
      default:
        // Unknown tag: never drop its text; optionally flag it in debug mode.
        if (theme.debugUnstyledTags) {
          return build(el, base.copyWith(backgroundColor: theme.debugUnstyledColor));
        }
        return build(el, base);
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/inline_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): rare inline fl/cq/item/notation + unstyled-tag debug highlight"`

---

### Task 12: BlockRenderer — prose blocks `pkey` `intro` `headline` `author` `quote` `example`

**Files:** Create — `packages/encarta_render/lib/src/block_renderer.dart`. Test — `packages/encarta_render/test/block_renderer_test.dart`.
**Interfaces:** Consumes: `EncartaTheme`, `InlineBuilder`. Produces: `class BlockRenderer { BlockRenderer({required EncartaTheme theme, required InlineBuilder inline}); Widget build(XmlElement el, {int depth = 0}); }` — later tasks add section/list/sec*/rule/br branches.

> Notes (VOCABULARY.md): `pkey` the dominant paragraph unit (100,071 arts / 703,294 occ, line 38), `intro` lead (2,695 / 2,706, line 41), `headline` (2,699 / 9,177, `type` 33/32/36/35/34, line 42), `author` byline (1,574 / 2,129, line 43), `quote` block quotation (739 / 2,600, `type` 30/27, line 45), `example` worked example (221 / 1,103, line 46). Each maps to a `Text.rich` of inline spans with its theme style.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/block_renderer_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_render/src/inline_renderer.dart';
import 'package:encarta_render/src/block_renderer.dart';

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;

BlockRenderer blocks() {
  final theme = EncartaTheme.faithfulInSpirit();
  final inline = InlineBuilder(
    theme: theme,
    assetResolver: (inlineId, inlineType) => const SizedBox.shrink(),
    onXrefTap: (r, {paraId}) {},
    titleForRefid: (r) => null,
    articleTitle: 'T',
    recognizers: <GestureRecognizer>[],
  );
  return BlockRenderer(theme: theme, inline: inline);
}

void main() {
  testWidgets('pkey/intro/headline/author/quote/example each render their text', (tester) async {
    final r = blocks();
    for (final tag in ['pkey', 'intro', 'headline', 'author', 'quote', 'example']) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: r.build(el('<$tag>Body of $tag</$tag>')))),
      );
      expect(find.textContaining('Body of $tag', findRichText: true), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected FAIL: `BlockRenderer` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/block_renderer.dart
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'encarta_theme.dart';
import 'inline_renderer.dart';

/// Maps block-level XML tags to vertical Flutter widgets. Structure only; all
/// pixels come from [theme].
class BlockRenderer {
  BlockRenderer({required this.theme, required this.inline});

  final EncartaTheme theme;
  final InlineBuilder inline;

  Widget build(XmlElement el, {int depth = 0}) {
    switch (el.name.local) {
      case 'pkey':
        return _prose(el, theme.body);
      case 'intro':
        return _prose(el, theme.intro);
      case 'headline':
        return _prose(el, theme.headlineDefault);
      case 'author':
        return _prose(el, theme.author);
      case 'quote':
        return _prose(el, theme.quote);
      case 'example':
        return _prose(el, theme.example);
      default:
        // Never drop text: render the unknown block as default-styled prose.
        return _prose(el, theme.body, debug: true);
    }
  }

  Widget _prose(XmlElement el, TextStyle style, {bool debug = false}) {
    final rich = Text.rich(TextSpan(style: style, children: inline.build(el, style)));
    if (debug && theme.debugUnstyledTags) {
      return Container(color: theme.debugUnstyledColor, child: rich);
    }
    return rich;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): BlockRenderer prose pkey/intro/headline/author/quote/example"`

---

### Task 13: BlockRenderer — `section` / `sectiontitle` nesting by `type` depth (4/5/6/7)

**Files:** Modify — `lib/src/block_renderer.dart`. Test — `test/block_renderer_test.dart` (add cases).
**Interfaces:** Produces: `section`/`sectiontitle` branches; `_depthForType` mapping; depth-based indent.

> Notes (VOCABULARY.md line 39): `section` nestable, `type` 6 (147k) / 4 (27k) / 7 (27k) / 5 (10k) = depth/kind. Map `type` → heading level: 4→1, 5→2, 6→3, 7→4 (drives `sectionTitleStyle`); visual indent grows with structural nesting `depth`. Type→level mapping is a judgment call (Self-review notes). `sectiontitle` rendered as its section's heading.

- [ ] **Step 1: Write the failing test**  (append to `test/block_renderer_test.dart`)
```dart
  testWidgets('section renders its title, nests children, and indents by depth', (tester) async {
    final r = blocks();
    final w = r.build(el(
      '<section type="4" id="s1"><sectiontitle>Title</sectiontitle><pkey>inside</pkey>'
      '<section type="5" id="s2"><sectiontitle>Deeper</sectiontitle><pkey>nested</pkey></section>'
      '</section>'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w))));
    expect(find.textContaining('Title', findRichText: true), findsOneWidget);
    expect(find.textContaining('inside', findRichText: true), findsOneWidget);
    expect(find.textContaining('Deeper', findRichText: true), findsOneWidget);
    expect(find.textContaining('nested', findRichText: true), findsOneWidget);
    // nested section is wrapped in extra Padding (indent)
    expect(find.byType(Padding), findsWidgets);
  });

  testWidgets('standalone sectiontitle renders as a heading', (tester) async {
    final r = blocks();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: r.build(el('<sectiontitle>Lonely</sectiontitle>')))));
    expect(find.textContaining('Lonely', findRichText: true), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected FAIL: `section`/`sectiontitle` hit `default` → nested `pkey`/title text collapses/duplicates incorrectly (no nesting, no `inside`/`Deeper` as separate widgets).

- [ ] **Step 3: Write minimal implementation**
Add cases in `build` (before `default`):
```dart
      case 'section':
        return _section(el, depth);
      case 'sectiontitle':
        return _prose(el, theme.sectionTitleStyle(depth == 0 ? 1 : depth));
```
Add helpers to `BlockRenderer`:
```dart
  int _depthForType(XmlElement section) {
    switch (int.tryParse(section.getAttribute('type') ?? '')) {
      case 4:
        return 1;
      case 5:
        return 2;
      case 6:
        return 3;
      case 7:
        return 4;
      default:
        return 1;
    }
  }

  Widget _section(XmlElement el, int depth) {
    final level = _depthForType(el);
    final children = <Widget>[];
    for (final child in el.childElements) {
      if (child.name.local == 'sectiontitle') {
        children.add(_prose(child, theme.sectionTitleStyle(level)));
      } else {
        children.add(build(child, depth: depth + 1));
      }
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(height: theme.blockSpacing));
    }
    final column = Column(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : theme.sectionIndentPerDepth),
      child: column,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): section/sectiontitle nesting + type-depth headings"`

---

### Task 14: BlockRenderer — `list` / `listitem` by `type`

**Files:** Modify — `lib/src/block_renderer.dart`. Test — `test/block_renderer_test.dart` (add cases).
**Interfaces:** Produces: `list` branch (`listitem` consumed within).

> Notes (VOCABULARY.md lines 44–45): `list` (3,296 / 8,567, `type` 1 = bulleted (7k) / 19 / 20), `listitem` child of list (3,296 / 60,755). `type=1` → bullet `•`; other types → ordered `1.`, `2.`, … Each item's content goes through the inline builder (may contain `i`/`xref`/etc.).

- [ ] **Step 1: Write the failing test**  (append to `test/block_renderer_test.dart`)
```dart
  testWidgets('list type=1 is bulleted; other list types are numbered', (tester) async {
    final r = blocks();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: r.build(el('<list type="1"><listitem>one</listitem><listitem>two</listitem></list>')))));
    expect(find.text('•'), findsNWidgets(2)); // bullet
    expect(find.textContaining('one', findRichText: true), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: r.build(el('<list type="19"><listitem>a</listitem><listitem>b</listitem></list>')))));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected FAIL: `list` hits `default` → no bullet/number markers.

- [ ] **Step 3: Write minimal implementation**
Add a case in `build` (before `default`):
```dart
      case 'list':
        return _list(el);
```
Add the helper to `BlockRenderer`:
```dart
  Widget _list(XmlElement el) {
    final type = int.tryParse(el.getAttribute('type') ?? '') ?? 1;
    final ordered = type != 1; // type 1 = bulleted; 19/20 = ordered
    final items = el.findElements('listitem').toList();
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final marker = ordered ? '${i + 1}.' : '•';
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: theme.blockSpacing / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, child: Text(marker, style: theme.listItem)),
            Expanded(
              child: Text.rich(TextSpan(style: theme.listItem, children: inline.build(items[i], theme.listItem))),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): list/listitem bulleted vs numbered by type"`

---

### Task 15: BlockRenderer — outline enumerators `sec` `seca` `secb` `secc` (I / A / B / C)

**Files:** Modify — `lib/src/block_renderer.dart`. Test — `test/block_renderer_test.dart` (add cases).
**Interfaces:** Produces: `sec`/`seca`/`secb`/`secc` branch with per-level indent.

> Notes (VOCABULARY.md lines 48–51): `sec` (5,661 / 58,346, e.g. "I"), `seca` (1,386 / 25,080, "A"), `secb` (437 / 5,541), `secc` (53 / 659). The element text IS the enumerator label (`<sec>I</sec>`); we style it via `theme.enumerator` and indent by level (sec=0, seca=1, secb=2, secc=3).

- [ ] **Step 1: Write the failing test**  (append to `test/block_renderer_test.dart`)
```dart
  testWidgets('sec/seca/secb/secc render their enumerator label, indented by level', (tester) async {
    final r = blocks();
    for (final entry in {'sec': 'I', 'seca': 'A', 'secb': 'B', 'secc': 'C'}.entries) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: r.build(el('<${entry.key}>${entry.value}</${entry.key}>')))));
      expect(find.textContaining(entry.value, findRichText: true), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected FAIL: `sec*` hit `default` (rendered as `theme.body` prose, not the dedicated enumerator widget with indent Padding around it). Assertion on `Padding` from `_enumerator` fails.

- [ ] **Step 3: Write minimal implementation**
Add cases in `build` (before `default`):
```dart
      case 'sec':
        return _enumerator(el, 0);
      case 'seca':
        return _enumerator(el, 1);
      case 'secb':
        return _enumerator(el, 2);
      case 'secc':
        return _enumerator(el, 3);
```
Add the helper to `BlockRenderer`:
```dart
  Widget _enumerator(XmlElement el, int level) {
    return Padding(
      padding: EdgeInsets.only(
        left: level * theme.sectionIndentPerDepth,
        top: 4,
        bottom: 2,
      ),
      child: Text.rich(TextSpan(style: theme.enumerator, children: inline.build(el, theme.enumerator))),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): outline enumerators sec/seca/secb/secc with per-level indent"`

---

### Task 16: BlockRenderer — `rule` divider + block-level `br`

**Files:** Modify — `lib/src/block_renderer.dart`. Test — `test/block_renderer_test.dart` (add cases).
**Interfaces:** Produces: `rule` and `br` branches.

> Notes (VOCABULARY.md lines 52–53): `rule` horizontal divider (2,688 / 3,402); `br` line break (6,318 / 43,745) — handled inline inside prose (Task 6), but a `br` appearing as a standalone top-level block renders as vertical spacing.

- [ ] **Step 1: Write the failing test**  (append to `test/block_renderer_test.dart`)
```dart
  testWidgets('rule renders a Divider; block-level br renders spacing', (tester) async {
    final r = blocks();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: r.build(el('<rule></rule>')))));
    expect(find.byType(Divider), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: r.build(el('<br></br>')))));
    expect(find.byType(SizedBox), findsWidgets);
  });
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected FAIL: `rule`/`br` hit `default` → no `Divider`/`SizedBox`.

- [ ] **Step 3: Write minimal implementation**
Add cases in `build` (before `default`):
```dart
      case 'rule':
        return Padding(
          padding: EdgeInsets.symmetric(vertical: theme.blockSpacing / 2),
          child: Divider(color: theme.ruleColor, height: 1, thickness: 1),
        );
      case 'br':
        return SizedBox(height: theme.blockSpacing);
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/block_renderer_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): rule divider + block-level br spacing"`

---

### Task 17: EncartaArticleBody widget — lazy builder + scroll anchors

**Files:** Create — `packages/encarta_render/lib/src/encarta_article_body.dart`. Modify — `lib/encarta_render.dart` (export). Test — `packages/encarta_render/test/encarta_article_body_test.dart`.
**Interfaces:** Consumes (LOCKED contract signature): `EncartaArticleBody({required EncartaDoc doc, required EncartaTheme theme, required AssetResolver assetResolver, required XrefTap onXrefTap, required TitleForRefid titleForRefid, ScrollController? controller})`. Produces: `EncartaArticleBodyState` (public) with `Future<void> scrollToAnchor(String anchorId)`.

> Notes (spec §5/§10): renders **lazily** over top-level blocks via `ListView.builder`; constrains to `theme.measure`; anchors every top-level block whose `id` is in `doc.allAnchorIds()` with a `GlobalKey` so the host can deep-link to a `paraID` or an outline `anchorId`. For an off-screen (un-built) lazy anchor, `scrollToAnchor` jumps to an index-proportional offset first, then `ensureVisible`. Recognizers created by `InlineBuilder` are disposed by this State.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/encarta_article_body_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  testWidgets('lists top-level blocks lazily and scrollToAnchor reaches off-screen anchors',
      (tester) async {
    final filler = List.generate(40, (i) => '<pkey id="g$i">Filler paragraph number $i here.</pkey>').join();
    final doc = EncartaDoc.parse(
      _b('<content><text><pkey id="p1">First</pkey>$filler<pkey id="last">LastPara</pkey></text></content>'),
      title: 'T',
    );
    final key = GlobalKey<EncartaArticleBodyState>();
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaArticleBody(
          key: key,
          doc: doc,
          theme: EncartaTheme.faithfulInSpirit(),
          assetResolver: (inlineId, inlineType) => const SizedBox.shrink(),
          onXrefTap: (r, {paraId}) {},
          titleForRefid: (r) => null,
          controller: controller,
        ),
      ),
    ));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.textContaining('First', findRichText: true), findsOneWidget);
    expect(find.textContaining('LastPara', findRichText: true), findsNothing); // off-screen, lazy

    await key.currentState!.scrollToAnchor('last');
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/encarta_article_body_test.dart`
Expected FAIL: `EncartaArticleBody`/`EncartaArticleBodyState` undefined.

- [ ] **Step 3: Write minimal implementation**
```dart
// packages/encarta_render/lib/src/encarta_article_body.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'callbacks.dart';
import 'block_renderer.dart';
import 'encarta_doc.dart';
import 'encarta_theme.dart';
import 'inline_renderer.dart';

/// Renders an [EncartaDoc] body lazily over its top-level blocks. Pure
/// presentation; reaches the outside world only via the injected callbacks.
class EncartaArticleBody extends StatefulWidget {
  const EncartaArticleBody({
    super.key,
    required this.doc,
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    this.controller,
  });

  final EncartaDoc doc;
  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final ScrollController? controller;

  @override
  State<EncartaArticleBody> createState() => EncartaArticleBodyState();
}

class EncartaArticleBodyState extends State<EncartaArticleBody> {
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _rebuildAnchors();
  }

  @override
  void didUpdateWidget(covariant EncartaArticleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.doc, widget.doc)) {
      _anchors.clear();
      _rebuildAnchors();
    }
  }

  void _rebuildAnchors() {
    for (final id in widget.doc.allAnchorIds()) {
      _anchors.putIfAbsent(id, () => GlobalKey());
    }
  }

  /// Scroll a section/paragraph anchor into view (outline click or paraID deep-link).
  Future<void> scrollToAnchor(String anchorId) async {
    final key = _anchors[anchorId];
    if (key == null) return;
    var ctx = key.currentContext;
    final controller = widget.controller;
    if (ctx == null && controller != null && controller.hasClients) {
      // Off-screen lazy item: jump to an index-proportional offset so it builds.
      final ids = widget.doc.blocks.map((b) => b.getAttribute('id')).toList();
      final idx = ids.indexOf(anchorId);
      if (idx >= 0 && ids.length > 1) {
        final pos = controller.position;
        final target = (pos.maxScrollExtent * (idx / (ids.length - 1)))
            .clamp(0.0, pos.maxScrollExtent);
        controller.jumpTo(target);
        await WidgetsBinding.instance.endOfFrame;
        ctx = key.currentContext;
      }
    }
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250), alignment: 0.05);
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers(); // drop last frame's recognizers before re-creating spans
    final inline = InlineBuilder(
      theme: widget.theme,
      assetResolver: widget.assetResolver,
      onXrefTap: widget.onXrefTap,
      titleForRefid: widget.titleForRefid,
      articleTitle: widget.doc.title,
      recognizers: _recognizers,
    );
    final blocks = BlockRenderer(theme: widget.theme, inline: inline);
    final top = widget.doc.blocks;

    return Container(
      color: widget.theme.background,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.theme.measure),
        child: ListView.builder(
          controller: widget.controller,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: top.length,
          itemBuilder: (context, i) {
            final el = top[i];
            Widget w = blocks.build(el);
            final id = el.getAttribute('id');
            if (id != null && _anchors.containsKey(id)) {
              w = KeyedSubtree(key: _anchors[id], child: w);
            }
            return Padding(
              padding: EdgeInsets.only(bottom: widget.theme.blockSpacing),
              child: w,
            );
          },
        ),
      ),
    );
  }
}
```
Add to `lib/encarta_render.dart`:
```dart
export 'src/encarta_article_body.dart';
```

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/encarta_article_body_test.dart`
Expected PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "feat(render): EncartaArticleBody lazy ListView + scroll anchors"`

---

### Task 18: Golden + widget test exercising ALL 32 tags + xref/inlinebmp callbacks

**Files:** Create — `packages/encarta_render/test/golden_all_tags_test.dart`, `packages/encarta_render/test/goldens/all_tags.png` (generated).
**Interfaces:** Consumes the full public API + fake callbacks. Produces: a committed golden reference and assertions that every tag renders and the `AssetResolver`/`inlinetitle` paths fire.

> Notes: this is the emphasis package's headline test. The fixture XML below contains **every one of the 32 tags** plus `xref` (external, internal-known, internal-with-paraID, dead) and `inlinebmp`. Fake callbacks record the `inlinebmp` `id`+`type` (passed through verbatim) and supply titles so internal xrefs are live. Golden is generated with `--update-goldens`, then re-run without it to confirm stability.

- [ ] **Step 1: Write the failing test**
```dart
// packages/encarta_render/test/golden_all_tags_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

const String _allTagsXml = '''
<content refid="42" revision="1"><text xml:space="preserve">
<intro id="i1">An <i>intro</i> about <inlinetitle></inlinetitle>.</intro>
<headline type="33" id="h1">A Headline</headline>
<author id="a1">By Jane Doe</author>
<pkey id="p1">Prose with <b>bold</b>, <u>under</u>, <smallcaps>SmallCaps</smallcaps>, H<sub>2</sub>O, E=mc<sup>2</sup>, fraction <fs type="2">1/2</fs>.<br></br>Line two.</pkey>
<pkey id="p2">Link <xref type="8" RefID="99">to Mercury</xref>, external <xref type="9" URL="https://example.org">site</xref>, deep <xref type="17" RefID="42" paraID="p1">para</xref>, dead <xref type="8" RefID="123456">link</xref>. Image <inlinebmp id="GLYPH.DIB" type="28"></inlinebmp>. Rare <fl>fl</fl> <cq para="1">cq</cq> <item pos="1">item</item> <notation type="1">n</notation>.</pkey>
<quote type="30">A block quotation.</quote>
<example id="e1">A worked example.</example>
<list type="1"><listitem>First item</listitem><listitem>Second item</listitem></list>
<rule></rule>
<section type="4" id="s1"><sectiontitle>Top Section</sectiontitle><sec>I</sec><pkey id="p3">Section prose.</pkey>
  <section type="5" id="s2"><sectiontitle>Sub Section</sectiontitle><seca>A</seca>
    <section type="6" id="s3"><sectiontitle>Sub-sub Section</sectiontitle><secb>1</secb>
      <section type="7" id="s4"><sectiontitle>Deepest Section</sectiontitle><secc>a</secc><pkey id="p4">Deep prose.</pkey></section>
    </section>
  </section>
</section>
</text></content>
''';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  testWidgets('golden: all 32 tags + xref + inlinebmp', (tester) async {
    final bmpIds = <String>[];
    final bmpTypes = <int>[];
    final taps = <int>[];
    final doc = EncartaDoc.parse(_b(_allTagsXml), title: 'The Sample Article');

    await tester.binding.setSurfaceSize(const Size(720, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: EncartaArticleBody(
          doc: doc,
          theme: EncartaTheme.faithfulInSpirit(),
          assetResolver: (inlineId, inlineType) {
            bmpIds.add(inlineId);
            bmpTypes.add(inlineType);
            return Container(width: 12, height: 12, color: const Color(0xFF888888));
          },
          onXrefTap: (refid, {paraId}) => taps.add(refid),
          titleForRefid: (refid) => refid == 99 ? 'Mercury' : (refid == 42 ? 'Self' : null),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Fake-callback wiring: inlinebmp passes id + type through verbatim.
    expect(bmpIds, contains('GLYPH.DIB'));
    expect(bmpTypes, contains(28));
    // inlinetitle substituted.
    expect(find.textContaining('The Sample Article', findRichText: true), findsOneWidget);
    // representative tags visible near the top of the scroll viewport.
    expect(find.textContaining('A Headline', findRichText: true), findsOneWidget);
    expect(find.textContaining('By Jane Doe', findRichText: true), findsOneWidget);

    await expectLater(
      find.byType(EncartaArticleBody),
      matchesGoldenFile('goldens/all_tags.png'),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
`cd packages/encarta_render && flutter test test/golden_all_tags_test.dart`
Expected FAIL: `Could not be compared against non-existent file .../goldens/all_tags.png` (golden not yet generated).

- [ ] **Step 3: Write minimal implementation**  (generate the golden — no lib change needed)
`cd packages/encarta_render && flutter test --update-goldens test/golden_all_tags_test.dart`
This writes `test/goldens/all_tags.png`. Inspect it visually: every tag's text must be present (headline, author, intro with substituted title, bold/underline/smallcaps/sub/sup, fraction, list bullets, rule divider, nested section headings, enumerators I/A/1/a, the grey inlinebmp box). If a tag is missing/wrong, fix the relevant renderer task before re-generating.

- [ ] **Step 4: Run test to verify it passes**
`cd packages/encarta_render && flutter test test/golden_all_tags_test.dart`
Expected PASS (golden now matches; callback + substitution assertions green).
Then run the whole suite: `cd packages/encarta_render && flutter test`
Expected: all tests PASS.

- [ ] **Step 5: Commit**
`git add packages/encarta_render && git commit -m "test(render): golden + widget coverage for all 32 tags, xref, inlinebmp"`

---

## Self-review notes

**Spec sections covered:** §3 (package boundary — `encarta_render` depends only on injected callbacks; no `dart:io`/SQLite), §5 (XML→widget tree, all 32 tags, never-drop-text, theme-decides-pixels), §8 (the in-package `EncartaTheme.faithfulInSpirit()` default), §10 (lazy body rendering, graceful degradation: dead xref → plain text, unknown tags → default-styled children).

**All 32 vocabulary tags covered (tag → task):**
`content` T4 · `text` T4 · `pkey` T12 · `section` T13 · `sectiontitle` T13 (+outline T5) · `intro` T12 · `headline` T12 · `author` T12 · `list` T14 · `listitem` T14 · `quote` T12 · `example` T12 · `sec` T15 · `seca` T15 · `secb` T15 · `secc` T15 · `rule` T16 · `br` T6 (inline) + T16 (block) · `xref` T8 · `inlinebmp` T9 · `inlinetitle` T7 · `i` T6 · `b` T6 · `u` T6 · `smallcaps` T6 · `sub` T6 · `sup` T6 · `fs` T10 · `fl` T11 · `cq` T11 · `item` T11 · `notation` T11. (32/32.)

**Verified-at-runtime assumptions / judgment calls (confirm against real corpus during implementation):**
1. **`<text>` fallback:** ~16k bodies lack a `<text>` wrapper (100,074/116,119 have it); parse falls back to `<content>` children. Confirm no body nests `<text>` deeper than one level.
2. **`fs type=2` split heuristic:** assumed numerator/denominator separated by `/` in the inner text. If real fixtures use child elements (e.g. nested runs) instead, extend `_fraction` — current code never drops text (falls back to plain inline) so it degrades safely.
3. **`section type` → heading level** mapping (4→1, 5→2, 6→3, 7→4): `type` is documented as "depth/kind" but the exact semantics are unconfirmed; outline `depth` uses true nesting (reliable) while only the heading *style* uses this map. Adjust the map if visual inspection of the golden shows inversion.
4. **`headline type` 33/32/36/35/34** collapse to one `headlineDefault` style — refine if subtypes prove visually distinct.
5. **`xref` subtypes 10/11/14/15/16/17** all render as internal links (per VOCABULARY.md line 86); labels can be refined if a media/sidebar/dictionary distinction emerges.
6. **`sub`/`sup`** use `WidgetSpan` + `Transform.translate` (true OpenType `subs`/`sups` features aren't reliably available across fonts); visually validated via the golden.
7. **`smallcaps`** uses `FontFeature.enableFeature('smcp')`; renders only if the active font ships small-caps glyphs — acceptable for the faithful-in-spirit target (falls back to normal caps otherwise).
8. **Recognizer disposal:** `EncartaArticleBodyState` disposes the previous frame's `TapGestureRecognizer`s at the start of `build`; correct under Flutter's build-then-paint ordering. If a future change retains spans across frames, move disposal to `didUpdateWidget`/`reassemble`.
