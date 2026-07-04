import 'dart:io';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:media_kit/media_kit.dart';

import 'game_audio.dart';

/// Real game audio over media_kit. One looping background player (the
/// fluidsynth-rendered BGLOOP1.wav music, falling back to a looping ambience
/// .wav if the rendered music is absent) plus a short-lived player per SFX.
/// Every media call is guarded so a playback failure degrades to silence rather
/// than crashing the game. mpv is initialized at app bootstrap
/// (`MediaKit.ensureInitialized()`), so no per-instance init here.
class MindMazeAudio implements GameAudio {
  MindMazeAudio(this.config);

  final AssetConfig config;
  Player? _bg;
  bool _muted = false;
  bool _disposed = false;

  @override
  bool get muted => _muted;

  @override
  void startBackground() {
    if (_disposed || _bg != null) return;
    try {
      final bg = Player();
      _bg = bg;
      bg.setPlaylistMode(PlaylistMode.loop);
      _openBackground(bg);
    } catch (_) {
      _bg = null;
    }
  }

  Future<void> _openBackground(Player bg) async {
    // mpv cannot synthesize MIDI, so the background is the pre-rendered
    // BGLOOP1.wav (fluidsynth-rendered from BGLOOP1.mid by the
    // copy_mindmaze_audio dev tool). Fall back to a looping ambience .wav if the
    // rendered music is absent, so there is always background audio.
    final music = File(audioAssetPath(config, 'BGLOOP1', 'wav'));
    final amb = File(audioAssetPath(config, 'amb1', 'wav'));
    try {
      if (music.existsSync()) {
        await bg.open(Media(music.path), play: !_muted);
        return;
      }
    } catch (_) {/* fall through to ambience */}
    try {
      if (amb.existsSync()) {
        await bg.open(Media(amb.path), play: !_muted);
      }
    } catch (_) {/* leave silent */}
  }

  @override
  void playSfx(GameSfx sfx) {
    if (_disposed || _muted) return;
    final file = File(audioAssetPath(config, sfxAssetId(sfx), 'wav'));
    if (!file.existsSync()) return;
    try {
      // A dedicated player per shot so overlapping SFX don't cut each other off;
      // dispose it once it finishes.
      final p = Player();
      p.stream.completed.listen((done) {
        if (done) p.dispose();
      });
      p.open(Media(file.path), play: true).catchError((_) {});
    } catch (_) {/* ignore */}
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    final bg = _bg;
    if (bg == null) return;
    try {
      if (muted) {
        bg.pause();
      } else {
        bg.play();
      }
    } catch (_) {/* ignore */}
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _bg?.dispose();
    } catch (_) {/* ignore */}
    _bg = null;
  }
}
