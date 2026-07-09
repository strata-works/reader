import 'package:vector_math/vector_math_64.dart';

class Hotspot {
  final String id;
  final String text;
  final Vector3 anchor;
  final double angle;
  final int? icon;
  const Hotspot({
    required this.id,
    required this.text,
    required this.anchor,
    required this.angle,
    this.icon,
  });
}

class TourLight {
  final String name;
  final Vector3 position;
  final int r, g, b;
  const TourLight({
    required this.name,
    required this.position,
    required this.r,
    required this.g,
    required this.b,
  });
  List<int> color3() => [r, g, b];
}

class Tour {
  final String id;
  final String name;
  final List<Hotspot> hotspots;
  final List<TourLight> lights;
  const Tour({
    required this.id,
    required this.name,
    required this.hotspots,
    required this.lights,
  });
}
