import 'package:encarta_data/encarta_data.dart';

/// Synchronous title lookup backing `TitleForRefid`. Seeded eagerly from data the
/// app already has (xref targets, title index, search hits) and lazily via [prime].
class ArticleTitleCache {
  final Future<String?> Function(int refid) fetch;
  final Map<int, String> _cache = <int, String>{};
  ArticleTitleCache({required this.fetch});

  String? cached(int refid) => _cache[refid];

  void seed(int refid, String title) => _cache[refid] = title;

  void seedXrefs(List<XrefTarget> xrefs) {
    for (final x in xrefs) {
      _cache[x.targetRefid] = x.title;
    }
  }

  void seedTitles(List<TitleRef> titles) {
    for (final t in titles) {
      _cache[t.refid] = t.title;
    }
  }

  Future<String?> prime(int refid) async {
    final hit = _cache[refid];
    if (hit != null) return hit;
    final fetched = await fetch(refid);
    if (fetched != null) _cache[refid] = fetched;
    return fetched;
  }
}
