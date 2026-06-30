/// Maps an article's `source` tier to a short badge label.
String tierBadge(String source) {
  switch (source) {
    case 'CONTDLX':
      return 'Deluxe';
    case 'CONTSTD':
      return 'Standard';
    case 'CONTSTC':
      return 'Concise';
    case 'CONTKDC':
      return 'Kids';
    default:
      return source;
  }
}
