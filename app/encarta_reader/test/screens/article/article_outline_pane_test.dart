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
}
