import 'package:encarta_reader/src/app.dart';
import 'package:encarta_reader/src/widgets/top_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell shows the toolbar above the router outlet',
      (tester) async {
    // env=null exercises the shell chrome without a DB; pages guard on db!=null.
    await tester.pumpWidget(const EncartaReaderApp(env: null));
    await tester.pump();
    expect(find.byType(EncartaToolbar), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
