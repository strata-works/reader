import 'package:auto_route/auto_route.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import '../../data/degradation.dart';
import '../../data/title_cache.dart';
import '../../widgets/app_scope.dart';
import 'article_view.dart';

/// Pure assembly: DB rows + parsed doc → ArticleViewData. Testable without Flutter.
Future<ArticleViewData?> buildArticleViewData({
  required int refid,
  required Future<Article?> Function(int) getArticle,
  required Future<List<MediaItem>> Function(int) mediaForArticle,
  required Future<List<XrefTarget>> Function(int) outboundXrefs,
  required ArticleTitleCache titles,
}) async {
  final article = await getArticle(refid);
  if (article == null) return null;

  final doc = EncartaDoc.parse(article.xmlBytes, title: article.title);
  final outline = doc.outline;

  final results = await Future.wait([
    mediaForArticle(refid),
    outboundXrefs(refid),
  ]);
  final media = results[0] as List<MediaItem>;
  final related = results[1] as List<XrefTarget>;

  titles.seedXrefs(related);
  titles.seed(refid, article.title);

  final displayTitle = resolveDisplayTitle(
    refid: refid,
    dbTitle: article.title,
    outline: outline,
  );

  return ArticleViewData(
    doc: doc,
    outline: outline,
    title: displayTitle,
    source: article.source,
    related: related,
    media: media,
  );
}

@RoutePage()
class ArticlePage extends StatefulWidget {
  const ArticlePage({
    super.key,
    @PathParam('refid') required this.refid,
    @QueryParam('para') this.paraId,
  });
  final int refid;
  final String? paraId;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  // Guarded so that inherited-widget changes (theme, AppScope rebuild, etc.)
  // do not re-fire the full load pipeline unless the refid actually changes.
  int? _loadedRefid;
  Future<ArticleViewData?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    // Contract: AppScope.db and AppScope.assets must be non-null while
    // ArticlePage is active. Both are set before navigation and cleared only
    // after this page is popped.
    assert(
      scope.db != null && scope.assets != null,
      'ArticlePage requires AppScope.db and AppScope.assets to be non-null',
    );
    if (_loadedRefid == widget.refid && _future != null) return;
    _loadedRefid = widget.refid;
    final db = scope.db!;
    _future = buildArticleViewData(
      refid: widget.refid,
      getArticle: db.getArticle,
      mediaForArticle: db.mediaForArticle,
      outboundXrefs: db.outboundXrefs,
      titles: scope.titles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<ArticleViewData?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (data == null) {
          return Center(child: Text('Article ${widget.refid} not found.'));
        }
        return ArticleView(
          data: data,
          theme: scope.theme,
          assetResolver: (id, type) => scope.assets!.inlineBmp(id, type),
          onXrefTap: (refid, {paraId}) =>
              scope.navigator.openArticle(refid, paraId: paraId),
          titleForRefid: scope.titles.cached,
          onRelatedTap: (refid) => scope.navigator.openArticle(refid),
          assets: scope.assets,
        );
      },
    );
  }
}
