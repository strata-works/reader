// Loads a 3-D tour's model + hotspot/light data from the app's bundled
// Flutter assets (AssetBundle), NOT dart:io. The Task-1 flutter_scene spike
// established that .model/.glb geometry must ship as bundled Flutter assets
// (declared under `flutter: assets:` in pubspec.yaml) rather than files read
// from an arbitrary data directory — so this adapter reads the tour's JSON
// via rootBundle (or an injected AssetBundle for tests) and returns the glb
// + point-cloud asset KEYS for Task 7's flutter_scene view to load.
import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter/services.dart';

class TourAssetsMissing implements Exception {
  final String message;
  TourAssetsMissing(this.message);
  @override
  String toString() => 'TourAssetsMissing: $message';
}

class TourAssets {
  final Tour tour;
  final String glbAsset;
  final String pointsAsset;
  const TourAssets(this.tour, this.glbAsset, this.pointsAsset);
}

const _tourNames = {'acropolis': 'Acropolis'};
// quarry file stem within each tour's asset dir (Acropolis = 'acr').
const _fileStem = {'acropolis': 'acr'};

/// Loads a tour's JSON via [bundle] (defaults to [rootBundle]) and returns
/// the model + the glb/points asset keys. Throws [TourAssetsMissing] if the
/// JSON assets are absent (e.g. tourId unknown / not materialized).
Future<TourAssets> loadTour(String tourId, {AssetBundle? bundle}) async {
  final assetBundle = bundle ?? rootBundle;
  final stem = _fileStem[tourId] ?? tourId;
  final baseDir = 'assets/3dtours/$tourId';
  final sceneKey = '$baseDir/$stem.scene.json';
  final hotspotsKey = '$baseDir/$stem.hotspots.json';

  String sceneJson;
  String hotspotsJson;
  try {
    sceneJson = await assetBundle.loadString(sceneKey);
    hotspotsJson = await assetBundle.loadString(hotspotsKey);
  } catch (_) {
    throw TourAssetsMissing(
        'Tour "$tourId" assets not found — run tool/materialize_tour_assets.py');
  }

  final tour = Tour(
    id: tourId,
    name: _tourNames[tourId] ?? tourId,
    hotspots: parseHotspots(hotspotsJson),
    lights: parseScene(sceneJson),
  );
  return TourAssets(tour, '$baseDir/$stem.glb', '$baseDir/${stem}_points.bin');
}
