// One-time dev tool: copies the MindMaze audio referenced by Phase 6 from the
// content-addressed extraction into assets_derived/mindmaze_audio/<id>.<ext>
// (friendly names the app resolves at runtime). Run once locally:
//   dart run tool/copy_mindmaze_audio.dart
// Output is under the gitignored quarry build dir, so nothing is committed.
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

// Background music (MIDI) + ambience fallback + the wired SFX.
const _ids = <String>[
  'BGLOOP1', 'BGLOOP2', 'BGLOOP3', // MIDI loops (BGLOOP1 used; 2/3 available)
  'amb1', // ambience fallback if MIDI won't play
  'right', 'wrong', 'dooropen', // SFX
];

void main() {
  final db = sqlite3.open('$_dataDir/encarta.sqlite', mode: OpenMode.readOnly);
  final outDir = Directory('$_dataDir/assets_derived/mindmaze_audio')
    ..createSync(recursive: true);

  for (final id in _ids) {
    final rows = db.select(
      "SELECT path, ext FROM asset WHERE source='MINDMAZE.EIT' AND baggage_id=?",
      [id],
    );
    if (rows.isEmpty) {
      stderr.writeln('SKIP $id: no asset row');
      continue;
    }
    final src = File('$_dataDir/assets/${rows.first['path']}');
    if (!src.existsSync()) {
      stderr.writeln('SKIP $id: file missing ${src.path}');
      continue;
    }
    // ext column includes the leading dot (e.g. ".wav"); strip it.
    final ext = (rows.first['ext'] as String).replaceFirst('.', '');
    final out = File('${outDir.path}/$id.$ext');
    out.writeAsBytesSync(src.readAsBytesSync());
    stdout.writeln('wrote ${out.path}');
  }
  db.dispose();
}
