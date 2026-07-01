// app/encarta_reader/lib/src/screens/article/media_rail.dart
import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

// Design-system palette.
const _ink = Color(0xFF1B2831);
const _inkSoft = Color(0xFF51636D);
const _hairline = Color(0xFFD6E0E7);

/// Pane-label style: 11px w700 letterSpacing 1.1 UPPERCASE ink-soft.
const _paneLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
  color: _inkSoft,
);

/// Right pane: vertical list of block-level media figures.
///
/// Chooses the rendering widget by [MediaItem.kind], falling back to file
/// extension for corpus items misclassified as `kind == 'other'` (e.g. `.wmv`
/// videos and `.wma` audio stored under kind='other' in the ETL output).
///
/// Each figure is wrapped in a card (white bg, hairline border, radius 8,
/// padding 12, 12px vertical gap between cards).
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

  /// Builds a single media CARD: white bg, 1px hairline border, radius 8,
  /// 12px internal padding.  Layout: optional title → figure → optional
  /// caption + credit (only when [_figureHasCaptionCredit] is false).
  Widget _buildCard(BuildContext context, MediaItem item) {
    final figure = _figure(item);
    final hasCaptionCredit = _figureHasCaptionCredit(item);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _hairline, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card title row — always rendered when the item has a non-empty title.
          if (item.title != null && item.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CaptionText(
                item.title!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),

          // Figure: EncartaImage / EncartaAudio / EncartaVideo.
          figure,

          // Caption + credit only for audio/video (EncartaImage renders them
          // internally; forwarding them here would duplicate the text).
          if (!hasCaptionCredit) ...[
            if (item.caption != null && item.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CaptionText(
                  item.caption!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
              ),
            if (item.credit != null && item.credit!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CaptionText(
                  'Credit: ${item.credit!}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: _inkSoft,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        const Text('MEDIA', style: _paneLabelStyle),
        const SizedBox(height: 12),
        for (int i = 0; i < media.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildCard(context, media[i]),
        ],
      ],
    );
  }
}
