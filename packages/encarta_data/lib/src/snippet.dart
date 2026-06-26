final _tagRe = RegExp(r'<[^>]*>');
final _wsRe = RegExp(r'\s+');

/// Builds a search snippet from raw article XML.
///
/// The fts5 table is contentless, so SQLite's `snippet()`/`highlight()` return
/// nothing — we generate snippets ourselves: strip tags, decode the few common
/// XML entities, then window `radius` characters around the first hit of the
/// query's first token. Returns a leading excerpt when there is no hit.
String encartaSnippet(String xmlText, String query, {int radius = 120}) {
  final text = xmlText
      .replaceAll(_tagRe, ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(_wsRe, ' ')
      .trim();
  if (text.isEmpty) return '';

  final term = query
      .split(_wsRe)
      .firstWhere((t) => t.isNotEmpty, orElse: () => '');

  String excerpt() =>
      text.length <= radius * 2 ? text : '${text.substring(0, radius * 2).trim()}…';

  if (term.isEmpty) return excerpt();

  final idx = text.toLowerCase().indexOf(term.toLowerCase());
  if (idx < 0) return excerpt();

  var start = idx - radius;
  var end = idx + term.length + radius;
  final hasLead = start > 0;
  final hasTrail = end < text.length;
  if (start < 0) start = 0;
  if (end > text.length) end = text.length;

  final core = text.substring(start, end).trim();
  return '${hasLead ? '…' : ''}$core${hasTrail ? '…' : ''}';
}
