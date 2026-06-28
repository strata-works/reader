import 'dart:typed_data';

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One article: identity, resolved title, source tier, and raw XML body bytes.
class Article {
  const Article({
    required this.refid,
    required this.title,
    required this.source,
    required this.xmlBytes,
  });

  final int refid;
  final String title;
  final String source;
  final Uint8List xmlBytes;

  @override
  bool operator ==(Object other) =>
      other is Article &&
      other.refid == refid &&
      other.title == title &&
      other.source == source &&
      _bytesEqual(other.xmlBytes, xmlBytes);

  @override
  int get hashCode => Object.hash(refid, title, source, xmlBytes.length);
}

/// A search result: target article id, its title, and the bm25 rank
/// (lower = more relevant; bm25 returns negative scores).
class SearchHit {
  const SearchHit({required this.refid, required this.title, required this.rank});

  final int refid;
  final String title;
  final double rank;

  @override
  bool operator ==(Object other) =>
      other is SearchHit &&
      other.refid == refid &&
      other.title == title &&
      other.rank == rank;

  @override
  int get hashCode => Object.hash(refid, title, rank);
}

/// One media slot for an article: its role + group, optional editorial text,
/// and the resolved asset (`assetPath` is RELATIVE to `<dataDir>/assets/`).
class MediaItem {
  const MediaItem({
    required this.mediaRefid,
    required this.role,
    required this.group,
    this.title,
    this.caption,
    this.credit,
    required this.assetPath,
    required this.ext,
    required this.kind,
  });

  final int mediaRefid;
  final String role;
  final String group;
  final String? title;
  final String? caption;
  final String? credit;
  final String assetPath;
  final String ext;
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is MediaItem &&
      other.mediaRefid == mediaRefid &&
      other.role == role &&
      other.group == group &&
      other.title == title &&
      other.caption == caption &&
      other.credit == credit &&
      other.assetPath == assetPath &&
      other.ext == ext &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(
      mediaRefid, role, group, title, caption, credit, assetPath, ext, kind);
}
