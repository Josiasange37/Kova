import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kova/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('End-to-end configuration flow', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Wait for the Future.delayed sequence in Splash Screen
    final startButton = find.text('Start configuration');
    
    int retries = 0;
    while (startButton.evaluate().isEmpty && retries < 50) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      retries++;
    }
    
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Parent Profile Screen
    expect(find.text('Your profile'), findsWidgets);

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4));

    // Enter name
    await tester.enterText(textFields.at(0), 'John Doe');
    
    // Enter phone
    await tester.enterText(textFields.at(1), '671234567');
    
    // Enter PIN
    await tester.enterText(textFields.at(2), '1234');
    
    // Enter Confirm PIN
    await tester.enterText(textFields.at(3), '1234');
    
    // Hide keyboard if necessary
    await tester.pumpAndSettle();

    // Tap Continue
    final continueButton = find.text('Continue');
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Child Profile Screen
    expect(find.text("Your child's profile"), findsWidgets);
    
    final childTextField = find.byType(TextField);
    expect(childTextField, findsOneWidget);

    // Enter child name
    await tester.enterText(childTextField, 'Alice');
    await tester.pumpAndSettle();

    // Tap Continue on child screen
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Next screen (WhatsApp connect)
    // We just verify it doesn't crash and moves to the next screen
  });
}
