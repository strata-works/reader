// packages/encarta_assets/lib/src/dib_shim.dart
import 'dart:typed_data';

/// Converts a raw `.dib` (a BMP without its 14-byte file header) into a complete
/// BMP byte buffer that `Image.memory` can decode today.
///
/// Layout of a DIB:  [DIB info header][optional color palette][pixel data].
/// We read the info header to compute the palette size, derive the pixel-data
/// offset (`bfOffBits`) and total file size, then prepend a correct
/// `BITMAPFILEHEADER` ("BM", size, reserved, offset).
class DibShim {
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Cached variant keyed by [cacheKey] (use the resolved file path).
  Uint8List toBmpCached(String cacheKey, Uint8List dib) =>
      _cache.putIfAbsent(cacheKey, () => toBmp(dib));

  /// Pure transform: prepend a valid 14-byte BMP file header.
  static Uint8List toBmp(Uint8List dib) {
    // Guard: need at minimum enough bytes to read the biSize field and the
    // core header fields (bitCount at 14, compression at 16, clrUsed at 32).
    if (dib.length < 16) {
      throw ArgumentError('DIB too short: ${dib.length} bytes');
    }
    final info = ByteData.sublistView(dib);
    final biSize = info.getUint32(0, Endian.little);
    if (dib.length < biSize) {
      throw ArgumentError('DIB too short: ${dib.length} bytes');
    }

    // BITMAPCOREHEADER (12) packs fields differently; everything Encarta ships
    // is BITMAPINFOHEADER (>=40), but handle the core case defensively.
    int bitCount;
    int clrUsed;
    int paletteEntryBytes;
    if (biSize == 12) {
      bitCount = info.getUint16(10, Endian.little);
      clrUsed = 0;
      paletteEntryBytes = 3; // RGBTRIPLE
    } else {
      bitCount = info.getUint16(14, Endian.little);
      clrUsed = info.getUint32(32, Endian.little);
      paletteEntryBytes = 4; // RGBQUAD
    }

    // Number of palette entries.
    var numColors = clrUsed;
    if (numColors == 0 && bitCount <= 8) {
      numColors = 1 << bitCount;
    }
    final paletteBytes = numColors * paletteEntryBytes;

    // BI_BITFIELDS (compression==3) with a 40-byte BITMAPINFOHEADER stores 3
    // (or 4 for alpha-aware) 32-bit color masks AFTER the header. For
    // BITMAPV4HEADER (biSize=108) and BITMAPV5HEADER (biSize=124) those masks
    // are already embedded inside biSize, so no extra bytes are needed.
    var extraMaskBytes = 0;
    if (biSize == 40) {
      final compression = info.getUint32(16, Endian.little);
      if (compression == 3) extraMaskBytes = 12; // 3 DWORD masks
      if (compression == 6) extraMaskBytes = 16; // BI_ALPHABITFIELDS
    }

    const fileHeaderSize = 14;
    final offBits = fileHeaderSize + biSize + paletteBytes + extraMaskBytes;
    final fileSize = fileHeaderSize + dib.length;

    final out = Uint8List(fileSize);
    final header = ByteData.sublistView(out, 0, fileHeaderSize);
    header.setUint8(0, 0x42); // 'B'
    header.setUint8(1, 0x4D); // 'M'
    header.setUint32(2, fileSize, Endian.little); // bfSize
    header.setUint16(6, 0, Endian.little); // bfReserved1
    header.setUint16(8, 0, Endian.little); // bfReserved2
    header.setUint32(10, offBits, Endian.little); // bfOffBits
    out.setRange(fileHeaderSize, fileSize, dib);
    return out;
  }
}
