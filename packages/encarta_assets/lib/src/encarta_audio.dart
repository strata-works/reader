// packages/encarta_assets/lib/src/encarta_audio.dart
import 'package:encarta_data/encarta_data.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'encarta_assets_base.dart';
import 'media_kit_init.dart';

/// Plays an audio asset (WMA originals supported on desktop via media_kit).
/// The Player is lazy-initialized only after the file resolves; a missing file
/// shows a "media unavailable" poster and never creates a Player.
class EncartaAudio extends StatefulWidget {
  const EncartaAudio({super.key, required this.item, required this.assets});

  final MediaItem item;
  final EncartaAssets assets;

  @override
  State<EncartaAudio> createState() => _EncartaAudioState();
}

class _EncartaAudioState extends State<EncartaAudio> {
  Player? _player;
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
      // Fire the async open; errors are caught in _openMedia so they degrade
      // to the "media unavailable" poster (spec §10) instead of escaping.
      _openMedia(player, file.path);
    } catch (_) {
      _unavailable = true;
    }
  }

  /// Opens [path] on [player] and catches any async errors, degrading to the
  /// "media unavailable" poster by setting [_unavailable] via [setState].
  Future<void> _openMedia(Player player, String path) async {
    try {
      await player.open(Media(path), play: false);
    } catch (_) {
      if (mounted) {
        setState(() => _unavailable = true);
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable || _player == null) {
      return _Poster(label: widget.item.title ?? 'Audio');
    }
    final player = _player!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => player.play(),
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => player.pause(),
        ),
        Flexible(child: Text(widget.item.title ?? 'Audio')),
      ],
    );
  }
}

/// Shared "media unavailable" poster.
class _Poster extends StatelessWidget {
  const _Poster({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('media-unavailable'),
        height: 80,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off, color: Color(0xFF9E9E9E)),
            Text('$label — media unavailable',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}
