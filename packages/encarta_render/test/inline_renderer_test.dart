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

  test('xref type=9 without URL renders plain text (no recognizer)', () {
    final recs = <GestureRecognizer>[];
    final spans = builder(recognizers: recs)
        .build(el('<pkey><xref type="9">nolink</xref></pkey>'), const TextStyle());
    final s = spans.whereType<TextSpan>().firstWhere((x) => x.text == 'nolink');
    expect(s.recognizer, isNull);
    expect(recs, isEmpty);
  });

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

  test('fs with non-2 type falls back to plain text (never dropped)', () {
    final spans = builder().build(el('<pkey><fs type="5">1/2</fs></pkey>'), const TextStyle(fontSize: 16));
    // Should not produce a WidgetSpan; content must appear as text
    expect(spans.whereType<WidgetSpan>(), isEmpty);
    expect(spans.whereType<TextSpan>().any((s) => s.text == '1/2'), isTrue);
  });
}
