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

// One representative transcoded frame per character sprite set (Phase 4 uses a
// single frame; multi-frame animation is Phase 6).
const _spriteFrame = <String, String>{
  'jester': 'jester1',
  'king': 'king1',
  'sorceres': 'sorceres',
  'lady': 'lady1',
  'duke': 'duke1',
};

/// The transcoded frame id for a character [spriteSetId]; falls back to the id
/// itself if the set is unknown.
String spriteFrameFor(String spriteSetId) => _spriteFrame[spriteSetId] ?? spriteSetId;
