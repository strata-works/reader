import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/screens/article/article_view.dart';
import 'package:encarta_reader/src/screens/article/article_outline_pane.dart';
import 'package:encarta_reader/src/screens/article/media_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EncartaDoc _doc() => EncartaDoc.parse(
      Uint8List.fromList(utf8.encode(
        '<content><text><pkey>Hello world.</pkey></text></content>',
      )),
      title: 'Test',
    );

/// A tall doc: 40 filler pkeys followed by a section with a nested section
/// id="deep" at the bottom. Callers can use paraId='deep' to test scrolling.
EncartaDoc _tallDocWithDeepAnchor() => EncartaDoc.parse(
      Uint8List.fromList(utf8.encode(
        '<content><text>'
        '${List.generate(40, (i) => '<pkey id="f$i">Filler $i.</pkey>').join()}'
        '<section type="4" id="outer"><sectiontitle>Outer</sectiontitle>'
        '<section type="5" id="deep"><sectiontitle>DeepSection</sectiontitle>'
        '<pkey id="dp1">Deep content.</pkey>'
        '</section>'
        '</section>'
        '</text></content>',
      )),
      title: 'Tall',
    );

ArticleViewData _data({
  List<XrefTarget> related = const [],
  List<MediaItem> media = const [],
}) =>
    ArticleViewData(
      doc: _doc(),
      outline: const EncartaOutline(entries: [
        OutlineEntry(title: 'Intro', anchorId: 'a1', depth: 0),
      ]),
      title: 'Test',
      source: 'CONTDLX',
      related: related,
      media: media,
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

  testWidgets('tapping a related link fires onRelatedTap', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleView(
          data: _data(
            related: const [XrefTarget(targetRefid: 42, title: 'Mars')],
          ),
          theme: EncartaTheme.faithfulInSpirit(),
          assetResolver: (id, type) => const Icon(Icons.image),
          onXrefTap: (refid, {paraId}) {},
          titleForRefid: (_) => null,
          onRelatedTap: (refid) => tapped = refid,
        ),
      ),
    ));

    await tester.tap(find.text('Mars'));
    await tester.pump();

    expect(tapped, 42);
  });

  testWidgets('tapping outline entry triggers scrollToAnchor without error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleView(
          data: _data(),
          theme: EncartaTheme.faithfulInSpirit(),
          assetResolver: (id, type) => const Icon(Icons.image),
          onXrefTap: (refid, {paraId}) {},
          titleForRefid: (_) => null,
          onRelatedTap: (_) {},
        ),
      ),
    ));

    // Tap "Intro" in the outline pane — wired to scrollToAnchor('a1').
    // 'a1' is not a block anchor in this doc so scrollToAnchor returns immediately.
    await tester.tap(find.text('Intro'));
    await tester.pumpAndSettle();
    // Reaching here without exception means the GlobalKey wiring is correct.
  });

  testWidgets(
      'body content is width-capped at theme.measure in a wide viewport',
      (tester) async {
    final theme = EncartaTheme.faithfulInSpirit();

    // Use a wide surface so the center column would stretch without the cap.
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleView(
          data: _data(),
          theme: theme,
          assetResolver: (id, type) => const Icon(Icons.image),
          onXrefTap: (refid, {paraId}) {},
          titleForRefid: (_) => null,
          onRelatedTap: (_) {},
        ),
      ),
    ));

    // There must be a ConstrainedBox whose maxWidth is exactly theme.measure.
    final measureBox = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .firstWhere((b) => b.constraints.maxWidth == theme.measure);
    expect(measureBox.constraints.maxWidth, theme.measure);

    // The rendered EncartaArticleBody must not exceed the measure.
    final bodySize = tester.getSize(find.byType(EncartaArticleBody));
    expect(bodySize.width, lessThanOrEqualTo(theme.measure));
  });

  group('paraId deep-link', () {
    testWidgets(
        'ArticleView with paraId scrolls the target anchor into view after build',
        (tester) async {
      // Use a tall viewport so the deep section starts off-screen.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doc = _tallDocWithDeepAnchor();
      final data = ArticleViewData(
        doc: doc,
        outline: EncartaOutline(entries: [
          OutlineEntry(title: 'Outer', anchorId: 'outer', depth: 1),
          OutlineEntry(title: 'DeepSection', anchorId: 'deep', depth: 2),
        ]),
        title: 'Tall',
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
            paraId: 'deep',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // After pumpAndSettle the post-frame callback and ensureVisible have run;
      // the deep section's body pkey should now be visible (it only appears in
      // the article body, NOT in the outline pane, so findsOneWidget is reliable).
      expect(
        find.textContaining('Deep content.', findRichText: true),
        findsOneWidget,
        reason: 'paraId=deep should scroll the deep section body into view',
      );
    });

    testWidgets('changing paraId re-triggers scrollToAnchor', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doc = _tallDocWithDeepAnchor();
      final data = ArticleViewData(
        doc: doc,
        outline: EncartaOutline(entries: [
          OutlineEntry(title: 'Outer', anchorId: 'outer', depth: 1),
          OutlineEntry(title: 'DeepSection', anchorId: 'deep', depth: 2),
        ]),
        title: 'Tall',
        source: 'CONTDLX',
        related: const [],
        media: const [],
      );

      String? currentParaId;
      late StateSetter setSt;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setSt = setState;
              return ArticleView(
                data: data,
                theme: EncartaTheme.faithfulInSpirit(),
                assetResolver: (id, type) => const Icon(Icons.image),
                onXrefTap: (refid, {paraId}) {},
                titleForRefid: (_) => null,
                onRelatedTap: (_) {},
                paraId: currentParaId,
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 'Deep content.' is the pkey inside the nested section — only rendered
      // when the section is scrolled into view. The outline shows section titles
      // (not pkey content) so this check is unambiguous.
      expect(
        find.textContaining('Deep content.', findRichText: true),
        findsNothing,
        reason: 'Deep section body should be off-screen before any paraId scroll',
      );

      // Change paraId to 'deep' to trigger didUpdateWidget → _scheduleParaIdScroll.
      setSt(() => currentParaId = 'deep');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Deep content.', findRichText: true),
        findsOneWidget,
        reason: 'Updating paraId to "deep" should scroll the deep section body into view',
      );
    });
  });

  group('media rail', () {
    late Directory root;
    late EncartaAssets assets;

    setUp(() {
      root = Directory.systemTemp
          .createTempSync('encarta_reader_article_view');
      assets = EncartaAssets.forTesting(AssetConfig(root.path));
    });
    tearDown(() => root.deleteSync(recursive: true));

    testWidgets('renders MediaRail when media items are present',
        (tester) async {
      final media = [
        const MediaItem(
          mediaRefid: 1,
          role: 'image',
          group: 'article',
          title: 'Earth',
          caption: 'Our planet',
          credit: 'NASA',
          assetPath: 'image/earth.jpg',
          ext: '.jpg',
          kind: 'image',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ArticleView(
            data: _data(media: media),
            theme: EncartaTheme.faithfulInSpirit(),
            assetResolver: (id, type) => const Icon(Icons.image),
            onXrefTap: (refid, {paraId}) {},
            titleForRefid: (_) => null,
            onRelatedTap: (_) {},
            assets: assets,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MediaRail), findsOneWidget);
    });
  });
}
