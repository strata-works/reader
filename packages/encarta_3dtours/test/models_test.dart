import 'package:vector_math/vector_math_64.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

void main() {
  test('Tour holds hotspots and lights', () {
    final t = Tour(
      id: 'acropolis',
      name: 'Acropolis',
      hotspots: [Hotspot(id: '_H26', text: 'Coloring the Sculptures', anchor: Vector3(0.42, 1.44, 3.98), angle: 183.64, icon: 6)],
      lights: [TourLight(name: '_TORCH4', position: Vector3(1.48, 0.23, -3.24), r: 1, g: 30, b: 83)],
    );
    expect(t.hotspots.single.text, 'Coloring the Sculptures');
    expect(t.hotspots.single.anchor.z, closeTo(3.98, 1e-6));
    expect(t.lights.single.b, 83);
  });
}
