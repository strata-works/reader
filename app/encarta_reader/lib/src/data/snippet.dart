import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_data/encarta_data.dart';

/// Decodes [xmlBytes] as UTF-8 and delegates to [encartaSnippet] to build a
/// plain-text snippet windowed around the first occurrence of [query].
///
/// Using [allowMalformed] so corrupted bytes never throw; the snippet logic
/// lives exclusively in [encartaSnippet] — no duplicate implementation here.
String makeSnippet(Uint8List xmlBytes, String query, {int radius = 120}) {
  final xmlText = utf8.decode(xmlBytes, allowMalformed: true);
  return encartaSnippet(xmlText, query, radius: radius);
}
