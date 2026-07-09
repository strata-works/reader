import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:test/test.dart';

const _hotspots = '''
[
  {"id":"_ZEUS2","text":"","anchor":[0,0,0,0],"icon":null,"macros":{}},
  {"id":"_H26","text":"Coloring the Sculptures","anchor":[0.422562,1.442125,3.977404,183.64006],"icon":6,"macros":{"MOUSEUP":"SCRIPT.EVENT(x)"}}
]''';

const _scene = '''
{"nodes":[{"name":"_TORCH4","transform":[1,0,0,0, 0,1,0,0, 0,0,1,0, 1.48,0.23,-3.24,1]}],
 "lights":[{"name":"_TORCH4","position":[1.48,0.23,-3.24],"color":[1,30,83]}],
 "cloud_placements":[]}''';

void main() {
  test('parseHotspots keeps only non-empty text and splits anchor/angle', () {
    final hs = parseHotspots(_hotspots);
    expect(hs.length, 1);
    expect(hs.single.id, '_H26');
    expect(hs.single.anchor.x, closeTo(0.422562, 1e-6));
    expect(hs.single.angle, closeTo(183.64006, 1e-5));
    expect(hs.single.icon, 6);
  });

  test('parseScene reads lights', () {
    final lights = parseScene(_scene);
    expect(lights.single.name, '_TORCH4');
    expect(lights.single.color3(), [1, 30, 83]);
  });
}
