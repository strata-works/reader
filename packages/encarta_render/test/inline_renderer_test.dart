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
        contains(const FontFeature.enable('smcp')));
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

  test('nested inline: <i>a<b>b</b></i> produces italic a and bold+italic b', () {
    final spans = builder().build(
      el('<pkey><i>a<b>b</b></i></pkey>'),
      const TextStyle(fontSize: 14),
    );
    final texts = spans.whereType<TextSpan>().toList();
    final italic = texts.firstWhere((s) => s.text == 'a');
    expect(italic.style!.fontStyle, FontStyle.italic);
    final boldItalic = texts.firstWhere((s) => s.text == 'b');
    expect(boldItalic.style!.fontStyle, FontStyle.italic);
    expect(boldItalic.style!.fontWeight, FontWeight.bold);
  });

  test('unknown tag renders its children with the inherited style (never drops text)', () {
    final spans = builder().build(
      el('<pkey><weirdtag>visible</weirdtag></pkey>'),
      const TextStyle(fontSize: 12),
    );
    final texts = spans.whereType<TextSpan>().toList();
    expect(texts.any((s) => s.text == 'visible'), isTrue);
    expect(texts.firstWhere((s) => s.text == 'visible').style!.fontSize, 12);
  });

  test('inlinetitle substitutes the injected article title', () {
    final spans = builder(title: 'Mercury (planet)')
        .build(el('<pkey>See <inlinetitle></inlinetitle> now</pkey>'), const TextStyle());
    expect(spans.whereType<TextSpan>().any((s) => s.text == 'Mercury (planet)'), isTrue);
  });
}
