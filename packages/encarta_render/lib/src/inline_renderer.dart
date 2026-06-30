// packages/encarta_render/lib/src/inline_renderer.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

      case 'xref':
        return [_xref(el, base)];

      case 'inlinebmp':
        return [_inlineBmp(el)];

      case 'fs':
        return [_fraction(el, base)];

      case 'fl':
      case 'cq':
      case 'item':
      case 'notation':
        // Known-rare, no special styling: render children with the inherited style.
        return build(el, base);

      default:
        // Unknown tag: never drop its text; optionally flag it in debug mode.
        if (theme.debugUnstyledTags) {
          return build(el, base.copyWith(backgroundColor: theme.debugUnstyledColor));
        }
        return build(el, base);
    }
  }

  /// Handles `<xref>` inline elements.
  ///
  /// `type=9` (external): if a `URL` attribute is present, opens it via
  /// [url_launcher] and returns a link span recorded in [recognizers].
  /// Without a `URL`, returns plain text.
  ///
  /// All other types are internal: a `RefID` is looked up via [titleForRefid].
  /// If absent from the corpus (returns null), renders plain text (dead-link
  /// suppression). If present, attaches a [TapGestureRecognizer] that calls
  /// [onXrefTap] with the refid and optional `paraID` deep-link anchor.
  InlineSpan _xref(XmlElement el, TextStyle base) {
    final label = el.innerText;
    final type = int.tryParse(el.getAttribute('type') ?? '');
    final linkStyle = base.merge(theme.xrefStyle);

    // External link (type 9).
    if (type == 9) {
      final url = el.getAttribute('URL');
      if (url == null || url.isEmpty) return TextSpan(text: label, style: base);
      final r = TapGestureRecognizer()..onTap = () => _unawaitedLaunch(url);
      recognizers.add(r);
      return TextSpan(text: label, style: linkStyle, recognizer: r);
    }

    // Internal link (all other types carry a RefID).
    final refid = int.tryParse(el.getAttribute('RefID') ?? '');
    if (refid == null) return TextSpan(text: label, style: base);
    if (titleForRefid(refid) == null) {
      // Dead link: refid absent from corpus → plain text, no tap.
      return TextSpan(text: label, style: base);
    }
    final paraId = el.getAttribute('paraID');
    final r = TapGestureRecognizer()
      ..onTap = () => onXrefTap(refid, paraId: paraId);
    recognizers.add(r);
    return TextSpan(text: label, style: linkStyle, recognizer: r);
  }

  /// Fire-and-forget URL launch; swallows failures so a bad URL never crashes
  /// the reader.
  void _unawaitedLaunch(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri).catchError((_) => false);
    }
  }

  /// Handles `<inlinebmp>` inline image elements.
  ///
  /// Passes the `id` attribute (verbatim string) and `type` attribute (as int)
  /// to the injected [assetResolver] WITHOUT interpreting them. Resolution
  /// logic (type=27 → baggage_id, type=28 → original NAME.DIB filename, etc.)
  /// is entirely the host resolver's responsibility. If `type` is missing or
  /// non-numeric, defaults to 0 so the resolver can decide how to handle it.
  InlineSpan _inlineBmp(XmlElement el) {
    final id = el.getAttribute('id') ?? '';
    final type = int.tryParse(el.getAttribute('type') ?? '') ?? 0;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: assetResolver(id, type),
    );
  }

  /// Handles `<fs type="2">` fraction elements.
  ///
  /// Splits the trimmed inner text on the FIRST `/`. If found and `type == 2`,
  /// renders a stacked Column (numerator / hairline rule / denominator) inside
  /// a [WidgetSpan], scaling the font by [EncartaTheme.fractionFontScale].
  ///
  /// FALLBACK (never drop content): if there is no `/` in the text OR the
  /// `type` attribute is anything other than `2`, returns a plain [TextSpan]
  /// with the raw inner text and the inherited style.
  InlineSpan _fraction(XmlElement el, TextStyle base) {
    final typeAttr = int.tryParse(el.getAttribute('type') ?? '');
    final text = el.innerText.trim();
    final slash = text.indexOf('/');
    if (typeAttr != 2 || slash < 0) return TextSpan(text: text, style: base);
    final numerator = text.substring(0, slash).trim();
    final denominator = text.substring(slash + 1).trim();
    final fr = base.copyWith(fontSize: (base.fontSize ?? 16) * theme.fractionFontScale);
    final ruleWidth =
        (numerator.length > denominator.length ? numerator.length : denominator.length) *
            (fr.fontSize ?? 12) *
            0.62;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(numerator, style: fr),
          Container(height: 1, width: ruleWidth, color: base.color ?? theme.foreground),
          Text(denominator, style: fr),
        ],
      ),
    );
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
