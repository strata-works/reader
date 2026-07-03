import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/corpus_provisioner.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment? env;
  try {
    final config = await resolveAppConfig(
      args: args,
      env: Platform.environment,
      isMobile: Platform.isAndroid || Platform.isIOS,
      provisionCorpus: provisionBundledCorpus,
    );
    env = await bootstrap(config);
  } catch (e, st) {
    debugPrint('Encarta startup failed: $e\n$st');
  }
  runApp(EncartaReaderApp(env: env));
}
