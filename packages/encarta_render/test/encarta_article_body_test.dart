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
}
