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
