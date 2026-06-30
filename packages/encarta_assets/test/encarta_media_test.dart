// packages/encarta_assets/test/encarta_media_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _audio() => MediaItem(
      mediaRefid: 7,
      role: 'audio',
      group: 'media',
      title: 'Clip',
      caption: null,
      credit: null,
      assetPath: 'audio/missing.wma',
      ext: '.wma',
      kind: 'audio',
    );

MediaItem _video() => MediaItem(
      mediaRefid: 8,
      role: 'item',
      group: 'media',
      title: 'Movie',
      caption: null,
      credit: null,
      assetPath: 'other/missing.wmv',
      ext: '.wmv',
      kind: 'other',
    );

// NOTE — async-error → poster path (spec §10, Finding 2):
// A lightweight unit test for the _openMedia() error branch would require
// either a real libmpv dylib (to create a Player that can then reject an open
// call) or a mockable Player seam that is not present in the current widget
// design.  Both approaches pull in libmpv, which is unavailable in the
// headless CI environment.  The async-error→poster path is therefore covered
// by the integration smoke test only.  If a Player factory / stub is
// introduced in future, add a test here using mediaKitInitOverride to prevent
// actual libmpv initialisation.
void main() {
  late Directory root;
  setUp(() =>
      root = Directory.systemTemp.createTempSync('encarta_assets_media'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('EncartaAudio shows "media unavailable" poster when missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EncartaAudio(item: _audio(), assets: assets))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media-unavailable')), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);
  });

  testWidgets('EncartaVideo shows "media unavailable" poster when missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EncartaVideo(item: _video(), assets: assets))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media-unavailable')), findsOneWidget);
  });
}
