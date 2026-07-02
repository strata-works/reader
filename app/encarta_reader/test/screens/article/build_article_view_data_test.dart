import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:encarta_reader/src/screens/article/article_page.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _xml() => Uint8List.fromList(utf8.encode(
      '<content><text><pkey>Body text.</pkey></text></content>',
    ));

void main() {
  test('assembles data, applies title fallback, seeds title cache', () async {
    final titles = ArticleTitleCache(fetch: (_) async => null);

    final data = await buildArticleViewData(
      refid: 3,
      getArticle: (id) async =>
          Article(refid: id, title: '', source: 'CONTSTD', xmlBytes: _xml()),
      mediaForArticle: (_) async => const [],
      outboundXrefs: (_) async =>
          const [XrefTarget(targetRefid: 9, title: 'Gravity')],
      titles: titles,
    );

    expect(data, isNotNull);
    expect(data!.related.single.title, 'Gravity');
    expect(titles.cached(9), 'Gravity'); // seeded for titleForRefid
    expect(data.title, 'Article 3'); // empty DB title → refid fallback
  });

  test('returns null when the article is absent', () async {
    final titles = ArticleTitleCache(fetch: (_) async => null);
    final data = await buildArticleViewData(
      refid: 404,
      getArticle: (_) async => null,
      mediaForArticle: (_) async => const [],
      outboundXrefs: (_) async => const [],
      titles: titles,
    );
    expect(data, isNull);
  });
}
