import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/search/search_page.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _xml(String s) => Uint8List.fromList(utf8.encode('<pkey>$s</pkey>'));

void main() {
  test('builds ranked results with our snippet, tier badge and thumb', () async {
    final data = await buildSearchViewData(
      query: 'mars',
      offset: 0,
      limit: 25,
      search: (q, {limit = 25, offset = 0}) async =>
          const [SearchHit(refid: 1, title: 'Mars', rank: -2.1)],
      getArticle: (id) async => Article(
        refid: id,
        title: 'Mars',
        source: 'CONTDLX',
        xmlBytes: _xml('Mars is the fourth planet.'),
      ),
      mediaForArticle: (_) async => const [
        MediaItem(
          mediaRefid: 9,
          role: 'thumb',
          group: 'article',
          title: null,
          caption: null,
          credit: null,
          assetPath: 'image/x.jpg',
          ext: 'jpg',
          kind: 'image',
        ),
      ],
    );

    expect(data.results.single.title, 'Mars');
    expect(data.results.single.tierBadge, 'Deluxe');
    expect(data.results.single.snippet, contains('Mars'));
    expect(data.results.single.thumb!.role, 'thumb');
    expect(data.hasMore, isFalse);
  });

  test('hasMore is true when a full page is returned', () async {
    final hits = List.generate(
        25, (i) => SearchHit(refid: i, title: 'T$i', rank: -i.toDouble()));
    final data = await buildSearchViewData(
      query: 'x',
      offset: 0,
      limit: 25,
      search: (q, {limit = 25, offset = 0}) async => hits,
      getArticle: (id) async =>
          Article(refid: id, title: 'T$id', source: 'CONTSTD', xmlBytes: _xml('x')),
      mediaForArticle: (_) async => const [],
    );
    expect(data.hasMore, isTrue);
  });

  // Task 22: probe (449 articles) showed ticon avg 247 B tiny .gif placeholders
  // vs picon avg 1981 B real .jtn images → picon is preferred over ticon.
  test('picon is chosen over ticon when both present (confirmed Task 22)', () async {
    final data = await buildSearchViewData(
      query: 'mars',
      offset: 0,
      limit: 25,
      search: (q, {limit = 25, offset = 0}) async =>
          const [SearchHit(refid: 1, title: 'Mars', rank: -2.1)],
      getArticle: (id) async => Article(
        refid: id,
        title: 'Mars',
        source: 'CONTDLX',
        xmlBytes: _xml('Mars is the fourth planet.'),
      ),
      mediaForArticle: (_) async => const [
        MediaItem(
          mediaRefid: 10,
          role: 'picon',
          group: 'article',
          title: null,
          caption: null,
          credit: null,
          assetPath: 'image/picon.jpg',
          ext: 'jpg',
          kind: 'image',
        ),
        MediaItem(
          mediaRefid: 11,
          role: 'ticon',
          group: 'article',
          title: null,
          caption: null,
          credit: null,
          assetPath: 'image/ticon.jpg',
          ext: 'jpg',
          kind: 'image',
        ),
      ],
    );

    expect(data.results.single.thumb!.role, 'picon',
        reason: 'picon (real ~1981 B images) beats ticon (tiny ~247 B placeholder gifs)');
  });
}
