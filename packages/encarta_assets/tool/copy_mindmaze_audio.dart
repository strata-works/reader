// One-time dev tool: copies the MindMaze audio referenced by Phase 6 from the
// content-addressed extraction into assets_derived/mindmaze_audio/<id>.<ext>
// (friendly names the app resolves at runtime), then renders the MIDI loops to
// WAV so mpv — which cannot synthesize MIDI — can play the real music. Run once
// locally:
//   dart run tool/copy_mindmaze_audio.dart
// Output is under the gitignored quarry build dir, so nothing is committed.
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _dataDir = '/Users/nexus/projects/experiments/strata/quarry/build';

// A General MIDI soundfont for rendering the .mid loops. This machine has the
// FluidR3 GM2 bank; adjust if yours lives elsewhere. If it (or fluidsynth) is
// missing, MIDI rendering is skipped and the app falls back to looping ambience.
const _soundfont = '/usr/local/lift/Soundfonts/FluidR3_GM2-2.sf2';
const _midiLoops = <String>['BGLOOP1', 'BGLOOP2', 'BGLOOP3'];

// Background music (MIDI, rendered to WAV below) + ambience fallback + SFX.
const _ids = <String>[
  'BGLOOP1', 'BGLOOP2', 'BGLOOP3', // MIDI loops (BGLOOP1 is the wired background)
  'amb1', // ambience fallback if the rendered music is absent
  'right', 'wrong', 'dooropen', // SFX
];

/// Absolute path of [bin] on PATH, or null if not found.
String? _which(String bin) {
  final r = Process.runSync('which', [bin]);
  return r.exitCode == 0 ? (r.stdout as String).trim() : null;
}

/// Renders the MIDI loops to 44.1kHz stereo WAV with fluidsynth so mpv can play
/// them. Skips gracefully (the app falls back to ambience) if fluidsynth or the
/// soundfont is unavailable.
void _renderMidi(Directory outDir) {
  final fluidsynth = _which('fluidsynth');
  if (fluidsynth == null) {
    stderr.writeln('SKIP midi render: fluidsynth not on PATH');
    return;
  }
  if (!File(_soundfont).existsSync()) {
    stderr.writeln('SKIP midi render: soundfont missing $_soundfont');
    return;
  }
  for (final id in _midiLoops) {
    final mid = File('${outDir.path}/$id.mid');
    if (!mid.existsSync()) {
      stderr.writeln('SKIP render $id: no $id.mid (copy it first)');
      continue;
    }
    final wav = '${outDir.path}/$id.wav';
    final r = Process.runSync(fluidsynth,
        ['-ni', '-g', '1.0', '-F', wav, '-r', '44100', _soundfont, mid.path]);
    if (r.exitCode == 0 && File(wav).existsSync()) {
      stdout.writeln('rendered $wav');
    } else {
      stderr.writeln('SKIP render $id: fluidsynth exit ${r.exitCode}: ${r.stderr}');
    }
  }
}

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

  // Turn the copied MIDI loops into playable WAV music.
  _renderMidi(outDir);
}
