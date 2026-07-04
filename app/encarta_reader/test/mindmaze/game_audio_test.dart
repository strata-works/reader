import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_reader/src/screens/mindmaze/game_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sfxAssetId maps each SFX to its extracted asset id', () {
    expect(sfxAssetId(GameSfx.correct), 'right');
    expect(sfxAssetId(GameSfx.wrong), 'wrong');
    expect(sfxAssetId(GameSfx.door), 'dooropen');
  });

  test('audioAssetPath resolves under derivedDir/mindmaze_audio', () {
    const config = AssetConfig('/data');
    expect(audioAssetPath(config, 'right', 'wav'),
        '/data/assets_derived/mindmaze_audio/right.wav');
    expect(audioAssetPath(config, 'BGLOOP1', 'mid'),
        '/data/assets_derived/mindmaze_audio/BGLOOP1.mid');
  });

  test('SilentGameAudio is a const no-op that never throws', () {
    const audio = SilentGameAudio();
    expect(audio.muted, isFalse);
    // None of these should throw or change observable state.
    audio.startBackground();
    audio.stopBackground();
    audio.playSfx(GameSfx.correct);
    audio.setMuted(true);
    audio.dispose();
    expect(audio.muted, isFalse);
  });

  group('applyMindMazeBackground', () {
    test("starts background on '/mindmaze'", () {
      final audio = _RecordingAudio();
      applyMindMazeBackground('/mindmaze', audio);
      expect(audio.started, isTrue);
      expect(audio.stopped, isFalse);
    });

    test('stops background off the MindMaze route', () {
      for (final location in ['/article/5', '/']) {
        final audio = _RecordingAudio();
        applyMindMazeBackground(location, audio);
        expect(audio.started, isFalse);
        expect(audio.stopped, isTrue);
      }
    });
  });
}

class _RecordingAudio implements GameAudio {
  bool started = false;
  bool stopped = false;
  bool _muted = false;
  @override
  void startBackground() => started = true;
  @override
  void stopBackground() => stopped = true;
  @override
  void playSfx(GameSfx sfx) {}
  @override
  void setMuted(bool muted) => _muted = muted;
  @override
  bool get muted => _muted;
  @override
  void dispose() {}
}
