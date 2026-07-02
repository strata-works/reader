import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_reader/src/data/snippet.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List xml(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('strips tags and windows around the first query hit', () {
    final body = xml(
      '<content><text><pkey>The <i>quantum</i> theory of '
      'photosynthesis is complex.</pkey></text></content>',
    );
    final s = makeSnippet(body, 'photosynthesis', radius: 20);
    expect(s, contains('photosynthesis'));
    expect(s, isNot(contains('<')));
    expect(s, contains('…'));
  });

  test('falls back to the leading text when query is absent', () {
    final body = xml('<content><text><pkey>Alpha beta gamma.</pkey></text></content>');
    final s = makeSnippet(body, 'zzz', radius: 100);
    expect(s, startsWith('Alpha beta gamma'));
  });

  test('collapses whitespace and is case-insensitive', () {
    final body = xml('<pkey>Big   Bang\n\ncosmology</pkey>');
    final s = makeSnippet(body, 'bang', radius: 10);
    expect(s, contains('Bang'));
    expect(s, isNot(contains('\n')));
  });
}
