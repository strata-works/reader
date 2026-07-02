import 'dart:io';

import 'package:encarta_data/encarta_data.dart';

/// Run: dart run tool/probe_thumbnail_role.dart [dataDir]
///
/// Samples featured + search-hit articles and reports, per role,
/// how many resolve to a real file on disk — mirroring EncartaAssets.resolvePath
/// (checks assets_derived first, then assets), but without importing Flutter.
Future<void> main(List<String> args) async {
  final dataDir = args.isNotEmpty
      ? args.first
      : '/Users/nexus/projects/experiments/strata/quarry/build';

  final dbPath = '$dataDir/encarta.sqlite';
  if (!File(dbPath).existsSync()) {
    // ignore: avoid_print
    print('ERROR: DB not found at $dbPath');
    exit(1);
  }

  final assetsDir = '$dataDir/assets';
  final derivedDir = '$dataDir/assets_derived';

  File? resolvePath(String assetPath) {
    final derived = File('$derivedDir/$assetPath');
    if (derived.existsSync()) return derived;
    final original = File('$assetsDir/$assetPath');
    if (original.existsSync()) return original;
    return null;
  }

  final db = await EncartaDb.open(dbPath);

  final counts = <String, int>{};
  final resolved = <String, int>{};
  final sizes = <String, List<int>>{};
  final exts = <String, Map<String, int>>{};
  final transparentCount = <String, int>{};

  // Collect refids: featured + broad search sample
  final refids = <int>{};
  final feats = await db.featured(limit: 50);
  for (final f in feats) {
    refids.add(f.refid);
  }
  for (final q in ['history', 'science', 'animal', 'country', 'water', 'life', 'art', 'war']) {
    final hits = await db.search(q, limit: 50);
    for (final h in hits) {
      refids.add(h.refid);
    }
  }

  // ignore: avoid_print
  print('Sampling ${refids.length} articles...');

  for (final refid in refids) {
    final media = await db.mediaForArticle(refid);
    for (final m in media) {
      counts[m.role] = (counts[m.role] ?? 0) + 1;
      final file = resolvePath(m.assetPath);
      if (file != null) {
        resolved[m.role] = (resolved[m.role] ?? 0) + 1;
        final size = file.lengthSync();
        (sizes[m.role] ??= []).add(size);
        final ext = m.ext.toLowerCase();
        (exts[m.role] ??= {})[ext] = ((exts[m.role] ?? {})[ext] ?? 0) + 1;
        // Detect transparent.gif placeholder: tiny gif files (< 200 bytes)
        if (ext == 'gif' && size < 200) {
          transparentCount[m.role] = (transparentCount[m.role] ?? 0) + 1;
        }
      }
    }
  }

  // ignore: avoid_print
  print('\n--- Thumbnail role probe results ---');
  final allRoles = [
    'thumb', 'ticon', 'picon', 'image',
    ...counts.keys.where((r) => !['thumb', 'ticon', 'picon', 'image'].contains(r)),
  ];
  for (final role in allRoles) {
    final seen = counts[role] ?? 0;
    if (seen == 0) continue;
    final res = resolved[role] ?? 0;
    final transparent = transparentCount[role] ?? 0;
    final rate = (res / seen * 100).toStringAsFixed(1);
    final sizeList = sizes[role] ?? [];
    final avgSize = sizeList.isEmpty
        ? 0
        : sizeList.reduce((a, b) => a + b) ~/ sizeList.length;
    final extMap = exts[role] ?? {};
    // ignore: avoid_print
    print('$role: seen=$seen resolved=$res ($rate%) transparent_gifs=$transparent avg_size=${avgSize}B exts=$extMap');
  }

  await db.close();
}
