import 'package:encarta_data/encarta_data.dart';
import 'package:encarta_render/encarta_render.dart';
import 'package:flutter/material.dart';

/// Left pane: "In this article" outline + "Related" outbound xrefs.
class ArticleOutlinePane extends StatelessWidget {
  final EncartaOutline outline;
  final List<XrefTarget> related;
  final void Function(String anchorId) onOutlineTap;
  final void Function(int refid) onRelatedTap;

  const ArticleOutlinePane({
    super.key,
    required this.outline,
    required this.related,
    required this.onOutlineTap,
    required this.onRelatedTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (outline.entries.isNotEmpty) ...[
          const Text('In this article',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in outline.entries)
            Padding(
              padding: EdgeInsets.only(left: 12.0 * e.depth),
              child: InkWell(
                onTap: () => onOutlineTap(e.anchorId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(e.title),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (related.isNotEmpty) ...[
          const Text('Related',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final x in related)
            InkWell(
              onTap: () => onRelatedTap(x.targetRefid),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(x.title,
                    style: const TextStyle(decoration: TextDecoration.underline)),
              ),
            ),
        ],
      ],
    );
  }
}
