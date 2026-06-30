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
