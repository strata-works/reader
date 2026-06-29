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
}
