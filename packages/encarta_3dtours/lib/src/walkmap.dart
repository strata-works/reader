import 'dart:typed_data';

/// The tour's walkable-ground surface: a triangle soup queried for ground
/// height under an (x, z) column. Backed by the `.3wm` "walkmap" mesh the
/// original engine loads (`WALKMAP.LOAD(`), extracted into a flat sidecar by
/// tool/materialize_tour_assets.py.
///
/// Byte format: `u32 triCount` (LE), then `triCount * 9` LE f32 — three
/// xyz vertices per triangle.
class Walkmap {
  final Float64List _tris; // 9 doubles per triangle

  Walkmap.fromTriangles(List<double> flatXyz)
      : assert(flatXyz.length % 9 == 0),
        _tris = Float64List.fromList(flatXyz);

  factory Walkmap.fromBytes(ByteData bytes) {
    final count = bytes.getUint32(0, Endian.little);
    final flat = List<double>.generate(
      count * 9,
      (i) => bytes.getFloat32(4 + i * 4, Endian.little),
    );
    return Walkmap.fromTriangles(flat);
  }

  int get triangleCount => _tris.length ~/ 9;

  /// The ground height under (x, z), or null when the point is off the map.
  /// With overlapping walkable layers, the highest ground wins.
  double? groundHeightAt(double x, double z) {
    double? best;
    for (var t = 0; t < _tris.length; t += 9) {
      final ax = _tris[t], ay = _tris[t + 1], az = _tris[t + 2];
      final bx = _tris[t + 3], by = _tris[t + 4], bz = _tris[t + 5];
      final cx = _tris[t + 6], cy = _tris[t + 7], cz = _tris[t + 8];
      // Barycentric coordinates in the XZ plane.
      final den = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
      if (den.abs() < 1e-12) continue; // degenerate footprint
      final w0 = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / den;
      final w1 = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / den;
      final w2 = 1.0 - w0 - w1;
      const eps = -1e-9;
      if (w0 < eps || w1 < eps || w2 < eps) continue; // outside
      final y = w0 * ay + w1 * by + w2 * cy;
      if (best == null || y > best) best = y;
    }
    return best;
  }
}
