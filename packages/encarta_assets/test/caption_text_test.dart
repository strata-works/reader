// packages/encarta_assets/test/caption_text_test.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [CaptionText] inside a minimal MaterialApp and returns it.
Future<void> _pump(WidgetTester tester, String raw, {TextStyle? style}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CaptionText(raw, style: style),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Collects all [TextSpan]s rendered by the [CaptionText] widget,
/// descending through the [RichText] subtree it owns.
List<TextSpan> _spans(WidgetTester tester) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byType(CaptionText),
      matching: find.byType(RichText),
    ),
  );
  final collected = <TextSpan>[];
  _collect(richText.text, collected);
  return collected;
}

void _collect(InlineSpan span, List<TextSpan> out) {
  if (span is TextSpan) {
    // Include spans that carry text directly.
    if (span.text != null && span.text!.isNotEmpty) out.add(span);
    for (final child in span.children ?? <InlineSpan>[]) {
      _collect(child, out);
    }
  }
}

/// Concatenates the plain text from all spans.
String _plainText(WidgetTester tester) =>
    _spans(tester).map((s) => s.text ?? '').join();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // --- italic tags -----------------------------------------------------------

  testWidgets('<it>x</it> yields an italic span for "x"', (tester) async {
    await _pump(tester, '<it>x</it>');
    final spans = _spans(tester);
    final xSpan = spans.firstWhere(
      (s) => s.text == 'x',
      orElse: () => const TextSpan(text: ''),
    );
    expect(xSpan.text, 'x', reason: 'text "x" must be present');
    expect(xSpan.style?.fontStyle, FontStyle.italic,
        reason: '<it> must produce italic style');
  });

  testWidgets('<i>z</i> (rare alias) yields an italic span for "z"',
      (tester) async {
    await _pump(tester, '<i>z</i>');
    final spans = _spans(tester);
    final zSpan =
        spans.firstWhere((s) => s.text == 'z', orElse: () => const TextSpan(text: ''));
    expect(zSpan.text, 'z');
    expect(zSpan.style?.fontStyle, FontStyle.italic);
  });

  // --- small-caps tag --------------------------------------------------------

  testWidgets('<scp>y</scp> yields a span with the smcp font feature',
      (tester) async {
    await _pump(tester, '<scp>y</scp>');
    final spans = _spans(tester);
    final ySpan =
        spans.firstWhere((s) => s.text == 'y', orElse: () => const TextSpan(text: ''));
    expect(ySpan.text, 'y', reason: 'text "y" must be present');
    expect(
      ySpan.style?.fontFeatures,
      contains(const FontFeature.enable('smcp')),
      reason: '<scp> must enable the OpenType smcp feature',
    );
  });

  // --- mixed string ----------------------------------------------------------

  testWidgets('mixed markup renders all text with no dropped characters',
      (tester) async {
    const raw = 'known as the <it>kabaka.</it> He ruled';
    await _pump(tester, raw);
    final plain = _plainText(tester);
    expect(plain, 'known as the kabaka. He ruled',
        reason: 'all text must appear; tags must be stripped');

    final spans = _spans(tester);
    final kabaka = spans.firstWhere(
      (s) => s.text == 'kabaka.',
      orElse: () => const TextSpan(text: ''),
    );
    expect(kabaka.style?.fontStyle, FontStyle.italic,
        reason: 'the <it>-wrapped word must be italic');
  });

  // --- unknown tag -----------------------------------------------------------

  testWidgets('unknown tag: tag is stripped but inner text is kept',
      (tester) async {
    await _pump(tester, 'prefix <weird>visible</weird> suffix');
    final plain = _plainText(tester);
    expect(plain, 'prefix visible suffix',
        reason: 'unknown tag text must not be dropped');
    // Must not throw — verified implicitly by reaching this line.
  });

  // --- unbalanced / malformed tags -------------------------------------------

  testWidgets('unclosed tag does not crash and text still appears',
      (tester) async {
    await _pump(tester, 'before <it>unclosed');
    final plain = _plainText(tester);
    expect(plain.contains('before'), isTrue);
    expect(plain.contains('unclosed'), isTrue,
        reason: 'text inside an unclosed tag must not be dropped');
  });

  testWidgets('malformed tag (no closing >) does not crash', (tester) async {
    await _pump(tester, 'text <broken');
    // Just must not crash; all text before the '<' must appear.
    expect(_plainText(tester).contains('text'), isTrue);
  });

  // --- entity decoding -------------------------------------------------------

  testWidgets('XML entities are decoded in plain text', (tester) async {
    await _pump(tester, 'A &amp; B &lt;tag&gt; &quot;hi&quot; &apos;x&apos;');
    final plain = _plainText(tester);
    expect(plain, "A & B <tag> \"hi\" 'x'");
  });

  testWidgets('entities inside a markup tag are decoded', (tester) async {
    await _pump(tester, '<it>rock &amp; roll</it>');
    final plain = _plainText(tester);
    expect(plain, 'rock & roll');
    final spans = _spans(tester);
    expect(
      spans.every((s) => s.style?.fontStyle == FontStyle.italic),
      isTrue,
      reason: 'spans inside <it> must be italic',
    );
  });

  // --- style passthrough -----------------------------------------------------

  testWidgets('base style is inherited by plain text spans', (tester) async {
    const base = TextStyle(fontSize: 42);
    await _pump(tester, 'hello world', style: base);
    final spans = _spans(tester);
    // Every span must carry the base font size.
    for (final span in spans) {
      expect(span.style?.fontSize, 42,
          reason: 'base style fontSize must be passed through');
    }
  });

  // --- no-markup passthrough -------------------------------------------------

  testWidgets('plain string with no tags renders as-is', (tester) async {
    await _pump(tester, 'No markup here.');
    expect(_plainText(tester), 'No markup here.');
  });

  // --- maxLines / overflow ---------------------------------------------------

  testWidgets('maxLines and overflow are forwarded to the inner Text.rich',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CaptionText(
          'A very long string that should be clipped',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(CaptionText),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.maxLines, 1,
        reason: 'maxLines must be forwarded to Text.rich');
    expect(richText.overflow, TextOverflow.ellipsis,
        reason: 'overflow must be forwarded to Text.rich');
  });
}
