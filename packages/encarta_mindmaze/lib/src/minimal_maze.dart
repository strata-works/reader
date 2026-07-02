import 'maze.dart';

// AUTHORED / RECONSTRUCTED CONTENT (not original Encarta data): this small
// castle, its room→character assignments, and all banter lines are hand-authored
// to exercise and showcase the engine. Backdrop/sprite ids reference real
// extracted MINDMAZE.EIT art names. The full 9-wing castle is a later effort.

const _jester = Character(
  id: 'jester', spriteSetId: 'jester',
  greeting: "Welcome, seeker! Answer true and the castle opens to you.",
  approve: ['Ha! Sharp as a tack.', 'The doors swing wide for a clever mind.'],
  rebuff: ['Tsk — think again, wanderer.', 'The stones themselves wince at that.'],
);

const _king = Character(
  id: 'king', spriteSetId: 'king',
  greeting: 'Prove your learning before my throne-ward halls.',
  approve: ['Well reasoned. Proceed.', 'A worthy answer.'],
  rebuff: ['A king expects better.', 'No. Try once more.'],
);

const _sorceres = Character(
  id: 'sorceres', spriteSetId: 'sorceres',
  greeting: 'The gallery guards its secrets. Do you know them?',
  approve: ['The runes glow in your favor.', 'Correct — the way clears.'],
  rebuff: ['The mist thickens against you.', 'Not so. Look deeper.'],
);

const _lady = Character(
  id: 'lady', spriteSetId: 'lady',
  greeting: 'One question stands between you and the tower stair.',
  approve: ['Gracefully done.', 'You may pass.'],
  rebuff: ['I fear not.', 'Consider again.'],
);

const _duke = Character(
  id: 'duke', spriteSetId: 'duke',
  greeting: 'The final test, here at the throne. Answer, and the castle is yours.',
  approve: ['The crown is won!', 'You have bested the maze.'],
  rebuff: ['So close — but no.', 'The throne is not yet yours.'],
);

/// A 5-room authored castle for testing + Phase 4. Start = atrium, goal = throne.
/// Layout (branch at the atrium):
///   atrium(0) --right--> library(1) --right--> hall(1) --tower--> throne(1, GOAL)
///   atrium(0) --tower--> gallery(0) --north--> hall(1)
MazeGraph minimalMaze() => const MazeGraph(
      startRoomId: 'atrium',
      goalRoomId: 'throne',
      rooms: {
        'atrium': Room(
          id: 'atrium', area: 0, backdropId: 'atrium', character: _jester,
          doors: [
            Door(direction: Direction.right, targetRoomId: 'library'),
            Door(direction: Direction.tower, targetRoomId: 'gallery'),
          ],
        ),
        'library': Room(
          id: 'library', area: 1, backdropId: 'bookshlf', character: _king,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'atrium'),
            Door(direction: Direction.right, targetRoomId: 'hall'),
          ],
        ),
        'gallery': Room(
          id: 'gallery', area: 0, backdropId: 'plnwalls', character: _sorceres,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'atrium'),
            Door(direction: Direction.north, targetRoomId: 'hall'),
          ],
        ),
        'hall': Room(
          id: 'hall', area: 1, backdropId: 'rmofdoor', character: _lady,
          doors: [
            Door(direction: Direction.left, targetRoomId: 'library'),
            Door(direction: Direction.tower, targetRoomId: 'throne'),
          ],
        ),
        'throne': Room(
          id: 'throne', area: 1, backdropId: 'atrium', character: _duke,
          doors: [
            Door(direction: Direction.south, targetRoomId: 'hall'),
          ],
        ),
      },
    );
