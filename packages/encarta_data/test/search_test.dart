import 'dart:convert';

import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

const fixturePath = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  late EncartaDb db;
  setUp(() async => db = await EncartaDb.open(fixturePath));
  tearDown(() => db.close());

  test('search returns ranked hits whose refids resolve to real articles', () async {
    // Derive a guaranteed-present token from the first fixture article's body.
    final refid = await db.firstTitledRefid();
    final article = (await db.getArticle(refid))!;
    final body = utf8.decode(article.xmlBytes, allowMalformed: true);
    final token = RegExp(r'[A-Za-z]{5,}')
        .allMatches(body)
        .map((m) => m.group(0)!)
        .first;

    final hits = await db.search(token, limit: 10);
    expect(hits, isNotEmpty);
    // Each hit maps to a loadable article (rowid==refid invariant in practice).
    final first = await db.getArticle(hits.first.refid);
    expect(first, isNotNull);
    // Results are sorted by bm25 ascending (more relevant first).
    for (var i = 1; i < hits.length; i++) {
      expect(hits[i].rank, greaterThanOrEqualTo(hits[i - 1].rank));
    }
  });

  test('search paginates with limit/offset', () async {
    final page1 = await db.search('a', limit: 2, offset: 0);
    final page2 = await db.search('a', limit: 2, offset: 2);
    expect(page1.length, lessThanOrEqualTo(2));
    final overlap = page1.map((h) => h.refid).toSet()
      ..retainAll(page2.map((h) => h.refid).toSet());
    expect(overlap, isEmpty);
  });
}
