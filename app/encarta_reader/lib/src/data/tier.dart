/// Maps an article's `source` tier to a short badge label.
///
/// Matches by prefix so both bare codes (`CONTDLX`) and corpus values with
/// a `.AKC` suffix (`CONTDLX.AKC`) resolve to the correct label.
String tierBadge(String source) {
  final s = source.toUpperCase();
  if (s.startsWith('CONTDLX')) return 'Deluxe';
  if (s.startsWith('CONTSTD')) return 'Standard';
  if (s.startsWith('CONTSTC')) return 'Concise';
  if (s.startsWith('CONTKDC')) return 'Kids';
  return source;
}
