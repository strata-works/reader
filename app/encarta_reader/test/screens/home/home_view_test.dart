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
          onSearch: (_) {},
          onRandom: () => randomTapped = true,
        ),
      ),
    ));

    expect(find.text('Encarta Kids home page'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);

    await tester.tap(find.text('Animals'));
    expect(opened, 2);
    await tester.tap(find.text('B'));
    expect(letter, 'B');
    await tester.tap(find.byKey(const Key('home.random')));
    expect(randomTapped, isTrue);
  });
}
