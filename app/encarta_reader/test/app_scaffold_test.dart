import 'package:encarta_reader/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EncartaReaderApp builds a MaterialApp', (tester) async {
    await tester.pumpWidget(const EncartaReaderApp(env: null));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
