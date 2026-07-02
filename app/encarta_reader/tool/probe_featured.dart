import 'package:encarta_data/encarta_data.dart';

/// Run: dart run tool/probe_featured.dart [dataDir]
/// Prints featured() titles so we can confirm media.group='home' is real portal content.
Future<void> main(List<String> args) async {
  final dataDir = args.isNotEmpty
      ? args.first
      : '/Users/nexus/projects/experiments/strata/quarry/build';
  final db = await EncartaDb.open('$dataDir/encarta.sqlite');

  final feats = await db.featured(limit: 12);
  // ignore: avoid_print
  print('featured() returned ${feats.length} title(s):');
  var allValid = true;
  for (final t in feats) {
    final article = await db.getArticle(t.refid);
    final valid = article != null;
    if (!valid) allValid = false;
    // ignore: avoid_print
    print('  ${valid ? 'OK' : 'MISSING'}\t${t.refid}\t${t.title}');
  }
  // ignore: avoid_print
  print(allValid ? 'ALL refids open a real article.' : 'WARNING: some refids are missing!');

  await db.close();
}
