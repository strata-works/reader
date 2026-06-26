import 'package:encarta_data/encarta_data.dart';
import 'package:test/test.dart';

void main() {
  const xml =
      '<text><pkey>The <i>quartz</i> mineral is a common rock-forming '
      'silicate found across the planet in many forms.</pkey></text>';

  test('strips tags and centers on the first query hit', () {
    final s = encartaSnippet(xml, 'quartz', radius: 12);
    expect(s, contains('quartz'));
    expect(s, isNot(contains('<')));
    // 'quartz' is at idx=4; radius=12 -> unclamped start=-8, clamped to 0 ->
    // nothing elided on the left, so NO leading ellipsis.
    expect(s, isNot(startsWith('…')));
  });

  test('no leading ellipsis when hit is near start (start clamps to 0)', () {
    // 'quartz' at idx=4, radius=12: start=4-12=-8 -> clamped to 0 -> no elision
    final s = encartaSnippet(xml, 'quartz', radius: 12);
    expect(s, isNot(startsWith('…')));
    expect(s, contains('quartz'));
  });

  test('leading ellipsis when hit is deep in the text (real left elision)', () {
    // 19 filler chars + space before 'target' -> idx=20; radius=5 -> start=15>0
    const deep = 'AAAAAAAAAAAAAAAAAAA target BBBBB';
    final s = encartaSnippet(deep, 'target', radius: 5);
    expect(s, startsWith('…'));
    expect(s, contains('target'));
  });

  test('decodes basic entities and collapses whitespace', () {
    final s = encartaSnippet('<p>Tom &amp;   Jerry</p>', 'jerry');
    expect(s, contains('Tom & Jerry'));
  });

  test('no hit -> returns a leading excerpt', () {
    final s = encartaSnippet(xml, 'zzz', radius: 8);
    expect(s, startsWith('The quartz')); // first chars of stripped text
    expect(s, isNot(contains('<')));
  });

  test('empty body -> empty string', () {
    expect(encartaSnippet('', 'x'), isEmpty);
  });
}
