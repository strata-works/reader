import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

// Design-system palette (used throughout this file).
const _ink = Color(0xFF1B2831);
const _inkSoft = Color(0xFF51636D);
const _accentTeal = Color(0xFF159AC0);
const _linkBlue = Color(0xFF1466B8);
const _hairline = Color(0xFFD6E0E7);
const _activeItemBg = Color(0xFFE1F0F6);

/// Shared pane-label style: 11px w700 letterSpacing 1.1 UPPERCASE ink-soft.
const _paneLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
  color: _inkSoft,
);

/// Left pane: "In this article" outline + "Related" outbound xrefs.
class ArticleOutlinePane extends StatelessWidget {
  final EncartaOutline outline;
  final List<XrefTarget> related;
  final void Function(String anchorId) onOutlineTap;
  final void Function(int refid) onRelatedTap;

  /// When non-null, the matching outline entry is highlighted with the teal
  /// active-indicator (bg + 3px left bar + accent-teal w600 text).
  /// Callers need not pass this; it defaults to null (no active entry).
  final String? activeAnchorId;

  const ArticleOutlinePane({
    super.key,
    required this.outline,
    required this.related,
    required this.onOutlineTap,
    required this.onRelatedTap,
    this.activeAnchorId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      children: [
        if (outline.entries.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text('IN THIS ARTICLE', style: _paneLabelStyle),
          ),
          for (final e in outline.entries)
            _OutlineEntryTile(
              entry: e,
              isActive: e.anchorId == activeAnchorId,
              onTap: () => onOutlineTap(e.anchorId),
            ),
          const SizedBox(height: 8),
        ],
        if (related.isNotEmpty) ...[
          if (outline.entries.isNotEmpty)
            const Divider(height: 1, thickness: 1, color: _hairline),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text('RELATED', style: _paneLabelStyle),
          ),
          for (final x in related)
            _RelatedEntryTile(
              target: x,
              onTap: () => onRelatedTap(x.targetRefid),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Outline entry tile
// ---------------------------------------------------------------------------

class _OutlineEntryTile extends StatelessWidget {
  final OutlineEntry entry;
  final bool isActive;
  final VoidCallback onTap;

  const _OutlineEntryTile({
    required this.entry,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 13.5,
      fontWeight:
          (entry.depth == 0 || isActive) ? FontWeight.w600 : FontWeight.w400,
      color: isActive ? _accentTeal : (entry.depth == 0 ? _ink : _inkSoft),
    );

    // The 3px left accent bar is realised as a BoxDecoration border so it spans
    // the full tile height without IntrinsicHeight overhead.  A consistent left
    // indent (7 + 14*depth) keeps non-active entries visually aligned with the
    // active bar + 4px gap layout.
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? _activeItemBg : null,
          border: isActive
              ? const Border(
                  left: BorderSide(color: _accentTeal, width: 3),
                )
              : null,
        ),
        padding: EdgeInsets.fromLTRB(
          (isActive ? 4 : 7) + 14.0 * entry.depth,
          5,
          14,
          5,
        ),
        child: Text(
          entry.title,
          style: textStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Related entry tile (hover → underline)
// ---------------------------------------------------------------------------

class _RelatedEntryTile extends StatefulWidget {
  final XrefTarget target;
  final VoidCallback onTap;

  const _RelatedEntryTile({required this.target, required this.onTap});

  @override
  State<_RelatedEntryTile> createState() => _RelatedEntryTileState();
}

class _RelatedEntryTileState extends State<_RelatedEntryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: CaptionText(
            widget.target.title,
            style: TextStyle(
              fontSize: 13.5,
              color: _linkBlue,
              decoration:
                  _hovered ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
