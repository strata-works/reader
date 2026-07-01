// packages/encarta_assets/lib/src/caption_text.dart
import 'package:flutter/material.dart';

/// Renders a media caption or credit string that may contain inline markup.
///
/// Handled vocabulary:
///   `<it>…</it>` and `<i>…</i>` → italic (`fontStyle: FontStyle.italic`)
///   `<scp>…</scp>`               → small-caps (OpenType 'smcp' feature)
///   Unknown tags                  → tag stripped, inner text kept as-is
///   Standard XML entities         → decoded (`&amp;` `&lt;` `&gt;` `&quot;` `&apos;`)
///
/// Malformed or unbalanced tags degrade gracefully: no text is ever dropped
/// and no exception is ever thrown.
///
/// Usage:
/// ```dart
/// CaptionText(
///   item.caption!,
///   style: Theme.of(context).textTheme.bodySmall,
/// )
/// ```
class CaptionText extends StatelessWidget {
  const CaptionText(this.raw, {this.style, this.textAlign, super.key});

  /// The raw markup string to parse and render.
  final String raw;

  /// Base text style; markup styles are applied on top via [TextStyle.copyWith].
  /// If omitted, the ambient [DefaultTextStyle] is used.
  final TextStyle? style;

  /// Text alignment forwarded to the inner [Text.rich].
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = _parseMarkup(raw, base);
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }
}

// ---------------------------------------------------------------------------
// Internal parser
// ---------------------------------------------------------------------------

/// Parses the mini markup vocabulary into a flat list of [TextSpan]s.
///
/// Uses a hand-rolled tokeniser so there is no additional package dependency.
/// The style stack tracks the currently active combined style; opening tags
/// push a new entry and closing tags pop one. Unrecognised tags contribute
/// no style change (inner text is still emitted with the inherited style).
List<TextSpan> _parseMarkup(String raw, TextStyle base) {
  final spans = <TextSpan>[];
  final styleStack = <TextStyle>[base];
  int pos = 0;

  while (pos < raw.length) {
    final tagStart = raw.indexOf('<', pos);

    if (tagStart == -1) {
      // No more tags — emit the rest as plain text.
      final text = _decodeEntities(raw.substring(pos));
      if (text.isNotEmpty) spans.add(TextSpan(text: text, style: styleStack.last));
      break;
    }

    // Emit plain text before the next tag.
    if (tagStart > pos) {
      final text = _decodeEntities(raw.substring(pos, tagStart));
      if (text.isNotEmpty) spans.add(TextSpan(text: text, style: styleStack.last));
    }

    final tagEnd = raw.indexOf('>', tagStart);
    if (tagEnd == -1) {
      // Malformed: '<' with no matching '>'. Treat as literal text.
      final text = _decodeEntities(raw.substring(tagStart));
      if (text.isNotEmpty) spans.add(TextSpan(text: text, style: styleStack.last));
      break;
    }

    final tagContent = raw.substring(tagStart + 1, tagEnd).trim();
    final isClosing = tagContent.startsWith('/');
    final rawName =
        (isClosing ? tagContent.substring(1) : tagContent.split(_kAttrSplit).first)
            .trim()
            .toLowerCase();

    if (isClosing) {
      // Pop the style stack (never below the base style).
      if (styleStack.length > 1) styleStack.removeLast();
    } else if (rawName.isNotEmpty) {
      // Push the new style for this opening tag.
      styleStack.add(_styleForTag(rawName, styleStack.last));
    }

    pos = tagEnd + 1;
  }

  return spans;
}

/// Splits on whitespace or self-closing slash to extract the tag name only.
final RegExp _kAttrSplit = RegExp(r'[\s/]');

/// Returns the text style for a recognised tag name, falling back to [base]
/// for unknown tags (so their inner text is kept with the inherited style).
TextStyle _styleForTag(String name, TextStyle base) {
  switch (name) {
    case 'it':
    case 'i':
      return base.copyWith(fontStyle: FontStyle.italic);
    case 'scp':
      // Prefer the OpenType 'smcp' feature; matches how encarta_render does it.
      return base.copyWith(
        fontFeatures: const [FontFeature.enable('smcp')],
      );
    default:
      // Unknown tag: inherit style unchanged so inner text is still rendered.
      return base;
  }
}

/// Decodes the five standard XML/HTML character entities.
///
/// `&amp;` is decoded last so that `&amp;lt;` → `&lt;` (not `<`).
String _decodeEntities(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll("&apos;", "'")
    .replaceAll('&amp;', '&');
