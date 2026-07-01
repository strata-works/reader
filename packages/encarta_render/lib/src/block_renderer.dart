// packages/encarta_render/lib/src/block_renderer.dart
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'encarta_theme.dart';
import 'inline_renderer.dart';

/// Maps block-level XML tags to vertical Flutter widgets. Structure only; all
/// pixels come from [theme].
///
/// Later tasks add section/list/sec*/rule/br branches to the same dispatch.
class BlockRenderer {
  BlockRenderer({
    required this.theme,
    required this.inline,
    this.anchorIds = const {},
    this.anchorKeys = const {},
  });

  final EncartaTheme theme;
  final InlineBuilder inline;

  /// Set of element ids that should receive a [GlobalKey] via [KeyedSubtree].
  /// Populated by [EncartaArticleBody] from [EncartaDoc.allAnchorIds].
  final Set<String> anchorIds;

  /// Map from element id → [GlobalKey]. Must contain an entry for every id in
  /// [anchorIds]. Owned by [EncartaArticleBody]; passed here for keying.
  final Map<String, GlobalKey> anchorKeys;

  /// Build the widget for [el] at [depth], wrapping it with a [KeyedSubtree]
  /// if the element's id is in [anchorIds] (so any level—top-level or
  /// nested—can be scrolled to via [EncartaArticleBodyState.scrollToAnchor]).
  Widget build(XmlElement el, {int depth = 0}) {
    Widget w = _buildWidget(el, depth: depth);
    final id = el.getAttribute('id');
    if (id != null && id.isNotEmpty && anchorIds.contains(id)) {
      w = KeyedSubtree(key: anchorKeys[id]!, child: w);
    }
    return w;
  }

  /// Internal dispatch: computes the raw widget for [el] without anchor keying.
  /// Recursive calls from [_section] go back through [build] so nested elements
  /// also receive their [KeyedSubtree] wrappers.
  Widget _buildWidget(XmlElement el, {int depth = 0}) {
    switch (el.name.local) {
      case 'pkey':
        return _prose(el, theme.body);
      case 'intro':
        return _prose(el, theme.intro);
      case 'headline':
        // All `type` variants (33/32/36/35/34) collapse to one style — a
        // documented judgment call per VOCABULARY.md notes.
        return _prose(el, theme.headlineDefault);
      case 'author':
        return _prose(el, theme.author);
      case 'quote':
        return _prose(el, theme.quote);
      case 'example':
        return _prose(el, theme.example);
      case 'section':
        return _section(el, depth);
      case 'sectiontitle':
        return _prose(el, theme.sectionTitleStyle(depth == 0 ? 1 : depth));
      case 'list':
        return _list(el);
      case 'sec':
      case 'seca':
      case 'secb':
      case 'secc':
        // Outline-numbering scaffolding ("II", "A", "1", "a"). Encarta used
        // these as per-section enumerators, never as visible body content.
        // Rendering them produces orphaned floating glyphs; suppress entirely.
        return const SizedBox.shrink();
      case 'rule':
        return Padding(
          padding: EdgeInsets.symmetric(vertical: theme.blockSpacing / 2),
          child: Divider(color: theme.ruleColor, height: 1, thickness: 1),
        );
      case 'br':
        return SizedBox(height: theme.blockSpacing);
      default:
        // Never drop text: render the unknown block as default-styled prose.
        // Later tasks add section/list/etc. branches here.
        return _prose(el, theme.body, debug: true);
    }
  }

  /// Maps section [type] attribute to a heading level (1-based).
  /// type 4→1, 5→2, 6→3, 7→4; unknown/missing → 1.
  int _depthForType(XmlElement section) {
    switch (int.tryParse(section.getAttribute('type') ?? '')) {
      case 4:
        return 1;
      case 5:
        return 2;
      case 6:
        return 3;
      case 7:
        return 4;
      default:
        return 1;
    }
  }

  Widget _section(XmlElement el, int depth) {
    final level = _depthForType(el);
    final children = <Widget>[];
    for (final child in el.childElements) {
      if (child.name.local == 'sectiontitle') {
        children.add(_prose(child, theme.sectionTitleStyle(level)));
      } else {
        children.add(build(child, depth: depth + 1));
      }
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(height: theme.blockSpacing));
    }
    final column = Column(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : theme.sectionIndentPerDepth),
      child: column,
    );
  }

  Widget _list(XmlElement el) {
    final type = int.tryParse(el.getAttribute('type') ?? '') ?? 1;
    final ordered = type != 1; // type 1 = bulleted; 19/20 = ordered
    final items = el.findElements('listitem').toList();
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final marker = ordered ? '${i + 1}.' : '•';
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: theme.blockSpacing / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, child: Text(marker, style: theme.listItem)),
            Expanded(
              child: Text.rich(TextSpan(style: theme.listItem, children: inline.build(items[i], theme.listItem))),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _prose(XmlElement el, TextStyle style, {bool debug = false}) {
    final rich = Text.rich(TextSpan(style: style, children: inline.build(el, style)));
    if (debug && theme.debugUnstyledTags) {
      return Container(color: theme.debugUnstyledColor, child: rich);
    }
    return rich;
  }
}
