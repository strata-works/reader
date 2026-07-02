// packages/encarta_assets/test/encarta_image_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

MediaItem _item({required String path, required String ext, String? caption}) =>
    MediaItem(
      mediaRefid: 1,
      role: 'image',
      group: 'article',
      title: null,
      caption: caption,
      credit: 'Encarta',
      assetPath: path,
      ext: ext,
      kind: 'image',
    );

void main() {
  late Directory root;
  setUp(() =>
      root = Directory.systemTemp.createTempSync('encarta_assets_image'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('renders an Image widget for a resolvable non-dib file',
      (tester) async {
    // Use a valid BMP (via DibShim.toBmp) so the Flutter codec can decode it.
    final bmp = DibShim.toBmp(_syntheticDib());
    final f = File(p.join(root.path, 'assets', 'image', 'pic.bmp'));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bmp);

    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaImage(
          item: _item(path: 'image/pic.bmp', ext: '.bmp'),
          assets: assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // An Image widget must exist — we did NOT fall back to a plain placeholder.
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('decodes a .dib via the shim and shows an Image', (tester) async {
    final dib = _syntheticDib();
    final f = File(p.join(root.path, 'assets', 'other', 'pic.dib'));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(dib);

    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaImage(
          item: _item(path: 'other/pic.dib', ext: '.dib'),
          assets: assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows placeholder + caption/credit when asset is missing',
      (tester) async {
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncartaImage(
          item: _item(
              path: 'image/missing.jpg', ext: '.jpg', caption: 'A caption'),
          assets: assets,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('encarta-image-placeholder')),
        findsOneWidget);
    expect(find.text('A caption'), findsOneWidget);
    expect(find.textContaining('Encarta'), findsOneWidget);
  });
}

/// 2x2 24-bit DIB (same shape as the dib_shim test).
Uint8List _syntheticDib() {
  final info = ByteData(40);
  info.setUint32(0, 40, Endian.little);
  info.setInt32(4, 2, Endian.little);
  info.setInt32(8, 2, Endian.little);
  info.setUint16(12, 1, Endian.little);
  info.setUint16(14, 24, Endian.little);
  info.setUint32(16, 0, Endian.little);
  info.setUint32(20, 16, Endian.little);
  info.setUint32(32, 0, Endian.little);
  final pixels = Uint8List(16);
  return Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...pixels]);
}
