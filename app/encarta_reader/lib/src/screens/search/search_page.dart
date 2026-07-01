import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import '../../data/snippet.dart';
import '../../data/tier.dart';
import '../../widgets/app_scope.dart';
import '../article/article_page.dart';
import '../article/article_view.dart';
import 'search_view.dart';

/// Roles tried, in order, for a result thumbnail (§11.3).
///
/// Precedence confirmed by Task 22 probe (449 articles sampled):
///   thumb  avg 1976 B real .jtn images  → best choice
///   picon  avg 1981 B real .jtn images  → per-article fallback
///   image  avg 1900 B real inline image → secondary fallback
///   ticon  avg  247 B tiny .gif icons   → last resort (placeholder-sized)
const _thumbRoles = ['thumb', 'picon', 'image', 'ticon'];

MediaItem? _pickThumb(List<MediaItem> media) {
  for (final role in _thumbRoles) {
    for (final m in media) {
      if (m.role == role) return m;
    }
  }
  return null;
}

/// Exposed for tests / probes; precedence confirmed in Task 22.
MediaItem? pickThumbForTest(List<MediaItem> media) => _pickThumb(media);

/// Pure assembly of the search screen's left column (ranked + paginated + snippet).
///
/// All DB methods are injected as function params so this is testable with fakes.
Future<SearchViewData> buildSearchViewData({
  required String query,
  required int offset,
  required int limit,
  required Future<List<SearchHit>> Function(String,
          {int limit, int offset})
      search,
  required Future<Article?> Function(int) getArticle,
  required Future<List<MediaItem>> Function(int) mediaForArticle,
}) async {
  final hits = await search(query, limit: limit, offset: offset);
  final results = <SearchResultItem>[];
  for (final h in hits) {
    final article = await getArticle(h.refid);
    final snippet = article == null
        ? ''
        : makeSnippet(article.xmlBytes, query);
    final media = await mediaForArticle(h.refid);
    results.add(SearchResultItem(
      refid: h.refid,
      title: h.title,
      snippet: snippet,
      tierBadge: tierBadge(article?.source ?? ''),
      thumb: _pickThumb(media),
    ));
  }
  return SearchViewData(
    query: query,
    results: results,
    offset: offset,
    hasMore: hits.length >= limit,
  );
}

@RoutePage()
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, @QueryParam('q') this.q = ''});
  final String q;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _limit = 25;
  Future<SearchViewData>? _future;
  ArticleViewData? _preview;
  int _selected = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db!;
    _future = buildSearchViewData(
      query: widget.q,
      offset: 0,
      limit: _limit,
      search: db.search,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
    );
  }

  Future<void> _select(int refid) async {
    final scope = AppScope.of(context);
    final db = scope.db!;
    final data = await buildArticleViewData(
      refid: refid,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
      outboundXrefs: db.outboundXrefs,
      titles: scope.titles,
    );
    if (!mounted) return;
    setState(() {
      _selected = refid;
      _preview = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<SearchViewData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
              child: Text('Something went wrong loading this search.'));
        }
        final base = snap.data!;
        final marked = SearchViewData(
          query: base.query,
          offset: base.offset,
          hasMore: base.hasMore,
          results: [
            for (final r in base.results)
              r.copyWith(selected: r.refid == _selected),
          ],
        );
        return SearchView(
          data: marked,
          preview: _preview,
          theme: scope.theme,
          assetResolver: (id, type) => scope.assets!.inlineBmp(id, type),
          onXrefTap: (refid, {paraId}) =>
              scope.navigator.openArticle(refid, paraId: paraId),
          titleForRefid: scope.titles.cached,
          onSelect: _select,
          onNextPage: null,
        );
      },
    );
  }
}
