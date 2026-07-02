// Builds test/fixtures/encarta_fixture.sqlite from the real corpus.
// Run once, from the package root, with the real DB present:
//   dart run tool/build_fixture.dart
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const srcDb =
    '/Users/nexus/projects/experiments/strata/quarry/build/encarta.sqlite';
const outDb = 'test/fixtures/encarta_fixture.sqlite';

void main() {
  // fts5 lives only in an fts5-enabled libsqlite3 (NOT macOS system sqlite3).
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
    stderr.writeln('No fts5-capable libsqlite3 found (install: brew install sqlite).');
    exit(1);
  }
  if (!File(srcDb).existsSync()) {
    stderr.writeln('Real corpus not found at $srcDb');
    exit(1);
  }

  final out = File(outDb);
  if (out.existsSync()) out.deleteSync();
  out.parent.createSync(recursive: true);

  final dst = sqlite3.open(outDb);
  dst.execute("ATTACH DATABASE 'file:$srcDb?mode=ro' AS src");

  dst.execute('''
    CREATE TABLE article (refid INTEGER PRIMARY KEY, source TEXT, title TEXT, xml BLOB);
    CREATE TABLE asset (baggage_id TEXT PRIMARY KEY, hash TEXT, kind TEXT, ext TEXT, path TEXT, source TEXT);
    CREATE TABLE media (refid INTEGER PRIMARY KEY, "group" TEXT, title TEXT, credit TEXT, caption TEXT, source TEXT);
    CREATE TABLE media_file (media_refid INTEGER, role TEXT, baggage_id TEXT, ext TEXT, PRIMARY KEY(media_refid, role));
    CREATE TABLE article_media (article_refid INTEGER, media_refid INTEGER, PRIMARY KEY(article_refid, media_refid));
    CREATE TABLE xref (refid INTEGER, target_refid INTEGER, PRIMARY KEY(refid, target_refid));
    CREATE VIRTUAL TABLE article_fts USING fts5(body, content='', contentless_delete=1, tokenize='unicode61');
  ''');

  // Pick the slice: 10 titled articles per source tier ...
  final ids = <int>{};
  for (final tier in const ['CONTDLX.AKC', 'CONTSTD.AKC', 'CONTSTC.AKC', 'CONTKDC.AKC']) {
    for (final r in dst.select(
        'SELECT refid FROM src.article WHERE source = ? AND title IS NOT NULL '
        'ORDER BY refid LIMIT 10',
        [tier])) {
      ids.add(r['refid'] as int);
    }
  }
  // ... plus the 3 most media-rich articles (so mediaForArticle has real data).
  for (final r in dst.select(
      'SELECT a.refid AS refid FROM src.article_media am '
      'JOIN src.article a ON a.refid = am.article_refid '
      'WHERE a.title IS NOT NULL GROUP BY a.refid ORDER BY count(*) DESC LIMIT 3')) {
    ids.add(r['refid'] as int);
  }
  final inC = ids.join(',');

  dst.execute('INSERT INTO article SELECT * FROM src.article WHERE refid IN ($inC)');
  dst.execute('INSERT INTO article_media SELECT * FROM src.article_media WHERE article_refid IN ($inC)');
  dst.execute('INSERT INTO media SELECT * FROM src.media WHERE refid IN (SELECT media_refid FROM article_media)');
  dst.execute("INSERT OR IGNORE INTO media SELECT * FROM src.media WHERE \"group\" = 'home' ORDER BY refid LIMIT 10");
  dst.execute('INSERT INTO media_file SELECT * FROM src.media_file WHERE media_refid IN (SELECT refid FROM media)');
  dst.execute('INSERT INTO asset SELECT * FROM src.asset WHERE baggage_id IN (SELECT baggage_id FROM media_file)');
  // Keep only xrefs whose target is also in the slice, so outboundXrefs JOINs resolve.
  dst.execute('INSERT INTO xref SELECT * FROM src.xref WHERE refid IN ($inC) AND target_refid IN ($inC)');

  // Build the contentless FTS in Dart, with rowid == refid (the invariant).
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
  final n = dst.select('SELECT count(*) AS n FROM article').first['n'];
  dst.dispose();
  stdout.writeln('Wrote $outDb with $n articles.');
}
