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
