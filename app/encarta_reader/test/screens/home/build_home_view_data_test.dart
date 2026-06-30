import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first featured becomes the hero; the rest become tiles; A-Z has 26', () async {
    final data = await buildHomeViewData(
      featured: ({int limit = 12}) async => const [
        TitleRef(refid: 1, title: 'Encarta Kids home page'),
        TitleRef(refid: 2, title: 'Animals'),
        TitleRef(refid: 3, title: 'Science'),
      ],
    );

    expect(data.hero!.title, 'Encarta Kids home page');
    expect(data.tiles.map((t) => t.title), ['Animals', 'Science']);
    expect(data.azLetters.length, 26);
    expect(data.azLetters.first, 'A');
    expect(data.azLetters.last, 'Z');
  });

  test('empty featured yields a null hero and no tiles', () async {
    final data = await buildHomeViewData(featured: ({int limit = 12}) async => const []);
    expect(data.hero, isNull);
    expect(data.tiles, isEmpty);
    expect(data.azLetters.length, 26);
  });
}
