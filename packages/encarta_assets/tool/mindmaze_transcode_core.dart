import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes [dibBytes] (a MindMaze BMP/DIB) and returns PNG bytes. When [key] is
/// true, every pixel equal to the sprite cyan key (RGB 0,255,255) is made fully
/// transparent so the sprite composites cleanly over a room backdrop; all other
/// pixels stay opaque. Backdrops pass `key: false` and stay fully opaque.
Uint8List keyCyanToPng(Uint8List dibBytes, {required bool key}) {
  final decoded = img.decodeImage(dibBytes);
  if (decoded == null) {
    throw ArgumentError('could not decode MindMaze image');
  }
  final image = decoded.convert(numChannels: 4); // ensure an alpha channel
  if (key) {
    for (final p in image) {
      if (p.r == 0 && p.g == 255 && p.b == 255) {
        p.a = 0;
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
