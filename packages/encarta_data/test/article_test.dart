import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  test('Article holds fields and supports value equality', () {
    final a = Article(
      refid: 1,
      title: 'Atom',
      source: 'CONTDLX.AKC',
      xmlBytes: Uint8List.fromList(const [60, 99, 62]),
    );
    final b = Article(
      refid: 1,
      title: 'Atom',
      source: 'CONTDLX.AKC',
      xmlBytes: Uint8List.fromList(const [60, 99, 62]),
    );
    expect(a.refid, 1);
    expect(a.title, 'Atom');
    expect(a.source, 'CONTDLX.AKC');
    expect(a.xmlBytes, [60, 99, 62]);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
