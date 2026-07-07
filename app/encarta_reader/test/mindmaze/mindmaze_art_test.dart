import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/mindmaze_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unit-level (no pumpWidget): asserting the RETURNED widget type avoids
  // rendering Image.file, whose real async codec never settles under
  // flutter_test and hangs the test to a 10-minute timeout.

  test('missing derived PNG → labeled placeholder container (not an Image)', () {
    final w = mindMazeArt(const AssetConfig('/no/such/dir'), 'atrium');
    expect(w, isA<Container>());
    expect((w as Container).key, const ValueKey('mm-art-missing-atrium'));
  });

  test('present derived PNG → an Image widget', () {
    final dir = Directory.systemTemp.createTempSync('mmart');
    File('${dir.path}/assets_derived/mindmaze/atrium.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0, 1, 2, 3]); // content need not decode; we assert the widget type
    final w = mindMazeArt(AssetConfig(dir.path), 'atrium');
    expect(w, isA<Image>());
    dir.deleteSync(recursive: true);
  });

  test('framesFor returns all frames of a multi-frame set, in order', () {
    expect(framesFor('jester'), ['jester1', 'jester2', 'jester3', 'jester4']);
    expect(framesFor('duke'), ['duke1', 'duke2', 'duke3']);
  });
  test('framesFor returns a single frame for single-frame sets', () {
    expect(framesFor('king'), ['king1']);
    expect(framesFor('parrot'), ['parrot']);
  });
  test('framesFor falls back to the id itself for unknown sets', () {
    expect(framesFor('nope'), ['nope']);
  });
}
