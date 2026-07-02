import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  test('XrefTarget holds fields and supports value equality', () {
    const a = XrefTarget(targetRefid: 99, title: 'Gravity');
    const b = XrefTarget(targetRefid: 99, title: 'Gravity');
    expect(a.targetRefid, 99);
    expect(a.title, 'Gravity');
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('XrefTarget is not equal when fields differ', () {
    const a = XrefTarget(targetRefid: 99, title: 'Gravity');
    const c = XrefTarget(targetRefid: 42, title: 'Light');
    expect(a, isNot(equals(c)));
  });
}
