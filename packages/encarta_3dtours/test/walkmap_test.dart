import 'dart:typed_data';

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

ByteData _pack(List<double> flat) {
  final b = BytesBuilder();
  final head = ByteData(4)..setUint32(0, flat.length ~/ 9, Endian.little);
  b.add(head.buffer.asUint8List());
  final f = ByteData(flat.length * 4);
  for (var i = 0; i < flat.length; i++) {
    f.setFloat32(i * 4, flat[i], Endian.little);
  }
  b.add(f.buffer.asUint8List());
  final bytes = b.toBytes();
  return ByteData.sublistView(bytes);
}

void main() {
  // One right triangle in the XZ plane, sloping in y: (0,0,0) (4,0,0) (0,4,4).
  const tri = <double>[0, 0, 0, 4, 0, 0, 0, 4, 4];

  test('point inside a triangle returns barycentric height', () {
    final wm = Walkmap.fromTriangles(tri);
    // At (1, 1): weights put us 1/4 along the z-sloping edge -> y = 1.
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
    // Flat corner region.
    expect(wm.groundHeightAt(2, 0.5), closeTo(0.5, 1e-6));
  });

  test('point outside every triangle returns null', () {
    final wm = Walkmap.fromTriangles(tri);
    expect(wm.groundHeightAt(-1, -1), isNull);
    expect(wm.groundHeightAt(10, 10), isNull);
  });

  test('overlapping triangles: highest ground wins', () {
    final wm = Walkmap.fromTriangles([
      ...tri, // height ~1 at (1,1)
      0, 5, 0, 4, 5, 0, 0, 5, 4, // same footprint, flat at y=5
    ]);
    expect(wm.groundHeightAt(1, 1), closeTo(5.0, 1e-6));
  });

  test('degenerate (zero-area) triangles are skipped, not NaN', () {
    final wm = Walkmap.fromTriangles([0, 9, 0, 0, 9, 0, 0, 9, 0, ...tri]);
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
  });

  test('fromBytes parses the packed sidecar format', () {
    final wm = Walkmap.fromBytes(_pack(tri));
    expect(wm.triangleCount, 1);
    expect(wm.groundHeightAt(1, 1), closeTo(1.0, 1e-6));
    expect(wm.groundHeightAt(10, 10), isNull);
  });
}
