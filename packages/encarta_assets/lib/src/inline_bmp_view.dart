// packages/encarta_assets/lib/src/inline_bmp_view.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import 'encarta_assets_base.dart';
import 'encarta_image.dart';

/// Inline bitmap widget returned by [EncartaAssets.inlineBmp].
///
/// `inlinebmp` ids come in two flavours REGARDLESS of the `type` attribute:
///  * an 8-hex `asset.baggage_id` (type 27 AND many type 28) → resolves to a
///    stored image (usually `.gif`/`.dib`) → render an [EncartaImage].
///  * an original `NAME.DIB` filename (some type 28) → not in the asset store →
///    resolves to null → placeholder.
/// So we ALWAYS attempt `db.assetByBaggageId(id)` and let the lookup decide,
/// rather than gating on `type` (which mis-classified resolvable type-28 gifs
/// as placeholders). Never throws.
///
/// The DB lookup is performed exactly once per widget instance (in State
/// initialisation) so that parent rebuilds, theme changes, and scroll events
/// do not trigger redundant `assetByBaggageId` queries.
class InlineBmpView extends StatefulWidget {
  const InlineBmpView({
    super.key,
    required this.assets,
    required this.inlineId,
    required this.inlineType,
  });

  final EncartaAssets assets;
  final String inlineId;
  final int inlineType;

  @override
  State<InlineBmpView> createState() => _InlineBmpViewState();
}

class _InlineBmpViewState extends State<InlineBmpView> {
  static const _placeholderKey = ValueKey('inlinebmp-placeholder');

  // Resolved once at State creation; never re-queried on rebuild.
  late final Future<AssetRow?> _future;

  @override
  void initState() {
    super.initState();
    _future = _lookup();
  }

  Future<AssetRow?> _lookup() async {
    try {
      return await widget.assets.db.assetByBaggageId(widget.inlineId);
    } catch (_) {
      return null; // never throw out of an inline glyph
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try to resolve every id as a baggage_id regardless of `type` — hex ids
    // resolve to a stored image, NAME.DIB ids resolve to null → placeholder.
    return FutureBuilder<AssetRow?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(width: 16, height: 16);
        }
        final row = snap.data;
        if (row == null) return _placeholder();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: EncartaImage(
            item: MediaItem(
              mediaRefid: -1,
              role: 'inlinebmp',
              group: 'inline',
              title: null,
              caption: null,
              credit: null,
              assetPath: row.path,
              ext: row.ext,
              kind: row.kind,
            ),
            assets: widget.assets,
            maxWidth: 240,
          ),
        );
      },
    );
  }

  // A quiet "figure unavailable" chip — a muted outlined box, not an alarming
  // broken-image glyph — for the rare ids that don't resolve (NAME.DIB) or a
  // format we can't decode.
  Widget _placeholder() => Container(
        key: _placeholderKey,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD6E0E7)),
        ),
        child: const Icon(Icons.image_outlined,
            size: 13, color: Color(0xFF9BAAB4)),
      );
}
