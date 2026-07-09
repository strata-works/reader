// Verifies tour_adapter.loadTour builds a Tour + resolves the glb/points
// asset keys by reading the materialized JSON via an AssetBundle (NOT
// dart:io — flutter_scene assets are bundled Flutter assets per the Task-1
// spike finding). Uses a stub AssetBundle with in-memory fixtures so this
// test does not depend on the real bundled files under assets/3dtours/.
import 'dart:convert';
import 'dart:typed_data';

import 'package:encarta_reader/src/screens/tours/tour_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAssetBundle extends CachingAssetBundle {
  final Map<String, String> strings;
  _StubAssetBundle(this.strings);

  @override
  Future<ByteData> load(String key) async {
    final v = strings[key];
    if (v == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    final bytes = utf8.encode(v);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = strings[key];
    if (v == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return v;
  }
}

void main() {
  final validBundle = _StubAssetBundle({
    'assets/3dtours/acropolis/acr.scene.json':
        '{"nodes":[],"lights":[{"name":"L","position":[1,2,3],"color":[1,30,83]}],"cloud_placements":[]}',
    'assets/3dtours/acropolis/acr.hotspots.json':
        '[{"id":"_H26","text":"Coloring the Sculptures","anchor":[0.42,1.44,3.98,183.6],"icon":6,"macros":{}}]',
  });

  test('loadTour parses fixtures from the asset bundle', () async {
    final a = await loadTour('acropolis', bundle: validBundle);
    expect(a.tour.hotspots.single.text, 'Coloring the Sculptures');
    expect(a.tour.lights.single.b, 83);
    expect(a.glbAsset, 'assets/3dtours/acropolis/acr.glb');
    expect(a.pointsAsset, 'assets/3dtours/acropolis/acr_points.bin');
  });

  test('loadTour throws TourAssetsMissing when assets absent', () async {
    final emptyBundle = _StubAssetBundle(const {});
    expect(() => loadTour('nope', bundle: emptyBundle),
        throwsA(isA<TourAssetsMissing>()));
  });
}
