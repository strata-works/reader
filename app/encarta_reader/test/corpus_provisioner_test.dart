import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encarta_reader/src/config/corpus_provisioner.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zipOf(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, bytes) =>
      archive.addFile(ArchiveFile(name, bytes.length, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('extractCorpusZip writes files at their zip-relative paths', () {
    final tmp = Directory.systemTemp.createTempSync('corpus_extract_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final zip = _zipOf({
      'encarta.sqlite': [1, 2, 3],
      'assets/image/abc.png': [9, 8, 7],
    });

    extractCorpusZip(zip, tmp);

    expect(File('${tmp.path}/encarta.sqlite').readAsBytesSync(), [1, 2, 3]);
    expect(File('${tmp.path}/assets/image/abc.png').readAsBytesSync(), [9, 8, 7]);
  });

  test('corpusIsProvisioned tracks the version marker', () {
    final tmp = Directory.systemTemp.createTempSync('corpus_marker_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    expect(corpusIsProvisioned(tmp, sampleVersion), isFalse);

    File('${tmp.path}/.sample_version').writeAsStringSync(sampleVersion);
    expect(corpusIsProvisioned(tmp, sampleVersion), isTrue);
    expect(corpusIsProvisioned(tmp, 'other-version'), isFalse);
  });
}
