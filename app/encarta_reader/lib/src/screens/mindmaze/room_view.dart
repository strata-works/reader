import 'dart:async';

import 'package:encarta_assets/encarta_assets.dart';
import 'package:encarta_mindmaze/encarta_mindmaze.dart';
import 'package:flutter/material.dart';

import 'end_screen.dart';
import 'game_audio.dart';
import 'mindmaze_art.dart';

/// Renders and drives a MindMaze [GameSession] over [maze]. Owns the session
/// (built via [newGame], rebuilt on restart); every interaction mutates the
/// session then setState, and the whole view re-derives from the new snapshot.
class RoomView extends StatefulWidget {
  const RoomView({
    super.key,
    required this.newGame,
    required this.maze,
    required this.config,
    this.audio = const SilentGameAudio(),
  });

  final GameSession Function() newGame;
  final MazeGraph maze;
  final AssetConfig config;
  final GameAudio audio;

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  late GameSession _session;
  bool _startFailed = false;
  bool _muted = false;
  Timer? _spriteTimer;
  int _frame = 0;
  String? _banterLine;
  int _banterIdx = 0;
  String _banterRoom = '';

  @override
  void initState() {
    super.initState();
    _start();
    if (!_startFailed) widget.audio.startBackground();
    _spriteTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _spriteTimer?.cancel();
    super.dispose();
  }

  // GameSession's constructor throws ArgumentError if an area's pool has no
  // posable question (exactly one correct choice) — e.g. a maze/pool area
  // mismatch. Guard construction so a bad pool degrades gracefully instead of
  // throwing inside initState/setState (never a red screen).
  void _start() {
    try {
      _session = widget.newGame();
      _startFailed = false;
    } catch (_) {
      _startFailed = true;
    }
  }

  void _answer(int i) {
    final outcome = _session.answer(i);
    if (outcome == AnswerOutcome.correct || outcome == AnswerOutcome.won) {
      widget.audio.playSfx(GameSfx.correct);
    } else if (outcome == AnswerOutcome.wrong || outcome == AnswerOutcome.lost) {
      widget.audio.playSfx(GameSfx.wrong);
    }
    setState(() {});
  }

  void _move(Direction d) {
    widget.audio.playSfx(GameSfx.door);
    setState(() => _session.move(d));
  }

  void _restart() => setState(_start);

  void _tapCharacter(Room room) {
    final banter = room.character.banter;
    if (banter.isEmpty) return;
    setState(() {
      if (_banterRoom != room.id) {
        _banterRoom = room.id;
        _banterIdx = 0;
      } else {
        _banterIdx = (_banterIdx + 1) % banter.length;
      }
      _banterLine = banter[_banterIdx];
    });
  }

  String _directionLabel(Direction d) {
    switch (d) {
      case Direction.left:
        return '← Left';
      case Direction.right:
        return 'Right →';
      case Direction.tower:
        return '↑ Tower';
      case Direction.north:
        return '↑ North';
      case Direction.south:
        return '↓ South';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startFailed) {
      return const Scaffold(
        body: Center(
          child: Text(
            'MindMaze could not start.',
            key: ValueKey('mm-start-failed'),
          ),
        ),
      );
    }
    final snap = _session.snapshot;
    final room = widget.maze.room(snap.currentRoomId);

    return Scaffold(
      backgroundColor: const Color(0xFF141018),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _hud(snap, room),
                Expanded(child: _scene(room)),
                _dialogPanel(snap, room),
              ],
            ),
            // The won end-screen and the lost overlay both key their restart
            // button 'mm-restart'. That is safe only because these two branches
            // are mutually exclusive (status is never both) — never render both
            // at once or the shared key collides.
            if (snap.status == GameStatus.won)
              MindMazeEndScreen(
                config: widget.config,
                score: snap.score,
                onPlayAgain: _restart,
              ),
            if (snap.status == GameStatus.lost)
              _overlay(
                key: const ValueKey('mm-lost'),
                title: 'Out of lives',
                subtitle: 'Score: ${snap.score}',
                buttonLabel: 'Try again',
              ),
          ],
        ),
      ),
    );
  }

  Widget _hud(GameSnapshot snap, Room room) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              key: const ValueKey('mm-lives'),
              children: [
                IconButton(
                  key: const ValueKey('mm-mute'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white54),
                  onPressed: () => setState(() {
                    _muted = !_muted;
                    widget.audio.setMuted(_muted);
                  }),
                ),
                for (var i = 0; i < snap.lives; i++)
                  const Icon(Icons.favorite, color: Color(0xFFE0557A), size: 18),
                const SizedBox(width: 8),
                Text('${snap.lives}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Flexible(
              child: Text('Score ${snap.score}',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(color: Colors.white)),
            ),
            Flexible(
              child: Text(room.character.id,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );

  Widget _scene(Room room) {
    final frames = framesFor(room.character.spriteSetId);
    final frameId = frames[_frame % frames.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        mindMazeArt(widget.config, room.backdropId, fit: BoxFit.cover),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.8,
            child: GestureDetector(
              key: const ValueKey('mm-character-tap'),
              onTap: () => _tapCharacter(room),
              child: mindMazeArt(widget.config, frameId, fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogPanel(GameSnapshot snap, Room room) {
    final children = <Widget>[];
    if (snap.lastCharacterLine != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(snap.lastCharacterLine!,
            style: const TextStyle(
                color: Colors.white, fontStyle: FontStyle.italic)),
      ));
    }
    if (_banterLine != null && _banterRoom == snap.currentRoomId) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(_banterLine!,
            key: const ValueKey('mm-banter'),
            style: const TextStyle(
                color: Colors.white70, fontStyle: FontStyle.italic)),
      ));
    }
    // Only show answer/door buttons while actually playing — once the game
    // is won or lost, the overlay covers this panel, and leaving these live
    // would let a tap reach dead buttons behind it.
    if (snap.status == GameStatus.playing) {
      final q = snap.currentQuestion;
      if (q != null) {
        children.add(Text(q.clue, style: const TextStyle(color: Colors.white)));
        children.add(const SizedBox(height: 8));
        for (var i = 0; i < q.choices.length; i++) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: FilledButton(
              key: ValueKey('mm-answer-$i'),
              onPressed: () => _answer(i),
              child: Text(q.choices[i].text),
            ),
          ));
        }
      } else if (snap.currentRoomCleared) {
        for (final door in room.doors) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: OutlinedButton(
              key: ValueKey('mm-door-${door.direction.name}'),
              onPressed: () => _move(door.direction),
              child: Text(_directionLabel(door.direction)),
            ),
          ));
        }
      }
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF201A2A),
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _overlay({
    required Key key,
    required String title,
    required String subtitle,
    required String buttonLabel,
  }) =>
      Positioned.fill(
        key: key,
        child: Container(
          color: const Color(0xCC000000),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('mm-restart'),
                onPressed: _restart,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      );
}
