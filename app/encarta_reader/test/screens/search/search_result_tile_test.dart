import 'package:encarta_reader/src/screens/search/search_result_tile.dart';
import 'package:encarta_reader/src/screens/search/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows title, snippet, tier badge and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchResultTile(
          item: const SearchResultItem(
            refid: 1,
            title: 'Black hole',
            snippet: '…a region of spacetime…',
            tierBadge: 'Deluxe',
            thumb: null,
          ),
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Black hole'), findsOneWidget);
    expect(find.text('…a region of spacetime…'), findsOneWidget);
    expect(find.text('Deluxe'), findsOneWidget);

    await tester.tap(find.byType(SearchResultTile));
    expect(tapped, isTrue);
  });

  testWidgets('selected tile has a distinct background from unselected',
      (tester) async {
    const baseItem = SearchResultItem(
      refid: 2,
      title: 'Neutron star',
      snippet: 'A dense stellar remnant',
      tierBadge: 'Std',
      thumb: null,
    );

    // Render unselected first.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchResultTile(
          item: baseItem,
          onTap: () {},
        ),
      ),
    ));

    final unselectedBg = tester
        .widget<Container>(find.byKey(const ValueKey('search-result-tile-bg')));
    expect(unselectedBg.color, isNull,
        reason: 'unselected tile should have no background colour');

    // Render selected variant.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchResultTile(
          item: baseItem.copyWith(selected: true),
          onTap: () {},
        ),
      ),
    ));

    final selectedBg = tester
        .widget<Container>(find.byKey(const ValueKey('search-result-tile-bg')));
    expect(selectedBg.color, isNotNull,
        reason: 'selected tile should have a highlight background colour');
  });
}
