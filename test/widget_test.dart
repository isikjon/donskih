import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_app/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const DonskihApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
