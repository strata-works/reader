// packages/encarta_render/lib/src/inline_renderer.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'callbacks.dart';
import 'encarta_theme.dart';

/// Turns inline XML runs into Flutter [InlineSpan]s. Stateless except for the
/// shared [recognizers] sink, which the host widget State owns and disposes.
///
/// Later tasks add `xref`, `inlinebmp`, `fs`, `inlinetitle`, and rare-tag
/// branches to [_element] without touching the core dispatch.
class InlineBuilder {
  InlineBuilder({
    required this.theme,
    required this.assetResolver,
    required this.onXrefTap,
    required this.titleForRefid,
    required this.articleTitle,
    required this.recognizers,
  });

  final EncartaTheme theme;
  final AssetResolver assetResolver;
  final XrefTap onXrefTap;
  final TitleForRefid titleForRefid;
  final String articleTitle;

  /// Accumulates [GestureRecognizer]s (e.g. for `xref` taps) so the host
  /// widget's [State] can dispose them in [State.dispose]. Later tasks push
  /// into this list; callers must dispose every entry.
  final List<GestureRecognizer> recognizers;

  /// Converts the direct children of [element] into a flat list of
  /// [InlineSpan]s, inheriting [base] as the current text style.
  ///
  /// `xml:space="preserve"` semantics: [XmlText] node values are passed
  /// verbatim — whitespace is never trimmed or collapsed.
  List<InlineSpan> build(XmlElement element, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final node in element.children) {
      if (node is XmlText) {
        spans.add(TextSpan(text: node.value, style: base));
      } else if (node is XmlElement) {
        spans.addAll(_element(node, base));
      }
      // XmlComment, XmlProcessing, etc. are silently ignored.
    }
    return spans;
  }

  /// Dispatches a single inline [XmlElement] to the appropriate span builder.
  ///
  /// Unknown tags fall through to the `default` case, which renders their
  /// children with the inherited style so text is never silently dropped.
  /// Later tasks extend this switch with `xref`, `inlinebmp`, `fs`,
  /// `inlinetitle`, and any rare tags from VOCABULARY.md.
  List<InlineSpan> _element(XmlElement el, TextStyle base) {
    switch (el.name.local) {
      case 'i':
        return build(el, base.copyWith(fontStyle: FontStyle.italic));

      case 'b':
        return build(el, base.copyWith(fontWeight: FontWeight.bold));

      case 'u':
        return build(el, base.copyWith(decoration: TextDecoration.underline));

      case 'smallcaps':
        // Prefer the OpenType 'smcp' feature; if the runtime font doesn't
        // support it the engine falls back to ordinary rendering silently.
        // An uppercase fallback would alter the text value, so we don't.
        return build(
          el,
          base.copyWith(
            fontFeatures: const [FontFeature.enable('smcp')],
          ),
        );

      case 'sub':
        // Rendered as a WidgetSpan wrapping a Transform.translate so that
        // the baseline shift is exact regardless of whether the runtime font
        // has OpenType subscript glyphs (they often don't).
        return [_shift(el, base, dyFactor: 0.22)];

      case 'sup':
        return [_shift(el, base, dyFactor: -0.40)];

      case 'br':
        // `<br></br>` is a hard line break; emit a bare newline TextSpan.
        return const [TextSpan(text: '\n')];

      case 'inlinetitle':
        return [TextSpan(text: articleTitle, style: base)];

      default:
        // "Never drop text" stance: render children with the inherited style.
        // Specific tags (xref, inlinebmp, …) are added in later tasks.
        return build(el, base);
    }
  }

  /// Wraps [el]'s content in a [WidgetSpan] with a vertical [Transform.translate]
  /// to produce sub/superscript without relying on OpenType positioning.
  ///
  /// [dyFactor] is multiplied by the effective font size:
  ///   - positive → shifts down (subscript)
  ///   - negative → shifts up (superscript)
  InlineSpan _shift(XmlElement el, TextStyle base, {required double dyFactor}) {
    final fontSize = base.fontSize ?? 16.0;
    final small = base.copyWith(fontSize: fontSize * 0.75);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Transform.translate(
        offset: Offset(0, fontSize * dyFactor),
        child: Text.rich(TextSpan(children: build(el, small))),
      ),
    );
  }
}
