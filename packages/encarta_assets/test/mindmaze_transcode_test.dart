import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

import '../tool/mindmaze_transcode_core.dart';

void main() {
  test('keyed: cyan pixels become transparent, others stay opaque', () {
    final src = img.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 0, 255, 255) // cyan key
      ..setPixelRgb(1, 0, 10, 20, 30); // ordinary
    final bmp = Uint8List.fromList(img.encodeBmp(src));

    final png = keyCyanToPng(bmp, key: true);
    final out = img.decodePng(png)!;

    expect(out.getPixel(0, 0).a, 0, reason: 'cyan → transparent');
    expect(out.getPixel(1, 0).a, 255, reason: 'non-cyan → opaque');
  });

  test('not keyed: cyan stays fully opaque (backdrop)', () {
    final src = img.Image(width: 1, height: 1)..setPixelRgb(0, 0, 0, 255, 255);
    final png = keyCyanToPng(Uint8List.fromList(img.encodeBmp(src)), key: false);
    final out = img.decodePng(png)!;
    expect(out.getPixel(0, 0).a, 255);
  });
}
