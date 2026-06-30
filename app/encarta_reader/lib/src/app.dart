import 'package:flutter/material.dart';

/// Placeholder root app. Replaced by the router-wired version in Task 22.
class EncartaReaderApp extends StatelessWidget {
  const EncartaReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Encarta Reader'))),
    );
  }
}
