// packages/encarta_assets/lib/src/encarta_image.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import 'caption_text.dart';
import 'dib_shim.dart';
import 'encarta_assets_base.dart';

/// Renders a block-level article image from a [MediaItem]. Resolves the file
/// (preferring derived assets), applies the `.dib` shim when needed, and
/// degrades to a labeled placeholder — still showing [MediaItem.caption] and
/// [MediaItem.credit] — on any miss or decode failure (graceful degradation).
class EncartaImage extends StatelessWidget {
  const EncartaImage({
    super.key,
    required this.item,
    required this.assets,
    this.maxWidth = 480,
  });

  final MediaItem item;
  final EncartaAssets assets;
  final double maxWidth;

  /// Process-wide cache keyed by resolved file path; survives rebuilds.
  static final DibShim _sharedShim = DibShim();

  bool get _isDib => item.ext.toLowerCase() == '.dib';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageArea(context),
          if (item.caption != null && item.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CaptionText(
                item.caption!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (item.credit != null && item.credit!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CaptionText(
                'Credit: ${item.credit!}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns the image widget, or the labeled placeholder on miss / error.
  Widget _buildImageArea(BuildContext context) {
    final file = assets.resolvePath(item.assetPath);

    // MISS — surface placeholder immediately (caption/credit still shown above).
    if (file == null) return _placeholder(context);

    // .dib: synchronously read + convert to BMP, then decode in-memory.
    if (_isDib) {
      try {
        final rawBytes = file.readAsBytesSync();
        final bmpBytes = _sharedShim.toBmpCached(file.path, rawBytes);
        return Image.memory(
          bmpBytes,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      } catch (_) {
        return _placeholder(context);
      }
    }

    // All other resolved formats: Image.file (lazy decode, no extra copy).
    return Image.file(
      file,
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        key: const ValueKey('encarta-image-placeholder'),
        height: 120,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: const Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: Color(0xFF9E9E9E),
        ),
      );
}
