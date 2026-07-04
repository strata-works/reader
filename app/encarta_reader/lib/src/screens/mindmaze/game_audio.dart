import 'package:encarta_assets/encarta_assets.dart';
import 'package:path/path.dart' as p;

/// A one-shot game sound effect. Mapped to an extracted MINDMAZE.EIT asset id
/// by [sfxAssetId].
enum GameSfx { correct, wrong, door }

/// The extracted `.wav` asset id backing each SFX.
String sfxAssetId(GameSfx sfx) {
  switch (sfx) {
    case GameSfx.correct:
      return 'right';
    case GameSfx.wrong:
      return 'wrong';
    case GameSfx.door:
      return 'dooropen';
  }
}

/// Runtime path for a MindMaze audio asset copied by `copy_mindmaze_audio.dart`
/// into `<derivedDir>/mindmaze_audio/<id>.<ext>`.
String audioAssetPath(AssetConfig config, String id, String ext) =>
    p.join(config.derivedDir, 'mindmaze_audio', '$id.$ext');

/// Game-audio port: looping background + fire-and-forget SFX + mute. Implemented
/// for real by [MindMazeAudio] (media_kit) and stubbed by [SilentGameAudio].
abstract class GameAudio {
  void startBackground();
  void playSfx(GameSfx sfx);
  void setMuted(bool muted);
  bool get muted;
  void dispose();
}

/// A no-op [GameAudio] for tests and graceful fallback when playback can't init.
class SilentGameAudio implements GameAudio {
  const SilentGameAudio();
  @override
  void startBackground() {}
  @override
  void playSfx(GameSfx sfx) {}
  @override
  void setMuted(bool muted) {}
  @override
  bool get muted => false;
  @override
  void dispose() {}
}
