import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:flutter/material.dart';

/// Renders a MindMaze art asset by [id] from the transcoded derived PNG
/// (`<config.derivedDir>/mindmaze/<id>.png`). Shows a labeled placeholder when
/// the PNG is absent or fails to decode — never blocks play. Does NOT use the
/// reader's DibShim/EncartaImage (MindMaze .dib are already-BM and load as
/// derived PNGs here).
Widget mindMazeArt(AssetConfig config, String id, {BoxFit fit = BoxFit.contain}) {
  final file = File('${config.derivedDir}/mindmaze/$id.png');
  if (!file.existsSync()) return _placeholder(id);
  return Image.file(file, fit: fit, errorBuilder: (_, __, ___) => _placeholder(id));
}

Widget _placeholder(String id) => Container(
      key: ValueKey('mm-art-missing-$id'),
      color: const Color(0xFF23202B),
      alignment: Alignment.center,
      child: Text(
        id,
        style: const TextStyle(color: Color(0xFF8A8398), fontSize: 10),
      ),
    );

// Ordered transcoded frames per character sprite set. Multi-frame sets animate
// (Phase 6); single-frame sets render statically. Frame ids match the extracted
// .dib names transcoded by tool/transcode_mindmaze_art.dart.
const _spriteFrames = <String, List<String>>{
  'jester': ['jester1', 'jester2', 'jester3', 'jester4'],
  'duke': ['duke1', 'duke2', 'duke3'],
  'suitarm': ['suitarm1', 'suitarm2'], // guard
  'secnldy': ['secnldy1', 'secnldy2'], // lady
  'servant': ['servant1', 'servant2'],
  'king': ['king1'],
  'sorceres': ['sorceres'],
  'alchem': ['alchem'],
  'asiantra': ['asiantra'], // merchant
  'parrot': ['parrot'],
  'maninst': ['maninst'], // prisoner
};

/// The ordered transcoded frame ids for a character [spriteSetId]; a single
/// element for static sets, or `[spriteSetId]` if the set is unknown.
List<String> framesFor(String spriteSetId) =>
    _spriteFrames[spriteSetId] ?? [spriteSetId];
