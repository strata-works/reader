// app/encarta_reader/lib/src/screens/article/media_rail.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

/// Right pane: vertical list of block-level media figures.
///
/// Chooses the rendering widget by [MediaItem.kind], falling back to file
/// extension for corpus items misclassified as `kind == 'other'` (e.g. `.wmv`
/// videos and `.wma` audio stored under kind='other' in the ETL output).
///
/// DEVIATION FROM BRIEF: adds `assets` parameter (required) because
/// [EncartaImage], [EncartaAudio], and [EncartaVideo] all require
/// `EncartaAssets` to resolve asset files — the brief's signature omitted it.
class MediaRail extends StatelessWidget {
  final List<MediaItem> media;

  /// Asset resolver forwarded to each media widget for file resolution.
  final EncartaAssets assets;

  const MediaRail({super.key, required this.media, required this.assets});

  // ---------------------------------------------------------------------------
  // Widget selection
  // ---------------------------------------------------------------------------

  /// Normalise ext: lower-case, strip leading dot.
  String _ext(MediaItem item) {
    final e = item.ext.toLowerCase();
    return e.startsWith('.') ? e.substring(1) : e;
  }

  /// Choose the correct media widget for [item].
  ///
  /// Priority:
  ///   1. `kind == 'audio'` or `kind == 'midi'` → [EncartaAudio]
  ///   2. `kind == 'video'`                     → [EncartaVideo]
  ///   3. `kind == 'image'`                     → [EncartaImage]
  ///   4. `kind == 'other'` (ETL quirk): resolve by extension:
  ///      - `.wmv` / `.mp4` / `.avi`            → [EncartaVideo]
  ///      - `.wma`                               → [EncartaAudio]
  ///      - image exts (`.dib`/`.bmp`/`.jpg`/`.gif`/`.png`) → [EncartaImage]
  ///      - unknown                              → [EncartaImage] (placeholder)
  ///   5. Any other/unknown kind                → [EncartaImage] (placeholder)
  Widget _figure(MediaItem item) {
    switch (item.kind) {
      case 'audio':
      case 'midi':
        return EncartaAudio(item: item, assets: assets);

      case 'video':
        return EncartaVideo(item: item, assets: assets);

      case 'image':
        return EncartaImage(item: item, assets: assets);

      case 'other':
        // Corpus quirk: WMV/WMA/DIB/BMP are ETL-misclassified as 'other'.
        final ext = _ext(item);
        if (ext == 'wmv' || ext == 'mp4' || ext == 'avi') {
          return EncartaVideo(item: item, assets: assets);
        }
        if (ext == 'wma') {
          return EncartaAudio(item: item, assets: assets);
        }
        // .dib, .bmp, .jpg, .gif, .png, and anything else → image (or placeholder)
        return EncartaImage(item: item, assets: assets);

      default:
        // Unknown kind: never crash — degrade to EncartaImage placeholder.
        return EncartaImage(item: item, assets: assets);
    }
  }

  /// Whether the figure widget already renders caption + credit internally.
  /// [EncartaImage] does; [EncartaAudio] and [EncartaVideo] do not.
  bool _figureHasCaptionCredit(MediaItem item) {
    final kind = item.kind;
    if (kind == 'image') return true;
    if (kind == 'other') {
      final ext = _ext(item);
      // 'other' items that become EncartaImage render their own caption/credit
      return ext != 'wmv' && ext != 'mp4' && ext != 'avi' && ext != 'wma';
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: media.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final item = media[i];
        final figure = _figure(item);
        // EncartaImage already renders caption + credit; only append them
        // for audio/video figures to avoid duplication.
        if (_figureHasCaptionCredit(item)) return figure;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            figure,
            if (item.caption != null && item.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.caption!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (item.credit != null && item.credit!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Credit: ${item.credit}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      },
    );
  }
}
