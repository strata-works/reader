import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/corpus_provisioner.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await resolveAppConfig(
    args: args,
    env: Platform.environment,
    isMobile: Platform.isAndroid || Platform.isIOS,
    provisionCorpus: provisionBundledCorpus,
  );
  final env = await bootstrap(config);
  runApp(EncartaReaderApp(env: env));
}
