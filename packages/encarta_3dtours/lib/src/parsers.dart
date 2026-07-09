import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import 'models.dart';

List<Hotspot> parseHotspots(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  final out = <Hotspot>[];
  for (final e in list.cast<Map<String, dynamic>>()) {
    final text = (e['text'] as String?) ?? '';
    if (text.isEmpty) continue;
    final a = (e['anchor'] as List).cast<num>();
    out.add(Hotspot(
      id: e['id'] as String,
      text: text,
      anchor: Vector3(a[0].toDouble(), a[1].toDouble(), a[2].toDouble()),
      angle: a.length > 3 ? a[3].toDouble() : 0.0,
      icon: e['icon'] as int?,
    ));
  }
  return out;
}

List<TourLight> parseScene(String jsonStr) {
  final root = jsonDecode(jsonStr) as Map<String, dynamic>;
  final lights = (root['lights'] as List?) ?? const [];
  return [
    for (final l in lights.cast<Map<String, dynamic>>())
      TourLight(
        name: l['name'] as String,
        position: () {
          final p = (l['position'] as List).cast<num>();
          return Vector3(p[0].toDouble(), p[1].toDouble(), p[2].toDouble());
        }(),
        r: (l['color'] as List)[0] as int,
        g: (l['color'] as List)[1] as int,
        b: (l['color'] as List)[2] as int,
      ),
  ];
}
