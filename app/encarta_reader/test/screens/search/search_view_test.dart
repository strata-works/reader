import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/article/article_view.dart';
import 'package:encarta_reader/src/screens/search/search_result_tile.dart';
import 'package:encarta_reader/src/screens/search/search_view.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArticleViewData _previewData() {
  final doc = EncartaDoc.parse(
    Uint8List.fromList(utf8.encode(
      '<content><text><pkey>Preview text.</pkey></text></content>',
    )),
    title: 'Mars',
  );
  return ArticleViewData(
    doc: doc,
    outline: const EncartaOutline(entries: []),
    title: 'Mars',
    source: 'CONTDLX',
    related: const [],
    media: const [],
  );
}

void main() {
  testWidgets('shows results column and a preview placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchView(
          data: const SearchViewData(
            query: 'mars',
            results: [
              SearchResultItem(
                refid: 1,
                title: 'Mars',
                snippet: 'fourth planet',
                tierBadge: 'Deluxe',
                thumb: null,
              ),
            ],
            offset: 0,
            hasMore: false,
          ),
          preview: null,
          onSelect: (_) {},
          onNextPage: null,
        ),
      ),
    ));

    expect(find.byType(SearchResultTile), findsOneWidget);
    expect(find.text('Select a result to preview'), findsOneWidget);
  });

  testWidgets('shows EncartaArticleBody in the right pane when preview is provided',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchView(
          data: const SearchViewData(
            query: 'mars',
            results: [
              SearchResultItem(
                refid: 1,
                title: 'Mars',
                snippet: 'fourth planet',
                tierBadge: 'Deluxe',
                thumb: null,
              ),
            ],
            offset: 0,
            hasMore: false,
          ),
          preview: _previewData(),
          theme: EncartaTheme.faithfulInSpirit(),
          onSelect: (_) {},
          onNextPage: null,
        ),
      ),
    ));

    expect(find.byType(EncartaArticleBody), findsOneWidget);
    expect(find.text('Select a result to preview'), findsNothing);
  });

  testWidgets('onSelect is called with the correct refid when a tile is tapped',
      (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchView(
          data: const SearchViewData(
            query: 'planets',
            results: [
              SearchResultItem(
                refid: 1,
                title: 'Mars',
                snippet: 'fourth planet',
                tierBadge: 'Deluxe',
                thumb: null,
              ),
              SearchResultItem(
                refid: 2,
                title: 'Jupiter',
                snippet: 'gas giant',
                tierBadge: 'Standard',
                thumb: null,
              ),
            ],
            offset: 0,
            hasMore: false,
          ),
          preview: null,
          onSelect: (refid) => selected = refid,
          onNextPage: null,
        ),
      ),
    ));

    await tester.tap(find.text('Jupiter'));
    await tester.pump();
    expect(selected, 2);
  });
}
