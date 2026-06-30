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
  BlockRenderer({required this.theme, required this.inline});

  final EncartaTheme theme;
  final InlineBuilder inline;

  Widget build(XmlElement el, {int depth = 0}) {
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
      default:
        // Never drop text: render the unknown block as default-styled prose.
        // Later tasks add section/list/etc. branches here.
        return _prose(el, theme.body, debug: true);
    }
  }

  Widget _prose(XmlElement el, TextStyle style, {bool debug = false}) {
    final rich = Text.rich(TextSpan(style: style, children: inline.build(el, style)));
    if (debug && theme.debugUnstyledTags) {
      return Container(color: theme.debugUnstyledColor, child: rich);
    }
    return rich;
  }
}
