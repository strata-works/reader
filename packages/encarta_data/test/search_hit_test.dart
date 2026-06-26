import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  test('SearchHit holds fields and supports value equality', () {
    const a = SearchHit(refid: 42, title: 'Mars', rank: -1.5);
    const b = SearchHit(refid: 42, title: 'Mars', rank: -1.5);
    expect(a.refid, 42);
    expect(a.title, 'Mars');
    expect(a.rank, -1.5);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
