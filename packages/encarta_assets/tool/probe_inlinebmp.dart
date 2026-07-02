// packages/encarta_assets/tool/probe_inlinebmp.dart
//
// Runtime verification of the inlinebmp id -> asset mapping.
// Run:  dart run tool/probe_inlinebmp.dart
//
// Findings (2026-06-25): type=27 ids ARE asset.baggage_id (resolvable);
// type=28 ids are original NAME.DIB filenames with no asset-table mapping
// (graceful placeholder). This script re-confirms that against the live DB.
import 'package:encarta_data/encarta_data.dart';

const _dbPath =
    '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';

Future<void> main() async {
  final db = await EncartaDb.open(_dbPath);
  // Sample type-27 ids confirmed to be baggage_ids during planning.
  const type27 = <String>['000f631b', '000f6e85', '000f3be2'];
  // Sample type-28 NAME.DIB ids confirmed NOT resolvable.
  const type28 = <String>['IIN7A0DF.DIB', 'INN7A0E4.DIB'];

  print('--- type=27 (expect: resolves via assetByBaggageId) ---');
  for (final id in type27) {
    final row = await db.assetByBaggageId(id);
    print('$id -> ${row?.path ?? 'NULL (unexpected!)'}');
  }
  print('--- type=28 NAME.DIB (expect: NULL → placeholder) ---');
  for (final id in type28) {
    final row = await db.assetByBaggageId(id);
    print('$id -> ${row?.path ?? 'NULL (expected; placeholder)'}');
  }
  await db.close();
}
