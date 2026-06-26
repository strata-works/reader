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
    expect(s, startsWith('…')); // leading ellipsis: hit not at the very start
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
