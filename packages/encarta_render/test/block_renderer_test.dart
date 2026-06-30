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

  // Verifies that each prose block tag is wired to its expected theme style, not just
  // that text appears. Distinguishing properties chosen so any wrong mapping fails:
  //   pkey   → body:           fontSize=16, fontStyle=null, fontWeight=null, color=0xFF1A1A1A
  //   intro  → intro:          fontSize=18, fontWeight=w500
  //   headline→headlineDefault: fontSize=22, fontWeight=w700
  //   author → author:         fontSize=14, fontStyle=italic, color=0xFF555555
  //   quote  → quote:          fontSize=16, fontStyle=italic, color=0xFF333333
  //   example→ example:        fontSize=15
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

  testWidgets('prose block TextStyle matches expected theme style per tag', (tester) async {
    final theme = EncartaTheme.faithfulInSpirit();

    // (tag, expectedStyle) — we read style directly from the root TextSpan of the
    // resulting RichText and compare key distinguishing properties.
    final cases = <(String, TextStyle)>[
      ('pkey',     theme.body),
      ('intro',    theme.intro),
      ('headline', theme.headlineDefault),
      ('author',   theme.author),
      ('quote',    theme.quote),
      ('example',  theme.example),
    ];

    for (final (tag, expected) in cases) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: blocks().build(el('<$tag>Body of $tag</$tag>')))),
      );

      // Text.rich → RichText; read the style that _prose sets.
      // Filter by text content to avoid matching internal MaterialApp RichText widgets.
      // IMPORTANT: Text.rich wraps our TextSpan inside a DefaultTextStyle TextSpan, so
      // richText.text = TextSpan(style: DefaultTextStyle, children: [ourSpan]).
      // Our theme style is at children[0], NOT at richText.text.style.
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Body of $tag'),
        ),
      );
      final rootSpan = richText.text as TextSpan;
      final ourSpan = rootSpan.children!.first as TextSpan;
      final actual = ourSpan.style!;

      expect(actual.fontSize, equals(expected.fontSize),
          reason: '<$tag> fontSize mismatch: expected ${expected.fontSize}');
      expect(actual.fontStyle, equals(expected.fontStyle),
          reason: '<$tag> fontStyle mismatch: expected ${expected.fontStyle}');
      expect(actual.fontWeight, equals(expected.fontWeight),
          reason: '<$tag> fontWeight mismatch: expected ${expected.fontWeight}');
      expect(actual.color, equals(expected.color),
          reason: '<$tag> color mismatch: expected ${expected.color}');
    }
  });
}
