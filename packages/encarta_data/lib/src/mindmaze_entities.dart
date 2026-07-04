/// Decodes the SGML/HTML character entities embedded in the raw MINDMAZE.DB
/// text (e.g. `L&eacute;opold` → `Léopold`, `M&ouml;bius` → `Möbius`,
/// `Avogadro&rsquo;s` → `Avogadro’s`).
///
/// The MindMaze question bank stores accented and typographic characters as
/// named entities (the article pipeline decodes these at ingest, but the
/// MindMaze ingest does not — see the quarry `mindmaze.py` cp1252 pass). Rather
/// than re-materialize the corpus, the data layer normalizes MindMaze text to
/// logical Unicode on read. The entity set is closed (a fixed historical data
/// file), so this static map is exact and dependency-free; decoding already-clean
/// text is a no-op, so it stays correct if the source is ever cleaned upstream.
library;

/// Named entities present in the MINDMAZE.DB corpus, mapped to their Unicode
/// characters. `&amp;` is intentionally absent — it is applied last (below) so
/// that `&amp;eacute;` decodes to the literal `&eacute;`, not `é`.
const Map<String, String> _entities = {
  // typographic
  'rsquo': '’', // ’
  'lsquo': '‘', // ‘
  'rdquo': '”', // ”
  'ldquo': '“', // “
  'mdash': '—', // —
  'deg': '°', // °
  'uml': '¨', // ¨
  'middot': '·', // ·
  'frac12': '½', // ½
  'emsp': ' ', // em space
  // Latin accented — lowercase
  'eacute': 'é', 'aacute': 'á', 'iacute': 'í',
  'oacute': 'ó', 'uacute': 'ú',
  'egrave': 'è', 'agrave': 'à', 'ograve': 'ò',
  'ouml': 'ö', 'uuml': 'ü', 'euml': 'ë', 'auml': 'ä',
  'iuml': 'ï',
  'ccedil': 'ç',
  'ocirc': 'ô', 'acirc': 'â', 'ecirc': 'ê', 'icirc': 'î',
  'ntilde': 'ñ', 'atilde': 'ã',
  'aring': 'å', 'oslash': 'ø',
  // Latin accented — uppercase
  'Eacute': 'É', 'Aring': 'Å', 'Uuml': 'Ü', 'Icirc': 'Î',
  // macron
  'amacr': 'ā', 'omacr': 'ō', 'umacr': 'ū', 'imacr': 'ī',
  'Amacr': 'Ā', 'Omacr': 'Ō',
  // other diacritics
  'Idot': 'İ', // İ
  'lstrok': 'ł', // ł
  'scedil': 'ş', // ş
  'tcedil': 'ţ', // ţ
  'Hcedil': 'Ḩ', // Ḩ
  'eogon': 'ę', // ę
  'nacute': 'ń', // ń
  'sacute': 'ś', // ś
  'cacute': 'ć', // ć
  'scaron': 'š', // š
  'rcaron': 'ř', // ř
  'ccaron': 'č', // č
  // breve (abreve/obreve are precomposed; c/s/z fall back to a combining breve)
  'abreve': 'ă', // ă
  'obreve': 'ŏ', // ŏ
  'cbreve': 'c̆', 'sbreve': 's̆', 'zbreve': 'z̆',
};

final RegExp _numericEntity = RegExp(r'&#([xX]?)([0-9A-Fa-f]+);');

/// Returns [text] with its MindMaze SGML/HTML entities decoded to Unicode.
/// Unrecognized `&name;` tokens are left untouched; numeric `&#DDD;` / `&#xHH;`
/// references are decoded generically. Idempotent on entity-free input.
String decodeMindMazeEntities(String text) {
  if (!text.contains('&')) return text;
  var out = text;
  for (final entry in _entities.entries) {
    out = out.replaceAll('&${entry.key};', entry.value);
  }
  out = out.replaceAllMapped(_numericEntity, (m) {
    final code = int.tryParse(m[2]!, radix: m[1]!.toLowerCase() == 'x' ? 16 : 10);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  return out.replaceAll('&amp;', '&'); // last, so &amp;foo; → &foo;
}
