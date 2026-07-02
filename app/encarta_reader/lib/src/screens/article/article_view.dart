import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

import 'article_outline_pane.dart';
import 'media_rail.dart';

/// Immutable bundle for one rendered article (assembled by buildArticleViewData).
class ArticleViewData {
  final EncartaDoc doc;
  final EncartaOutline outline;
  final String title;
  final String source;
  final List<XrefTarget> related;
  final List<MediaItem> media;

  const ArticleViewData({
    required this.doc,
    required this.outline,
    required this.title,
    required this.source,
    required this.related,
    required this.media,
  });
}

/// Center-of-gravity Article screen: three panes (outline+related | body | media).
///
/// DEVIATION FROM BRIEF: adds optional [assets] parameter ([EncartaAssets?])
/// because [MediaRail] requires an [EncartaAssets] for file resolution.
/// [assetResolver] serves the body's inline images; [assets] serves the rail's
/// block media. Both are needed when the article has media — but [assets] is
/// optional so callers without media (or in tests) need not supply it.
class ArticleView extends StatefulWidget {
  final ArticleViewData data;
  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final void Function(int refid) onRelatedTap;

  /// When non-null and non-empty, the view calls [EncartaArticleBodyState.scrollToAnchor]
  /// with this id after the body is built (initState) and whenever this value
  /// changes (didUpdateWidget). Supports both initial deep-links and same-article
  /// "see section" xref navigation.
  final String? paraId;

  /// Required only when [data.media] is non-empty. Forwarded to [MediaRail].
  final EncartaAssets? assets;

  const ArticleView({
    super.key,
    required this.data,
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    required this.onRelatedTap,
    this.paraId,
    this.assets,
  });

  @override
  State<ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  /// Key into [EncartaArticleBodyState] so outline taps and paraId deep-links
  /// can call [scrollToAnchor].
  final _bodyKey = GlobalKey<EncartaArticleBodyState>();

  @override
  void initState() {
    super.initState();
    _scheduleParaIdScroll();
  }

  @override
  void didUpdateWidget(covariant ArticleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paraId != widget.paraId) {
      _scheduleParaIdScroll();
    }
  }

  /// Schedule a post-frame scroll to [widget.paraId] if it is non-null and
  /// non-empty. The post-frame delay ensures [_bodyKey.currentState] is
  /// available (body must be built before we can call scrollToAnchor).
  void _scheduleParaIdScroll() {
    final paraId = widget.paraId;
    if (paraId == null || paraId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bodyKey.currentState?.scrollToAnchor(paraId);
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.data.media.isEmpty || widget.assets != null,
      'ArticleView: media provided but assets is null — rail cannot resolve files',
    );
    final showRail = widget.data.media.isNotEmpty && widget.assets != null;

    // Design-system constants.
    const sideRailBg = Color(0xFFEEF3F6);
    const contentBg = Color(0xFFFCFDFE);
    const hairline = Color(0xFFD6E0E7);
    const ink = Color(0xFF1B2831);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: 244px outline+related pane — side-rail bg + 1px right hairline.
        Container(
          width: 244,
          decoration: const BoxDecoration(
            color: sideRailBg,
            border: Border(
              right: BorderSide(color: hairline, width: 1),
            ),
          ),
          child: ArticleOutlinePane(
            outline: widget.data.outline,
            related: widget.data.related,
            onOutlineTap: (anchorId) =>
                _bodyKey.currentState?.scrollToAnchor(anchorId),
            onRelatedTap: widget.onRelatedTap,
          ),
        ),

        // CENTER: content bg; article capped at theme.measure and centered;
        // padding 28h / 20t; title header with 1px hairline rule beneath.
        Expanded(
          child: ColoredBox(
            color: contentBg,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.theme.measure),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CaptionText(
                            widget.data.title,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w600,
                              color: ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: widget.theme.ruleColor,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: EncartaArticleBody(
                        key: _bodyKey,
                        doc: widget.data.doc,
                        theme: widget.theme,
                        assetResolver: widget.assetResolver,
                        onXrefTap: widget.onXrefTap,
                        titleForRefid: widget.titleForRefid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // RIGHT: 300px block media rail — side-rail bg + 1px left hairline.
        // Only shown when media is present + assets provided.
        if (showRail)
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: sideRailBg,
              border: Border(
                left: BorderSide(color: hairline, width: 1),
              ),
            ),
            child: MediaRail(
              media: widget.data.media,
              assets: widget.assets!,
            ),
          ),
      ],
    );
  }
}
