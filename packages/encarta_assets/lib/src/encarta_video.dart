// packages/encarta_assets/lib/src/encarta_video.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'encarta_assets_base.dart';
import 'media_kit_init.dart';

/// Plays a video asset (WMV originals supported on desktop via media_kit).
/// Player + VideoController are lazy-initialized after the file resolves; a
/// missing file shows a "media unavailable" poster and creates no Player.
class EncartaVideo extends StatefulWidget {
  const EncartaVideo({super.key, required this.item, required this.assets});

  final MediaItem item;
  final EncartaAssets assets;

  @override
  State<EncartaVideo> createState() => _EncartaVideoState();
}

class _EncartaVideoState extends State<EncartaVideo> {
  Player? _player;
  VideoController? _controller;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    final file = widget.assets.resolvePath(widget.item.assetPath);
    if (file == null) {
      _unavailable = true;
      return;
    }
    try {
      ensureMediaKit();
      final player = Player();
      _player = player;
      _controller = VideoController(player);
      player.open(Media(file.path), play: false);
    } catch (_) {
      _unavailable = true;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unavailable || controller == null) {
      return Container(
        key: const ValueKey('media-unavailable'),
        height: 180,
        alignment: Alignment.center,
        color: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Color(0xFFBDBDBD)),
            Text('${widget.item.title ?? 'Video'} — media unavailable',
                style: const TextStyle(color: Color(0xFFBDBDBD))),
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(controller: controller),
    );
  }
}
