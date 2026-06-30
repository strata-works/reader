// packages/encarta_render/test/golden_all_tags_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
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

/// Walk an [InlineSpan] tree depth-first and return the first [TextSpan] whose
/// [TextSpan.text] property equals [target], or null if none is found.
/// Only the leaf [text] field is compared — children-only spans are skipped
/// so that parent wrapper spans don't accidentally match.
TextSpan? _findSpanWithText(InlineSpan root, String target) {
  if (root is TextSpan) {
    if (root.text == target) return root;
    for (final child in root.children ?? const <InlineSpan>[]) {
      final found = _findSpanWithText(child, target);
      if (found != null) return found;
    }
  }
  return null;
}

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

    // -----------------------------------------------------------------------
    // inlinebmp: use equals so a spurious extra call would fail
    // (exactly one <inlinebmp> in the fixture).
    // -----------------------------------------------------------------------
    expect(bmpIds, equals(['GLYPH.DIB']));
    expect(bmpTypes, equals([28]));

    // -----------------------------------------------------------------------
    // Tag content assertions (pre-existing 3 + 5 more distinct tags)
    // -----------------------------------------------------------------------
    // inlinetitle substituted.
    expect(find.textContaining('The Sample Article', findRichText: true), findsOneWidget);
    // headline
    expect(find.textContaining('A Headline', findRichText: true), findsOneWidget);
    // author
    expect(find.textContaining('By Jane Doe', findRichText: true), findsOneWidget);
    // b (bold run inside pkey p1)
    expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    // quote
    expect(find.textContaining('A block quotation.', findRichText: true), findsOneWidget);
    // listitem
    expect(find.textContaining('First item', findRichText: true), findsOneWidget);
    // sectiontitle
    expect(find.textContaining('Top Section', findRichText: true), findsOneWidget);
    // sec enumerator: the <sec>I</sec> block renders as a RichText whose full
    // plain text is exactly "I" — use find.text for an exact match.
    expect(find.text('I', findRichText: true), findsOneWidget);

    // -----------------------------------------------------------------------
    // Dead-vs-live xref distinction
    // Walk every RichText span tree to locate:
    //   • liveSpan — "to Mercury" (RefID=99, titleForRefid→'Mercury'): must
    //     carry a TapGestureRecognizer that fires onXrefTap(99).
    //   • deadSpan — "link"  (RefID=123456, titleForRefid→null): must render
    //     as plain text with NO recognizer.
    // -----------------------------------------------------------------------
    TextSpan? liveSpan;
    TextSpan? deadSpan;
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      liveSpan ??= _findSpanWithText(rt.text, 'to Mercury');
      deadSpan ??= _findSpanWithText(rt.text, 'link');
      if (liveSpan != null && deadSpan != null) break;
    }

    expect(liveSpan, isNotNull, reason: 'live xref "to Mercury" must render');
    expect(
      liveSpan!.recognizer,
      isNotNull,
      reason: 'live xref (RefID=99, known title) must carry a tap recognizer',
    );
    expect(deadSpan, isNotNull, reason: 'dead xref "link" must render as plain text');
    expect(
      deadSpan!.recognizer,
      isNull,
      reason: 'dead xref (RefID=123456, unknown title) must NOT have a recognizer',
    );

    // Fire the live-xref recognizer directly (avoids hit-test pixel arithmetic)
    // and assert the host callback recorded the correct refid.
    (liveSpan.recognizer! as TapGestureRecognizer).onTap!();
    expect(taps, equals([99]));

    await expectLater(
      find.byType(EncartaArticleBody),
      matchesGoldenFile('goldens/all_tags.png'),
    );
  });
}
