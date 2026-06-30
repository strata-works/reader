// packages/encarta_assets/lib/src/inline_bmp_view.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';

import 'encarta_assets_base.dart';
import 'encarta_image.dart';

/// Inline bitmap widget returned by [EncartaAssets.inlineBmp].
///
/// type==27: [inlineId] is an `asset.baggage_id` → resolve it through
/// `db.assetByBaggageId` and render an [EncartaImage] (which applies the `.dib`
/// shim if needed). type!=27: original NAME.DIB form, unresolvable today → small
/// placeholder. Never throws.
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
    // Only type-27 inlinebmp ids are asset.baggage_id values (verified).
    if (widget.inlineType != 27) return _placeholder();
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

  Widget _placeholder() => Container(
        key: _placeholderKey,
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Icon(Icons.image_not_supported, size: 12),
      );
}
