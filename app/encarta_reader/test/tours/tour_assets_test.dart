// Verifies the materialized Acropolis tour assets under
// assets/3dtours/acropolis/ are present and parse correctly via the
// encarta_3dtours package's parsers. These JSON files are committed (small);
// the packed acr.glb is gitignored (regenerable via pack_assets.py) and is
// NOT read by this test.
import 'dart:io';

import 'package:encarta_3dtours/encarta_3dtours.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Resolve relative to this test file so it works regardless of the
  // invoking shell's cwd (flutter test may run from repo root or app dir).
  final assetsDir = Directory(
    p.join(
      p.dirname(Platform.script.toFilePath()),
      '..',
      '..',
      'assets',
      '3dtours',
      'acropolis',
    ),
  );
  final hotspotsFile = File(p.join(assetsDir.path, 'acr.hotspots.json'));
  final sceneFile = File(p.join(assetsDir.path, 'acr.scene.json'));

  // Fallback: when run via `flutter test` from app/encarta_reader, cwd IS
  // the package root, so also try a cwd-relative path if the script-relative
  // one didn't resolve (Platform.script can be unreliable under some runners).
  File resolveExisting(File primary, String relative) {
    if (primary.existsSync()) return primary;
    return File(p.join(Directory.current.path, relative));
  }

  final hotspots = resolveExisting(
    hotspotsFile,
    'assets/3dtours/acropolis/acr.hotspots.json',
  );
  final scene = resolveExisting(
    sceneFile,
    'assets/3dtours/acropolis/acr.scene.json',
  );

  test(
    'materialized Acropolis hotspots: 45 non-empty (of 108 total)',
    () {
      if (!hotspots.existsSync()) {
        markTestSkipped(
          'assets/3dtours/acropolis/acr.hotspots.json not materialized yet '
          '— run pack_assets.py to generate tour assets',
        );
        return;
      }
      final raw = hotspots.readAsStringSync();
      final parsed = parseHotspots(raw);
      expect(parsed.length, 45);
      for (final h in parsed) {
        expect(h.text, isNotEmpty);
      }
    },
  );

  test('materialized Acropolis scene: 71 lights', () {
    if (!scene.existsSync()) {
      markTestSkipped(
        'assets/3dtours/acropolis/acr.scene.json not materialized yet '
        '— run pack_assets.py to generate tour assets',
      );
      return;
    }
    final raw = scene.readAsStringSync();
    final lights = parseScene(raw);
    expect(lights.length, 71);
  });
}
