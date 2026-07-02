import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders hero, tiles, A-Z strip, random; fires callbacks',
      (tester) async {
    int? opened;
    String? letter;
    var randomTapped = false;
    String? searched;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeView(
          data: const HomeViewData(
            hero: TitleRef(refid: 1, title: 'Encarta Kids home page'),
            tiles: [
              TitleRef(refid: 2, title: 'Animals'),
              TitleRef(refid: 3, title: 'Science'),
            ],
            azLetters: ['A', 'B', 'C'],
          ),
          onOpenArticle: (r) => opened = r,
          onBrowseLetter: (l) => letter = l,
          onSearch: (q) => searched = q,
          onRandom: () => randomTapped = true,
        ),
      ),
    ));

    // Hero renders.
    expect(find.text('Encarta Kids home page'), findsOneWidget);

    // Hero tap fires onOpenArticle(heroRefid).
    await tester.tap(find.text('Encarta Kids home page'));
    await tester.pump();
    expect(opened, 1);

    // Tile renders and tap fires onOpenArticle(tileRefid).
    expect(find.text('Animals'), findsOneWidget);
    await tester.tap(find.text('Animals'));
    await tester.pump();
    expect(opened, 2);

    // A–Z letter tap fires onBrowseLetter.
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(letter, 'B');

    // Random fires onRandom.
    await tester.tap(find.byKey(const Key('home.random')));
    await tester.pump();
    expect(randomTapped, isTrue);

    // Search submit fires onSearch(query).
    await tester.enterText(find.byType(TextField), 'africa');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(searched, 'africa');
  });

  testWidgets('empty data does not crash', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeView(
          data: const HomeViewData(
            hero: null,
            tiles: [],
            azLetters: [],
          ),
          onOpenArticle: (_) {},
          onBrowseLetter: (_) {},
          onSearch: (_) {},
          onRandom: () {},
        ),
      ),
    ));
    expect(find.byType(HomeView), findsOneWidget);
  });
}
