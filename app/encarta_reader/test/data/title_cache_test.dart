import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/data/title_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached() returns seeded titles synchronously', () {
    final c = ArticleTitleCache(fetch: (_) async => null);
    c.seed(7, 'Photosynthesis');
    expect(c.cached(7), 'Photosynthesis');
    expect(c.cached(8), isNull);
  });

  test('seedXrefs / seedTitles populate the cache', () {
    final c = ArticleTitleCache(fetch: (_) async => null);
    c.seedXrefs(const [XrefTarget(targetRefid: 1, title: 'Atom')]);
    c.seedTitles(const [TitleRef(refid: 2, title: 'Bohr')]);
    expect(c.cached(1), 'Atom');
    expect(c.cached(2), 'Bohr');
  });

  test('prime() fetches once and memoizes', () async {
    var calls = 0;
    final c = ArticleTitleCache(fetch: (refid) async {
      calls++;
      return 'T$refid';
    });
    expect(await c.prime(9), 'T9');
    expect(await c.prime(9), 'T9');
    expect(calls, 1);
    expect(c.cached(9), 'T9');
  });
}
