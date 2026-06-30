// packages/encarta_assets/test/dib_shim_test.dart
import 'dart:typed_data';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal 2x2, 24-bit DIB (BITMAPINFOHEADER, no palette).
/// Each 2px row = 6 bytes padded to 8 → 16 bytes of pixel data.
Uint8List buildSyntheticDib() {
  final info = ByteData(40);
  info.setUint32(0, 40, Endian.little); // biSize
  info.setInt32(4, 2, Endian.little); // biWidth
  info.setInt32(8, 2, Endian.little); // biHeight
  info.setUint16(12, 1, Endian.little); // biPlanes
  info.setUint16(14, 24, Endian.little); // biBitCount
  info.setUint32(16, 0, Endian.little); // biCompression = BI_RGB
  info.setUint32(20, 16, Endian.little); // biSizeImage
  info.setUint32(32, 0, Endian.little); // biClrUsed = 0
  final pixels = Uint8List(16); // 2 rows * 8 bytes
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = i; // arbitrary distinguishable content
  }
  return Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...pixels]);
}

void main() {
  test('prepends a valid 14-byte BM header for a 24-bit DIB', () {
    final dib = buildSyntheticDib();
    final bmp = DibShim.toBmp(dib);

    // BM signature.
    expect(bmp[0], 0x42); // 'B'
    expect(bmp[1], 0x4D); // 'M'

    final bd = ByteData.sublistView(bmp);
    // bfSize == 14 + dib.length.
    expect(bd.getUint32(2, Endian.little), 14 + dib.length);
    // bfReserved1/2 == 0.
    expect(bd.getUint32(6, Endian.little), 0);
    // bfOffBits: no palette for 24-bit → 14 + 40 = 54.
    expect(bd.getUint32(10, Endian.little), 54);

    // Total length and that the DIB payload follows the header unchanged.
    expect(bmp.length, 14 + dib.length);
    expect(bmp.sublist(14), dib);
  });

  test('computes palette offset for an 8-bit DIB (256-color table)', () {
    final info = ByteData(40);
    info.setUint32(0, 40, Endian.little); // biSize
    info.setInt32(4, 1, Endian.little); // biWidth
    info.setInt32(8, 1, Endian.little); // biHeight
    info.setUint16(12, 1, Endian.little); // biPlanes
    info.setUint16(14, 8, Endian.little); // biBitCount = 8
    info.setUint32(16, 0, Endian.little); // biCompression
    info.setUint32(32, 0, Endian.little); // biClrUsed = 0 → 256 colors
    // 256 colors * 4 bytes + 4 bytes pixel row.
    final body = Uint8List(256 * 4 + 4);
    final dib =
        Uint8List.fromList(<int>[...info.buffer.asUint8List(), ...body]);
    final bmp = DibShim.toBmp(dib);
    final bd = ByteData.sublistView(bmp);
    // bfOffBits = 14 + 40 + 256*4 = 1078.
    expect(bd.getUint32(10, Endian.little), 1078);
  });

  test('cache returns identical instance for the same key', () {
    final dib = buildSyntheticDib();
    final shim = DibShim();
    final a = shim.toBmpCached('k1', dib);
    final b = shim.toBmpCached('k1', dib);
    expect(identical(a, b), isTrue);
  });
}
