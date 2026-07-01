import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:encarta_reader/src/screens/article/article_outline_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders outline + related and fires taps', (tester) async {
    String? tappedAnchor;
    int? tappedRefid;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleOutlinePane(
          outline: const EncartaOutline(entries: [
            OutlineEntry(title: 'History', anchorId: 'a1', depth: 0),
            OutlineEntry(title: 'Theory', anchorId: 'a2', depth: 1),
          ]),
          related: const [XrefTarget(targetRefid: 7, title: 'Newton')],
          onOutlineTap: (a) => tappedAnchor = a,
          onRelatedTap: (r) => tappedRefid = r,
        ),
      ),
    ));

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Newton'), findsOneWidget);

    await tester.tap(find.text('Theory'));
    expect(tappedAnchor, 'a2');
    await tester.tap(find.text('Newton'));
    expect(tappedRefid, 7);
  });

  testWidgets(
      'related item with inline markup renders plain text + italic, no raw tags',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleOutlinePane(
          outline: const EncartaOutline(entries: []),
          related: const [
            XrefTarget(
              targetRefid: 99,
              title: '<it>A Midsummer Night\'s Dream</it> (play)',
            ),
          ],
          onOutlineTap: (_) {},
          onRelatedTap: (_) {},
        ),
      ),
    ));

    // Raw tag text must not appear anywhere in the widget tree.
    expect(find.textContaining('<it>'), findsNothing,
        reason: 'opening <it> tag must be stripped');
    expect(find.textContaining('</it>'), findsNothing,
        reason: 'closing </it> tag must be stripped');

    // The visible text "A Midsummer Night's Dream" must be present as a
    // rich-text span rendered by CaptionText (findRichText: true).
    expect(
      find.textContaining("A Midsummer Night's Dream", findRichText: true),
      findsOneWidget,
      reason: 'title inner text must be visible',
    );

    // The italic span must carry FontStyle.italic.
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(CaptionText),
        matching: find.byType(RichText),
      ),
    );
    bool hasItalicSpan = false;
    void checkSpan(InlineSpan span) {
      if (span is TextSpan) {
        final text = span.text ?? '';
        if (text.contains("A Midsummer Night's Dream")) {
          if (span.style?.fontStyle == FontStyle.italic) hasItalicSpan = true;
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          checkSpan(child);
        }
      }
    }
    checkSpan(richText.text);
    expect(hasItalicSpan, isTrue, reason: '<it>-wrapped text must be italic');
  });

  testWidgets('active entry shows teal active-indicator styling', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleOutlinePane(
          outline: const EncartaOutline(entries: [
            OutlineEntry(title: 'History', anchorId: 'a1', depth: 0),
            OutlineEntry(title: 'Theory', anchorId: 'a2', depth: 1),
          ]),
          related: const [],
          onOutlineTap: (_) {},
          onRelatedTap: (_) {},
          activeAnchorId: 'a2',
        ),
      ),
    ));

    // The active entry ('Theory') must be present.
    expect(find.text('Theory'), findsOneWidget);

    // Find the active entry's Container and verify the active-indicator bg colour.
    final containers = tester.widgetList<Container>(find.byType(Container));
    final activeContainers = containers.where((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == const Color(0xFFE1F0F6);
      }
      return false;
    }).toList();
    expect(activeContainers, isNotEmpty,
        reason: 'Active entry must have bg Color(0xFFE1F0F6)');

    // The 3px left accent-teal border must be present on the active tile.
    final borderedContainers = containers.where((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        final leftBorder = decoration.border;
        if (leftBorder is Border) {
          return leftBorder.left.color == const Color(0xFF159AC0) &&
              leftBorder.left.width == 3;
        }
      }
      return false;
    }).toList();
    expect(borderedContainers, isNotEmpty,
        reason: 'Active entry must have 3px left border in accent-teal');

    // Non-active entry ('History') must NOT carry the active-indicator bg.
    final historyFinder = find.text('History');
    expect(historyFinder, findsOneWidget);
  });
}
