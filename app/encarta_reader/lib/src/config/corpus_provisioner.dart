import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';

/// Bump when a new sample_corpus.zip ships so devices re-unpack it.
const String sampleVersion = '2026-07-03-2';

/// Bundled asset key for the packaged sample corpus.
const String _sampleAsset = 'assets/sample_corpus.zip';

/// Extract every file in [zipBytes] under [target], creating parent dirs.
void extractCorpusZip(Uint8List zipBytes, Directory target) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  for (final file in archive) {
    final outPath = '${target.path}/${file.name}';
    if (file.isFile) {
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

/// True iff [corpus] holds a `.sample_version` marker equal to [version].
bool corpusIsProvisioned(Directory corpus, String version) {
  final marker = File('${corpus.path}/.sample_version');
  return corpus.existsSync() &&
      marker.existsSync() &&
      marker.readAsStringSync().trim() == version;
}

/// Ensure the bundled sample corpus is unpacked into app-private storage and
/// return its directory. Idempotent: skips when the version marker matches.
/// On failure, leaves the corpus dir cleared so the next launch retries.
Future<String> provisionBundledCorpus() async {
  final support = await getApplicationSupportDirectory();
  final corpus = Directory('${support.path}/corpus');
  if (corpusIsProvisioned(corpus, sampleVersion)) return corpus.path;

  if (corpus.existsSync()) corpus.deleteSync(recursive: true);
  corpus.createSync(recursive: true);
  try {
    final data = await rootBundle.load(_sampleAsset);
    extractCorpusZip(data.buffer.asUint8List(), corpus);
    File('${corpus.path}/.sample_version').writeAsStringSync(sampleVersion);
  } catch (_) {
    if (corpus.existsSync()) corpus.deleteSync(recursive: true);
    rethrow;
  }
  return corpus.path;
}

/// Resolve the app's [AppConfig], provisioning the bundled sample corpus on
/// mobile when no CLI/env override is present. CLI `--data-dir=` / env
/// `ENCARTA_DATA_DIR` always win (dev override, even on a device).
Future<AppConfig> resolveAppConfig({
  required List<String> args,
  required Map<String, String> env,
  required bool isMobile,
  Future<String> Function()? provisionCorpus,
}) async {
  final base = AppConfig.resolve(args: args, env: env);
  final hasOverride = base.dataDir != AppConfig.defaultDataDir;
  if (isMobile && !hasOverride && provisionCorpus != null) {
    final dir = await provisionCorpus();
    return AppConfig.resolve(args: args, env: env, setting: dir);
  }
  return base;
}
