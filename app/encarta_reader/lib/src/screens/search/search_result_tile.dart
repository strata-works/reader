import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

import 'search_view.dart';

/// Left-column result row: thumbnail · title · snippet · tier badge.
///
/// [assets] is optional; when provided together with a non-null [item.thumb]
/// the full [EncartaImage] is rendered. Without it (or when [item.thumb] is
/// null) a lightweight placeholder icon is shown instead.
class SearchResultTile extends StatelessWidget {
  final SearchResultItem item;
  final VoidCallback onTap;

  /// Required only when [item.thumb] is non-null and the caller wants to
  /// render the actual thumbnail via [EncartaImage].
  final EncartaAssets? assets;

  const SearchResultTile({
    super.key,
    required this.item,
    required this.onTap,
    this.assets,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        key: const ValueKey('search-result-tile-bg'),
        color: item.selected ? Theme.of(context).highlightColor : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: _buildThumb(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.tierBadge,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    final thumb = item.thumb;
    final a = assets;
    if (thumb != null && a != null) {
      return EncartaImage(item: thumb, assets: a, maxWidth: 56);
    }
    return const Icon(Icons.article_outlined, size: 40);
  }
}
