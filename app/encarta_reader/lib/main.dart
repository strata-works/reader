import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/bootstrap.dart';
import 'src/config/app_config.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(args: args, env: Platform.environment);
  final env = await bootstrap(config);
  runApp(EncartaReaderApp(env: env));
}
