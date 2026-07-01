import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home falls back to a non-empty source when featured() is empty', () async {
    final data = await buildHomeViewData(
      featured: ({int limit = 12}) async => const [],
      fallback: ({int limit = 12}) async =>
          const [TitleRef(refid: 1, title: 'Aardvark')],
    );
    expect(data.hero!.title, 'Aardvark');
  });
}
