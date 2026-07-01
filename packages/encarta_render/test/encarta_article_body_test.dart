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

    // Capture the future WITHOUT awaiting it first — awaiting before pumping
    // would deadlock because the post-frame callback never fires until a frame
    // is pumped.
    final scrollFuture = key.currentState!.scrollToAnchor('last');
    // Drive the post-frame callback and any scroll animation to completion.
    await tester.pumpAndSettle();
    // The future is already complete at this point; await it to surface errors.
    await scrollFuture;
    expect(controller.offset, greaterThan(0));
  });

  testWidgets(
      'scrollToAnchor reaches a NESTED anchor (sub-section) that is off-screen',
      (tester) async {
    // Build a doc with 40 filler top-level pkeys to push the outer section
    // off-screen, then a top-level section containing a nested section with
    // id "deep". The nested section should be scrollable via scrollToAnchor.
    final filler =
        List.generate(40, (i) => '<pkey id="f$i">Filler $i.</pkey>').join();
    final doc = EncartaDoc.parse(
      _b(
        '<content><text>'
        '$filler'
        '<section type="4" id="outer"><sectiontitle>Outer</sectiontitle>'
        '<section type="5" id="deep"><sectiontitle>DeepSection</sectiontitle>'
        '<pkey id="dp1">Deep content here.</pkey>'
        '</section>'
        '</section>'
        '</text></content>',
      ),
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

    // The nested section title must be off-screen initially (lazy list + filler).
    expect(
      find.textContaining('DeepSection', findRichText: true),
      findsNothing,
      reason: 'Deep section should be off-screen before scrolling',
    );

    // Capture the future first; do NOT await before pumping.
    final scrollFuture = key.currentState!.scrollToAnchor('deep');
    // Drive the post-frame jump + ensureVisible animation to completion.
    await tester.pumpAndSettle();
    await scrollFuture;

    // The nested section title must now be visible on screen.
    expect(
      find.textContaining('DeepSection', findRichText: true),
      findsOneWidget,
      reason: 'Deep section should be visible after scrollToAnchor("deep")',
    );
  });
}
