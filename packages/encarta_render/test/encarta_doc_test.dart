import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('parse walks content -> text -> blocks and keeps the injected title', () {
    final doc = EncartaDoc.parse(
      _b('<content refid="1" revision="1"><text xml:space="preserve">'
         '<pkey id="p1">Hello</pkey><pkey id="p2">World</pkey></text></content>'),
      title: 'My Title',
    );
    expect(doc.title, 'My Title');
    expect(doc.blocks.length, 2);
    expect(doc.blocks.first.name.local, 'pkey');
    expect(doc.blocks.first.getAttribute('id'), 'p1');
    expect(doc.allAnchorIds(), containsAll(<String>['p1', 'p2']));
  });

  test('parse falls back to <content> children when <text> is absent', () {
    final doc = EncartaDoc.parse(
      _b('<content refid="2" revision="1"><pkey id="x">Body</pkey></content>'),
      title: 'T',
    );
    expect(doc.blocks.single.name.local, 'pkey');
  });

  test('parse degrades gracefully on malformed/empty XML', () {
    expect(
      () => EncartaDoc.parse(_b(''), title: 'Bad'),
      returnsNormally,
    );
    final doc = EncartaDoc.parse(_b(''), title: 'Bad');
    expect(doc.blocks, isEmpty);
  });

  test('outline captures nested sectiontitles with 1-based depth and anchors', () {
    final doc = EncartaDoc.parse(
      _b('<content><text>'
         '<section type="4" id="s1"><sectiontitle>Top</sectiontitle>'
         '<pkey id="p1">body</pkey>'
         '<section type="5" id="s2"><sectiontitle>Sub</sectiontitle></section>'
         '</section></text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries.map((e) => e.title).toList(), <String>['Top', 'Sub']);
    expect(doc.outline.entries.map((e) => e.depth).toList(), <int>[1, 2]);
    expect(doc.outline.entries.first.anchorId, 's1');
  });

  test('outline skips sections without a sectiontitle', () {
    final doc = EncartaDoc.parse(
      _b('<content><text><section type="4" id="s1"></section></text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries, isEmpty);
  });

  // Finding 1: every anchorId in the outline must be resolvable via allAnchorIds().
  test('every outline anchorId is present in allAnchorIds (mixed real/synthetic)', () {
    final doc = EncartaDoc.parse(
      _b('<content><text>'
         '<section type="4" id="s1"><sectiontitle>Real ID</sectiontitle></section>'
         '<section type="5"><sectiontitle>Synthetic ID</sectiontitle></section>'
         '</text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries.length, 2);
    final anchors = doc.allAnchorIds().toSet();
    for (final entry in doc.outline.entries) {
      expect(anchors, contains(entry.anchorId),
          reason: 'anchorId "${entry.anchorId}" not found in allAnchorIds()');
    }
  });

  // Finding 3: a titleless parent section must still count as a nesting level.
  test('titleless parent section depth still counts for titled child', () {
    final doc = EncartaDoc.parse(
      _b('<content><text>'
         '<section type="4">'
         '  <section type="5" id="c1"><sectiontitle>Child</sectiontitle></section>'
         '</section></text></content>'),
      title: 'T',
    );
    expect(doc.outline.entries.length, 1);
    expect(doc.outline.entries.first.title, 'Child');
    expect(doc.outline.entries.first.anchorId, 'c1');
    expect(doc.outline.entries.first.depth, 2);
  });
}
