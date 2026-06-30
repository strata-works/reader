import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_reader/src/screens/search/search_page.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _m(String role) => MediaItem(
      mediaRefid: 1,
      role: role,
      group: 'article',
      title: null,
      caption: null,
      credit: null,
      assetPath: 'image/x.jpg',
      ext: 'jpg',
      kind: 'image',
    );

void main() {
  test('thumb wins over ticon and picon (confirmed against real assets)', () {
    final picked = pickThumbForTest([_m('picon'), _m('ticon'), _m('thumb')]);
    expect(picked!.role, 'thumb');
  });
}
