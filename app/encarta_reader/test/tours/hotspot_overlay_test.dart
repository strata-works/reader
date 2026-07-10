import 'package:encarta_reader/src/screens/tours/hotspot_overlay.dart';
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('tapping a projected marker fires onTap with the hotspot', (tester) async {
    Hotspot? tapped;
    final cam = OrbitCamera(target: Vector3.zero(), distance: 5);
    final hs = [Hotspot(id: '_H26', text: 'Coloring the Sculptures', anchor: Vector3.zero(), angle: 0, icon: 6)];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 800, height: 600,
        child: HotspotOverlay(
          hotspots: hs, camera: cam, viewport: const Size(800, 600),
          onTap: (h) => tapped = h,
        ),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('hotspot-_H26')));
    expect(tapped?.id, '_H26');
  });
}
