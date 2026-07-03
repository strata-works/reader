import 'dart:convert';
import 'dart:typed_data';

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
          onOpen: (_) {},
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
          onOpen: (_) {},
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
          onOpen: (_) {},
          onNextPage: null,
        ),
      ),
    ));

    await tester.tap(find.text('Jupiter'));
    await tester.pump();
    expect(selected, 2);
  });

  // Responsive layout tests

  const narrowData = SearchViewData(
    query: 'mars',
    results: [
      SearchResultItem(
        refid: 42,
        title: 'Mars',
        snippet: 'fourth planet',
        tierBadge: 'Deluxe',
        thumb: null,
      ),
    ],
    offset: 0,
    hasMore: false,
  );

  Widget buildInWidth(
    double width, {
    required void Function(int) onSelect,
    required void Function(int) onOpen,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: SearchView(
              data: narrowData,
              preview: null,
              onSelect: onSelect,
              onOpen: onOpen,
              onNextPage: null,
            ),
          ),
        ),
      );

  testWidgets(
      'narrow layout (390 px): no overflow and tap invokes onOpen not onSelect',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? opened;
    int? selected;

    await tester.pumpWidget(buildInWidth(
      390,
      onSelect: (id) => selected = id,
      onOpen: (id) => opened = id,
    ));

    // No overflow exception.
    expect(tester.takeException(), isNull);

    // Results are shown.
    expect(find.byType(SearchResultTile), findsOneWidget);

    // Tap invokes onOpen, not onSelect.
    await tester.tap(find.text('Mars'));
    await tester.pump();
    expect(opened, 42);
    expect(selected, isNull);
  });

  testWidgets(
      'wide layout (800 px): two-pane shown and tap invokes onSelect not onOpen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? opened;
    int? selected;

    await tester.pumpWidget(buildInWidth(
      800,
      onSelect: (id) => selected = id,
      onOpen: (id) => opened = id,
    ));

    expect(tester.takeException(), isNull);

    // Preview placeholder visible (two-pane).
    expect(find.text('Select a result to preview'), findsOneWidget);

    // Tap invokes onSelect, not onOpen.
    await tester.tap(find.text('Mars'));
    await tester.pump();
    expect(selected, 42);
    expect(opened, isNull);
  });
}
