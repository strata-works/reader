import 'package:encarta_render/encarta_render.dart';

/// §10 title degradation: DB title → first outline entry title → "Article <refid>".
String resolveDisplayTitle({
  required int refid,
  required String dbTitle,
  required EncartaOutline outline,
}) {
  if (dbTitle.trim().isNotEmpty) return dbTitle;
  for (final e in outline.entries) {
    if (e.title.trim().isNotEmpty) return e.title;
  }
  return 'Article $refid';
}
