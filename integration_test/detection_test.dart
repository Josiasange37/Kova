import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kova/main.dart' as app;
import 'package:kova/child/services/monitoring_bridge.dart';
import 'package:kova/child/services/text_analyzer.dart';
import 'package:kova/core/app_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── Fast unit-style checks (no device needed) ────────────────────────────

  group('TextAnalyzer keyword detection', () {
    test('"fuck you" scores as violence high', () {
      final result = TextAnalyzer.analyze('fuck you');
      expect(result['violence'], greaterThan(0.5),
          reason: '"fuck you" should trigger violence score > 0.5');
      expect(result['unsafe'], greaterThan(0.5),
          reason: 'Overall unsafe score should be > 0.5');
    });

    test('"commit suicide" scores as critical violence', () {
      final result = TextAnalyzer.analyze('commit suicide');
      expect(result['violence'], greaterThanOrEqualTo(0.85),
          reason: '"commit suicide" should trigger violence score >= 0.85');
    });

    test('"kill myself" scores as critical self-harm', () {
      final result = TextAnalyzer.analyze('i want to kill myself');
      expect(result['violence'], equals(1.0),
          reason: '"kill myself" should be max severity');
    });

    test('"send nudes" scores as sexual', () {
      final result = TextAnalyzer.analyze('send nudes');
      expect(result['sexual'], greaterThanOrEqualTo(0.9));
    });

    test('"our secret" scores as grooming', () {
      final result = TextAnalyzer.analyze("this is our secret, don't tell");
      expect(result['grooming'], greaterThan(0.5));
    });

    test('safe message returns low risk', () {
      final result = TextAnalyzer.analyze('how was school today?');
      expect(result['unsafe'], lessThan(0.2));
    });
  });

  // ── Full app integration test ────────────────────────────────────────────

  testWidgets('Simulate grooming detection and blocking overlay',
      (WidgetTester tester) async {
    // 1. Force the app mode to Child to trigger DetectionOrchestrator
    await AppModeManager.setChildMode('test_child_123');

    // Start the application
    app.main();
    await tester.pumpAndSettle();

    // 2. Wait until the DetectionOrchestrator is active and callbacks are bound
    int retries = 0;
    while (MonitoringBridge.onContent == null && retries < 10) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      retries++;
    }

    expect(MonitoringBridge.onContent, isNotNull,
        reason: 'MonitoringBridge was not initialized');

    // 3a. Inject a grooming message
    MonitoringBridge.onContent?.call(
      'com.whatsapp',
      "don't tell your parents about us", // grooming trigger
      'notification',
      'incoming',
      'convo_grooming',
      'Predator',
    );

    // 3b. Inject a self-harm message (previously undetected)
    MonitoringBridge.onContent?.call(
      'com.whatsapp',
      'commit suicide you loser', // self-harm + insult trigger
      'notification',
      'incoming',
      'convo_selfharm',
      'Bully',
    );

    // 4. Wait for the app to process and update UI
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 5. Verify the block overlay is shown
    final blockTextFinder = find.textContaining('blocked', skipOffstage: false);
    expect(blockTextFinder, findsWidgets,
        reason: 'Block screen was not displayed after harmful message');
  });
}

