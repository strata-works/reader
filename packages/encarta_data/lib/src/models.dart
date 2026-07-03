import 'dart:typed_data';

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One article: identity, resolved title, source tier, and raw XML body bytes.
class Article {
  const Article({
    required this.refid,
    required this.title,
    required this.source,
    required this.xmlBytes,
  });

  final int refid;
  final String title;
  final String source;
  final Uint8List xmlBytes;

  @override
  bool operator ==(Object other) =>
      other is Article &&
      other.refid == refid &&
      other.title == title &&
      other.source == source &&
      _bytesEqual(other.xmlBytes, xmlBytes);

  @override
  int get hashCode => Object.hash(refid, title, source, xmlBytes.length);
}

/// A search result: target article id, its title, and the bm25 rank
/// (lower = more relevant; bm25 returns negative scores).
class SearchHit {
  const SearchHit({required this.refid, required this.title, required this.rank});

  final int refid;
  final String title;
  final double rank;

  @override
  bool operator ==(Object other) =>
      other is SearchHit &&
      other.refid == refid &&
      other.title == title &&
      other.rank == rank;

  @override
  int get hashCode => Object.hash(refid, title, rank);
}

/// One media slot for an article: its role + group, optional editorial text,
/// and the resolved asset (`assetPath` is RELATIVE to `<dataDir>/assets/`).
class MediaItem {
  const MediaItem({
    required this.mediaRefid,
    required this.role,
    required this.group,
    this.title,
    this.caption,
    this.credit,
    required this.assetPath,
    required this.ext,
    required this.kind,
  });

  final int mediaRefid;
  final String role;
  final String group;
  final String? title;
  final String? caption;
  final String? credit;
  final String assetPath;
  final String ext;
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is MediaItem &&
      other.mediaRefid == mediaRefid &&
      other.role == role &&
      other.group == group &&
      other.title == title &&
      other.caption == caption &&
      other.credit == credit &&
      other.assetPath == assetPath &&
      other.ext == ext &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(
      mediaRefid, role, group, title, caption, credit, assetPath, ext, kind);
}

/// An outbound cross-reference target: the linked article id + its title.
class XrefTarget {
  const XrefTarget({required this.targetRefid, required this.title});

  final int targetRefid;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is XrefTarget &&
      other.targetRefid == targetRefid &&
      other.title == title;

  @override
  int get hashCode => Object.hash(targetRefid, title);
}

/// A lightweight title pointer for browse/index lists: article id + title.
class TitleRef {
  const TitleRef({required this.refid, required this.title});

  final int refid;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is TitleRef && other.refid == refid && other.title == title;

  @override
  int get hashCode => Object.hash(refid, title);
}

/// One row of the `asset` table: the stored binary's identity and location.
/// `path` is RELATIVE to `<dataDir>/assets/`. Used by encarta_assets to
/// resolve `inlinebmp type=27` (whose `id` is an `asset.baggage_id`).
class AssetRow {
  const AssetRow({
    required this.baggageId,
    required this.hash,
    required this.kind,
    required this.ext,
    required this.path,
  });

  final String baggageId;
  final String hash;
  final String kind;
  final String ext;
  final String path;

  @override
  bool operator ==(Object other) =>
      other is AssetRow &&
      other.baggageId == baggageId &&
      other.hash == hash &&
      other.kind == kind &&
      other.ext == ext &&
      other.path == path;

  @override
  int get hashCode => Object.hash(baggageId, hash, kind, ext, path);
}

bool _answersEqual(List<MindMazeAnswer> a, List<MindMazeAnswer> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One MindMaze answer choice. `ordinal` 0 is the authored correct answer;
/// 1–3 are decoys. `articleRefid` joins article.refid ("learn more" target).
class MindMazeAnswer {
  const MindMazeAnswer({
    required this.ordinal,
    required this.text,
    required this.articleRefid,
    required this.isCorrect,
  });

  final int ordinal;
  final String text;
  final int articleRefid;
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      other is MindMazeAnswer &&
      other.ordinal == ordinal &&
      other.text == text &&
      other.articleRefid == articleRefid &&
      other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(ordinal, text, articleRefid, isCorrect);
}

/// One MindMaze question: a definition-style clue plus its four answers
/// (ordinal-ordered, index 0 correct). `area` is the castle wing 0–8, or null
/// when the question's topic matched no Area*.lst pool.
class MindMazeQuestion {
  const MindMazeQuestion({
    required this.id,
    required this.area,
    required this.clue,
    required this.answers,
  });

  final int id;
  final int? area;
  final String clue;
  final List<MindMazeAnswer> answers;

  /// The authored correct answer (ordinal 0 / is_correct = 1).
  MindMazeAnswer get correct => answers.firstWhere((a) => a.isCorrect);

  @override
  bool operator ==(Object other) =>
      other is MindMazeQuestion &&
      other.id == id &&
      other.area == area &&
      other.clue == clue &&
      _answersEqual(other.answers, answers);

  @override
  int get hashCode => Object.hash(id, area, clue, answers.length);
}

/// The decoded MindMaze castle: its [rooms], directed [doors], and the
/// [characters] that pose questions. Connectivity is the Phase 5a authored
/// spine; room/character content and banter are authentic (decoded from
/// ENCARTA.EXE). See `mindmazeCastle()`.
class MindMazeCastle {
  const MindMazeCastle({
    required this.rooms,
    required this.doors,
    required this.characters,
  });

  final List<MindMazeRoom> rooms;
  final List<MindMazeDoor> doors;
  final List<MindMazeCharacter> characters;
}

/// A castle room: its question-pool [area] (nullable), [backdropId] art,
/// resident [characterId], and whether it is the [isGoal] (throne) room.
class MindMazeRoom {
  const MindMazeRoom({
    required this.id,
    required this.area,
    required this.backdropId,
    required this.characterId,
    required this.isGoal,
  });

  final String id;
  final int? area;
  final String backdropId;
  final String characterId;
  final bool isGoal;
}

/// A one-way navigation edge from [roomId] to [targetRoomId] via [direction]
/// (one of left|right|tower|north|south).
class MindMazeDoor {
  const MindMazeDoor({
    required this.roomId,
    required this.direction,
    required this.targetRoomId,
  });

  final String roomId;
  final String direction;
  final String targetRoomId;
}

/// A castle character: its [spriteSet] art id, authentic [greeting], and all
/// recovered [banter] lines (parsed from banter_json).
class MindMazeCharacter {
  const MindMazeCharacter({
    required this.id,
    required this.spriteSet,
    required this.greeting,
    required this.banter,
  });

  final String id;
  final String spriteSet;
  final String greeting;
  final List<String> banter;
}
