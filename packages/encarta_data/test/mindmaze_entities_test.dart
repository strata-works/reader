import 'package:encarta_data/src/mindmaze_entities.dart';
import 'package:test/test.dart';

void main() {
  test('decodes accented named entities in real MindMaze answers', () {
    expect(decodeMindMazeEntities('Senghor, L&eacute;opold S&eacute;dar'),
        'Senghor, Léopold Sédar');
    expect(decodeMindMazeEntities('M&ouml;bius Strip'), 'Möbius Strip');
    expect(decodeMindMazeEntities('Galois, &Eacute;variste'), 'Galois, Évariste');
    expect(decodeMindMazeEntities('Asw&amacr;n High Dam'), 'Aswān High Dam');
    expect(decodeMindMazeEntities('Bolyai, J&aacute;nos'), 'Bolyai, János');
  });

  test('decodes typographic entities', () {
    expect(decodeMindMazeEntities('Avogadro&rsquo;s Number'), 'Avogadro’s Number');
    expect(decodeMindMazeEntities('&ldquo;quote&rdquo;'), '“quote”');
  });

  test('&amp; is decoded last so &amp;eacute; stays literal', () {
    expect(decodeMindMazeEntities('AT&amp;T'), 'AT&T');
    expect(decodeMindMazeEntities('&amp;eacute;'), '&eacute;');
  });

  test('decodes numeric references', () {
    expect(decodeMindMazeEntities('caf&#233;'), 'café');
    expect(decodeMindMazeEntities('caf&#xe9;'), 'café');
  });

  test('leaves entity-free and unknown-entity text untouched', () {
    expect(decodeMindMazeEntities('First president of Senegal'),
        'First president of Senegal');
    expect(decodeMindMazeEntities('a &notareal; b'), 'a &notareal; b');
  });
}
