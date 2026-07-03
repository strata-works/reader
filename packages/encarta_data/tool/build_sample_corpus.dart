// Builds a small standalone sample corpus (DB subset + copied asset files) and
// zips it to app/encarta_reader/assets/sample_corpus.zip for bundling on mobile.
// Run from the encarta_data package root with the full corpus present:
//   dart run tool/build_sample_corpus.dart
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const srcRoot = '/Users/nexus/projects/experiments/strata/quarry/build';
const srcDb = '$srcRoot/encarta.sqlite';
const outRoot = 'build/sample_corpus'; // scratch build dir (git-ignored)
const outDb = '$outRoot/encarta.sqlite';
const outZip = '../../app/encarta_reader/assets/sample_corpus.zip';
const targetArticles = 260;

void main() {
  // 1. Load an FTS5-capable libsqlite3 (same probe as build_fixture.dart).
  var loaded = false;
  for (final p in const [
    '/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib',
    '/usr/local/opt/sqlite/lib/libsqlite3.dylib',
  ]) {
    if (File(p).existsSync()) {
      open.overrideForAll(() => DynamicLibrary.open(p));
      loaded = true;
      break;
    }
  }
  if (!loaded) {
    stderr.writeln('No fts5-capable libsqlite3 found (brew install sqlite).');
    exit(1);
  }
  if (!File(srcDb).existsSync()) {
    stderr.writeln('Real corpus not found at $srcDb');
    exit(1);
  }

  // 2. Fresh output tree.
  final outDir = Directory(outRoot);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  final dst = sqlite3.open(outDb);
  dst.execute("ATTACH DATABASE 'file:$srcDb?mode=ro' AS src");

  // 3. Schema (identical to the real DB's read subset).
  dst.execute('''
    CREATE TABLE article (refid INTEGER PRIMARY KEY, source TEXT, title TEXT, xml BLOB);
    CREATE TABLE asset (baggage_id TEXT PRIMARY KEY, hash TEXT, kind TEXT, ext TEXT, path TEXT, source TEXT);
    CREATE TABLE media (refid INTEGER PRIMARY KEY, "group" TEXT, title TEXT, credit TEXT, caption TEXT, source TEXT);
    CREATE TABLE media_file (media_refid INTEGER, role TEXT, baggage_id TEXT, ext TEXT, PRIMARY KEY(media_refid, role));
    CREATE TABLE article_media (article_refid INTEGER, media_refid INTEGER, PRIMARY KEY(article_refid, media_refid));
    CREATE TABLE xref (refid INTEGER, target_refid INTEGER, PRIMARY KEY(refid, target_refid));
    CREATE VIRTUAL TABLE article_fts USING fts5(body, content='', contentless_delete=1, tokenize='unicode61');
    CREATE TABLE mm_question (id INTEGER PRIMARY KEY, area INTEGER, clue TEXT);
    CREATE TABLE mm_answer (id INTEGER PRIMARY KEY, question_id INTEGER, ordinal INTEGER, text TEXT, article_refid INTEGER, is_correct INTEGER, flag INTEGER);
  ''');

  // 4. Select ~targetArticles genuinely illustrated articles that show REAL,
  //    DISTINCT pictures. The naive "most decodable images" query fails here:
  //    the article->image graph funnels thousands of articles onto a tiny set
  //    of SHARED photos (200 top-in-band articles reference 1089 image slots
  //    but only ~42 distinct files). So instead we rank articles by how many
  //    RARE images they carry — decodable jpg/gif/png/bmp assets referenced by
  //    at most 3 articles (i.e. this article's own pictures, not shared UI
  //    chrome) — requiring at least 3 such images, most-rare first. This yields
  //    a sample rich in unique, on-disk photos.
  final ids = <int>{};
  for (final r in dst.select(
      "WITH img AS ( "
      "  SELECT s.baggage_id AS bid, am.article_refid AS aref "
      "  FROM src.asset s "
      "  JOIN src.media_file mf ON mf.baggage_id = s.baggage_id "
      "  JOIN src.article_media am ON am.media_refid = mf.media_refid "
      "  WHERE s.kind = 'image' "
      "    AND lower(s.ext) IN ('.jpg','.jpeg','.gif','.png','.bmp') "
      "), "
      "pop AS (SELECT bid, count(DISTINCT aref) AS narts FROM img GROUP BY bid) "
      "SELECT i.aref AS refid, "
      "       sum(CASE WHEN p.narts <= 3 THEN 1 ELSE 0 END) AS nrare "
      "FROM img i "
      "JOIN pop p ON p.bid = i.bid "
      "JOIN src.article a ON a.refid = i.aref "
      "WHERE a.title IS NOT NULL "
      "GROUP BY i.aref HAVING nrare >= 3 "
      "ORDER BY nrare DESC LIMIT ?",
      [targetArticles])) {
    ids.add(r['refid'] as int);
  }
  // Union in a SMALL audio demo: ~8 titled articles carrying 1–3 audio clips
  // each (a handful of .wma, not hundreds), so audio playback can be demoed.
  for (final r in dst.select(
      "SELECT a.refid AS refid FROM src.article a "
      "JOIN src.article_media am ON am.article_refid = a.refid "
      "JOIN src.media_file mf ON mf.media_refid = am.media_refid "
      "JOIN src.asset s ON s.baggage_id = mf.baggage_id AND s.kind = 'audio' "
      "WHERE a.title IS NOT NULL "
      "GROUP BY a.refid HAVING count(*) BETWEEN 1 AND 3 "
      "ORDER BY count(*) ASC LIMIT 8")) {
    ids.add(r['refid'] as int);
  }
  if (ids.isEmpty) {
    stderr.writeln('No image-bearing titled articles found.');
    exit(1);
  }
  final inC = ids.join(',');

  // 5. Copy DB rows (mirror build_fixture.dart); xref pruned to in-slice edges.
  dst.execute('INSERT INTO article SELECT * FROM src.article WHERE refid IN ($inC)');
  dst.execute('INSERT INTO article_media SELECT * FROM src.article_media WHERE article_refid IN ($inC)');
  dst.execute('INSERT INTO media SELECT * FROM src.media WHERE refid IN (SELECT media_refid FROM article_media)');
  dst.execute('INSERT INTO media_file SELECT * FROM src.media_file WHERE media_refid IN (SELECT refid FROM media)');
  dst.execute('INSERT INTO asset SELECT * FROM src.asset WHERE baggage_id IN (SELECT baggage_id FROM media_file)');
  dst.execute('INSERT INTO xref SELECT * FROM src.xref WHERE refid IN ($inC) AND target_refid IN ($inC)');

  // MindMaze: minimalMaze uses areas 0 and 1. Copy a generous per-area slice
  // (with all answers) so every maze room has a rich, posable question pool.
  // Without this the mobile sample has no questions and MindMaze can't start.
  final qids = <int>{};
  for (final area in const [0, 1]) {
    for (final r in dst.select(
        'SELECT id FROM src.mm_question WHERE area = ? ORDER BY id LIMIT 80',
        [area])) {
      qids.add(r['id'] as int);
    }
  }
  final qIn = qids.join(',');
  dst.execute('INSERT INTO mm_question SELECT * FROM src.mm_question WHERE id IN ($qIn)');
  dst.execute('INSERT INTO mm_answer SELECT * FROM src.mm_answer WHERE question_id IN ($qIn)');

  // 6. Rebuild contentless FTS (rowid == refid invariant).
  final tagRe = RegExp(r'<[^>]*>');
  final fts = dst.prepare('INSERT INTO article_fts(rowid, body) VALUES(?, ?)');
  for (final r in dst.select('SELECT refid, xml FROM article')) {
    final refid = r['refid'] as int;
    final raw = r['xml'];
    final text = (raw is List<int>
            ? utf8.decode(raw, allowMalformed: true)
            : '${raw ?? ''}')
        .replaceAll(tagRe, ' ');
    fts.execute([refid, text]);
  }
  fts.dispose();
  dst.execute('DETACH DATABASE src');

  // 7. Copy referenced asset files. Prefer the derived (transcoded) file when
  //    present (smaller/decodable), matching the resolver's precedence; else the
  //    original. Same relative path either way. Missing files are skipped (data
  //    gaps degrade to placeholders at runtime).
  var copied = 0, skipped = 0, bytes = 0;
  for (final r in dst.select('SELECT path, ext FROM asset')) {
    final rel = r['path'] as String?;
    if (rel == null || rel.isEmpty) continue;
    // Skip undecodable Encarta thumbnail formats — they render as placeholders
    // whether shipped or not, so shipping them is pure budget waste.
    final rawExt = (r['ext'] as String? ?? '').toLowerCase();
    if (rawExt == '.jtn' || rawExt == '.gtn') {
      skipped++;
      continue;
    }
    final derived = File('$srcRoot/assets_derived/$rel');
    final original = File('$srcRoot/assets/$rel');
    File? src;
    String subdir;
    if (derived.existsSync()) {
      src = derived;
      subdir = 'assets_derived';
    } else if (original.existsSync()) {
      src = original;
      subdir = 'assets';
    } else {
      skipped++;
      continue;
    }
    final out = File('$outRoot/$subdir/$rel');
    out.parent.createSync(recursive: true);
    src.copySync(out.path);
    copied++;
    bytes += src.lengthSync();
  }

  // 8. Self-check the output (integration guard from the spec).
  final artN = dst.select('SELECT count(*) AS n FROM article').first['n'] as int;
  final ftsN = dst
      .select('SELECT count(*) AS n FROM article a '
          'JOIN article_fts f ON f.rowid = a.refid')
      .first['n'] as int;
  // Visual-richness check: how many copied assets are decodable images.
  final imgN = dst.select("SELECT count(*) AS n FROM asset "
      "WHERE kind='image' AND lower(ext) IN ('.jpg','.jpeg','.gif','.png','.bmp')")
      .first['n'] as int;
  final mmqN = dst.select('SELECT count(*) AS n FROM mm_question').first['n'] as int;
  final mmqArea0 = dst.select('SELECT count(*) AS n FROM mm_question WHERE area=0').first['n'] as int;
  final mmqArea1 = dst.select('SELECT count(*) AS n FROM mm_question WHERE area=1').first['n'] as int;
  stdout.writeln('MindMaze questions: $mmqN (area0=$mmqArea0, area1=$mmqArea1)');
  dst.dispose();
  if (ftsN != artN) {
    stderr.writeln('FTS invariant broken: $ftsN joined != $artN articles');
    exit(1);
  }
  stdout.writeln('Decodable images in sample: $imgN');

  // 9. Zip the output tree (its ROOT becomes the corpus dir on device).
  final zipFile = File(outZip);
  zipFile.parent.createSync(recursive: true);
  if (zipFile.existsSync()) zipFile.deleteSync();
  final enc = ZipFileEncoder();
  enc.create(zipFile.path);
  enc.addDirectory(outDir, includeDirName: false);
  enc.close();

  final zipMb = zipFile.lengthSync() / (1024 * 1024);
  stdout.writeln('Sample: $artN articles, $copied assets copied '
      '(${(bytes / 1e6).toStringAsFixed(1)} MB raw), $skipped missing.');
  stdout.writeln('Wrote ${zipFile.path} (${zipMb.toStringAsFixed(1)} MB).');
  if (zipMb > 30) {
    stderr.writeln('WARNING: zip exceeds 30 MB budget — lower targetArticles.');
  }
}
