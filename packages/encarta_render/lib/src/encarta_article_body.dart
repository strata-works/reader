import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
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

  /// Maps each anchor id → index of the TOP-LEVEL block in [EncartaDoc.blocks]
  /// whose subtree contains that id. Used for off-screen proportional jumping
  /// in [scrollToAnchor] when the target is nested inside a top-level block.
  final Map<String, int> _anchorTopIndex = <String, int>{};

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
      _anchorTopIndex.clear();
      _rebuildAnchors();
    }
    // If the injected controller changed and we no longer need our own, dispose it.
    if (oldWidget.controller == null && widget.controller != null) {
      _ownController?.dispose();
      _ownController = null;
    }
  }

  void _rebuildAnchors() {
    // Create a GlobalKey for EVERY id in allAnchorIds() — top-level and nested.
    for (final id in widget.doc.allAnchorIds()) {
      _anchors.putIfAbsent(id, () => GlobalKey());
    }

    // Build _anchorTopIndex: each anchor id → index of the top-level block
    // whose subtree contains it (used for off-screen proportional jumping).
    for (var i = 0; i < widget.doc.blocks.length; i++) {
      final block = widget.doc.blocks[i];
      final bid = block.getAttribute('id');
      if (bid != null && bid.isNotEmpty) {
        _anchorTopIndex[bid] = i;
      }
      for (final d in block.descendantElements) {
        final did = d.getAttribute('id');
        if (did != null && did.isNotEmpty) {
          _anchorTopIndex[did] = i;
        }
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

    // Use _anchorTopIndex to find the top-level block that owns this anchor
    // (works for nested ids that are NOT in doc.blocks directly).
    final idx = _anchorTopIndex[anchorId];
    if (idx == null || widget.doc.blocks.length <= 1) return Future<void>.value();

    final pos = controller.position;
    final target = (pos.maxScrollExtent * (idx / (widget.doc.blocks.length - 1)))
        .clamp(0.0, pos.maxScrollExtent);
    controller.jumpTo(target);

    // Use a Completer so the caller's `await scrollToAnchor(id)` resumes only
    // after the post-frame ensureVisible animation actually completes.
    // The test must NOT await the future before pumping a frame — it should
    // capture the future, call pumpAndSettle() to drive the callback and
    // animation, then await the (already-complete) future.
    final completer = Completer<void>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        completer.complete();
        return;
      }
      final newCtx = key.currentContext;
      if (newCtx == null) {
        // Anchor truly absent after the frame — complete normally, never hang.
        completer.complete();
        return;
      }
      Scrollable.ensureVisible(
        newCtx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.05,
      ).then((_) => completer.complete()).catchError(completer.completeError);
    });

    return completer.future;
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
    // Pass anchorIds + anchorKeys so BlockRenderer keys every element—including
    // nested sections and paragraphs—via KeyedSubtree, not just top-level blocks.
    final blocks = BlockRenderer(
      theme: widget.theme,
      inline: inline,
      anchorIds: _anchors.keys.toSet(),
      anchorKeys: _anchors,
    );
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
            // BlockRenderer.build() now owns KeyedSubtree wrapping for all
            // elements (top-level and nested) whose id is in anchorIds.
            final Widget w = blocks.build(top[i]);
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
