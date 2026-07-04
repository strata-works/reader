// One-time tool: transcodes the MindMaze art referenced by the decoded castle from
// the extracted .dib into assets_derived/mindmaze/<id>.png. Sprites get their
// cyan key turned transparent; backdrops stay opaque. Run once locally:
//   dart run tool/transcode_mindmaze_art.dart
// (the output dir is under the gitignored quarry build dir, so PNGs are not
// committed; packaging them with the app is Phase 6.)
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'mindmaze_transcode_core.dart';

const _sprites = [
  'jester1', 'king1', 'duke1', 'suitarm1', 'secnldy1', 'servant1',
  'sorceres', 'alchem', 'asiantra', 'parrot', 'maninst',
];
const _backdrops = [
  'atrium', 'dunrm', 'walltre1', 'walltre2', 'bookshlf', 'plnwalls', 'rmofdoor',
  'end1', 'trophy', // end-screen art (opaque, not cyan-keyed)
];

const _dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

void main() {
  final db = sqlite3.open('$_dataDir/encarta.sqlite', mode: OpenMode.readOnly);
  final outDir = Directory('$_dataDir/assets_derived/mindmaze')
    ..createSync(recursive: true);

  void run(String id, {required bool key}) {
    final rows = db.select(
      "SELECT path FROM asset WHERE source='MINDMAZE.EIT' AND baggage_id=?",
      [id],
    );
    if (rows.isEmpty) {
      stderr.writeln('SKIP $id: no asset row');
      return;
    }
    final src = File('$_dataDir/assets/${rows.first['path']}');
    if (!src.existsSync()) {
      stderr.writeln('SKIP $id: file missing ${src.path}');
      return;
    }
    final out = File('${outDir.path}/$id.png');
    out.writeAsBytesSync(keyCyanToPng(src.readAsBytesSync(), key: key));
    stdout.writeln('wrote ${out.path}');
  }

  for (final id in _sprites) {
    run(id, key: true);
  }
  for (final id in _backdrops) {
    run(id, key: false);
  }
  db.dispose();
}
