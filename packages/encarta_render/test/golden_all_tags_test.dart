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
