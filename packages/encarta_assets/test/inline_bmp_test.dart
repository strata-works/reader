// packages/encarta_assets/test/inline_bmp_test.dart
import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Fakes only `assetByBaggageId`; any other DB access throws loudly.
class _FakeDb implements EncartaDb {
  _FakeDb(this._rows);
  final Map<String, AssetRow> _rows;

  @override
  Future<AssetRow?> assetByBaggageId(String baggageId) async =>
      _rows[baggageId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('only assetByBaggageId is faked');
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('encarta_assets_inlinebmp');
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('type != 27 (original NAME.DIB) → placeholder, no DB hit',
      (tester) async {
    // forTesting with the throwing stand-in DB proves no lookup is attempted.
    final assets = EncartaAssets.forTesting(AssetConfig(root.path));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: assets.inlineBmp('IIN7A0DF.DIB', 28))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsOneWidget);
  });

  testWidgets('type 27 with unknown baggage id → placeholder', (tester) async {
    final assets = EncartaAssets.forTesting(
      AssetConfig(root.path),
      db: _FakeDb(const {}),
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: assets.inlineBmp('000f631b', 27))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsOneWidget);
  });

  testWidgets('type 27 baggage id resolves to a file → renders an Image',
      (tester) async {
    // Write a tiny valid PNG so Image.memory can decode it.
    final f = File(p.join(root.path, 'assets', 'image', 'pic.png'));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(_onePixelPng());

    final assets = EncartaAssets.forTesting(
      AssetConfig(root.path),
      db: _FakeDb({
        '000f631b': const AssetRow(
          baggageId: '000f631b',
          hash: 'deadbeef',
          kind: 'image',
          ext: '.png',
          path: 'image/pic.png',
        ),
      }),
    );
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: assets.inlineBmp('000f631b', 27))));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('inlinebmp-placeholder')), findsNothing);
  });
}

/// Smallest valid 1x1 PNG (transparent).
List<int> _onePixelPng() => const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ];
