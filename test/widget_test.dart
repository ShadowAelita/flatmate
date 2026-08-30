import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flatmate/register_page.dart';
import 'package:flatmate/wg_data.dart';

void main() {
  testWidgets('RegisterPage builds smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

    expect(find.text('Wer bist du?'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
  });

  testWidgets('Color picker shows all member colors',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

    expect(
      find.byType(CircleAvatar),
      findsNWidgets(WGData.memberColors.length),
    );
  });
}
