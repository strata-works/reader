import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  test('TitleRef holds fields and supports value equality', () {
    const a = TitleRef(refid: 5, title: 'Atom');
    const b = TitleRef(refid: 5, title: 'Atom');
    const c = TitleRef(refid: 6, title: 'Boron');
    expect(a.refid, 5);
    expect(a.title, 'Atom');
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });
}
