import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/main.dart';

void main() {
  testWidgets('App renders with not configured mode', (WidgetTester tester) async {
    await tester.pumpWidget(const KovaApp(initialMode: AppMode.notConfigured));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
