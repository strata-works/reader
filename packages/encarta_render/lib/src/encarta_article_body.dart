import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'callbacks.dart';
import 'block_renderer.dart';
import 'encarta_doc.dart';
import 'encarta_theme.dart';
import 'inline_renderer.dart';

/// Renders an [EncartaDoc] body lazily over its top-level blocks. Pure
/// presentation; reaches the outside world only via the injected callbacks.
class EncartaArticleBody extends StatefulWidget {
  const EncartaArticleBody({
    super.key,
    required this.doc,
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    this.controller,
  });

  final EncartaDoc doc;
  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final ScrollController? controller;

  @override
  State<EncartaArticleBody> createState() => EncartaArticleBodyState();
}

class EncartaArticleBodyState extends State<EncartaArticleBody> {
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};

  ScrollController? _ownController;

  ScrollController get _effectiveController =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _rebuildAnchors();
  }

  @override
  void didUpdateWidget(covariant EncartaArticleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.doc, widget.doc)) {
      _anchors.clear();
      _rebuildAnchors();
    }
    // If the injected controller changed and we no longer need our own, dispose it.
    if (oldWidget.controller == null && widget.controller != null) {
      _ownController?.dispose();
      _ownController = null;
    }
  }

  void _rebuildAnchors() {
    // Only attach keys to top-level blocks whose id is in allAnchorIds().
    final anchorSet = widget.doc.allAnchorIds().toSet();
    for (final block in widget.doc.blocks) {
      final id = block.getAttribute('id');
      if (id != null && id.isNotEmpty && anchorSet.contains(id)) {
        _anchors.putIfAbsent(id, () => GlobalKey());
      }
    }
  }

  /// Scroll a section/paragraph anchor into view (outline click or paraID deep-link).
  ///
  /// If the item is already built (on-screen), calls [Scrollable.ensureVisible]
  /// directly and awaits it. If it is off-screen (not yet built by the lazy
  /// list), jumps to an index-proportional offset so the list builds that
  /// region, then schedules [Scrollable.ensureVisible] via
  /// [addPostFrameCallback] so the caller can `await` this function without
  /// deadlocking in test environments where [WidgetsBinding.endOfFrame] would
  /// block until a frame is pumped.
  Future<void> scrollToAnchor(String anchorId) {
    final key = _anchors[anchorId];
    if (key == null) return Future<void>.value();

    final ctx = key.currentContext;
    final controller = _effectiveController;

    // Already on-screen — scroll into view and await the animation.
    if (ctx != null) {
      return Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250), alignment: 0.05);
    }

    // Off-screen lazy item: jump to an index-proportional offset to force the
    // list to build items around the target, then ensureVisible on next frame.
    if (!controller.hasClients) return Future<void>.value();

    final ids = widget.doc.blocks.map((b) => b.getAttribute('id')).toList();
    final idx = ids.indexOf(anchorId);
    if (idx < 0 || ids.length <= 1) return Future<void>.value();

    final pos = controller.position;
    final target = (pos.maxScrollExtent * (idx / (ids.length - 1)))
        .clamp(0.0, pos.maxScrollExtent);
    controller.jumpTo(target);

    // Register a post-frame callback to ensureVisible after the list rebuilds.
    // We do NOT await the frame here — that would deadlock in testWidgets when
    // the test `await`s this function before calling `pumpAndSettle()`.
    // The callback fires during the next pump, and pumpAndSettle() then drives
    // the ensureVisible animation to completion.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final newCtx = key.currentContext;
      if (newCtx != null) {
        await Scrollable.ensureVisible(
          newCtx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.05,
        );
      }
    });

    return Future<void>.value();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers(); // drop last frame's recognizers before re-creating spans
    final inline = InlineBuilder(
      theme: widget.theme,
      assetResolver: widget.assetResolver,
      onXrefTap: widget.onXrefTap,
      titleForRefid: widget.titleForRefid,
      articleTitle: widget.doc.title,
      recognizers: _recognizers,
    );
    final blocks = BlockRenderer(theme: widget.theme, inline: inline);
    final top = widget.doc.blocks;

    return Container(
      color: widget.theme.background,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.theme.measure),
        child: ListView.builder(
          controller: _effectiveController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: top.length,
          itemBuilder: (context, i) {
            final el = top[i];
            Widget w = blocks.build(el);
            final id = el.getAttribute('id');
            if (id != null && _anchors.containsKey(id)) {
              w = KeyedSubtree(key: _anchors[id], child: w);
            }
            return Padding(
              padding: EdgeInsets.only(bottom: widget.theme.blockSpacing),
              child: w,
            );
          },
        ),
      ),
    );
  }
}
