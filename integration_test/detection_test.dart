import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kova/main.dart' as app;
import 'package:kova/child/services/monitoring_bridge.dart';
import 'package:kova/core/app_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Simulate grooming detection and blocking overlay', (WidgetTester tester) async {
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

    expect(MonitoringBridge.onContent, isNotNull, reason: "MonitoringBridge was not initialized");

    // 3. Inject a simulated incoming grooming message directly via the bridge
    // This simulates the Android service passing a notification payload
    MonitoringBridge.onContent?.call(
      'com.whatsapp',
      'send me naked pictures', // keyword trigger for high severity
      'notification',
      'incoming',
      'convo_1',
      'Predator'
    );

    // 4. Wait for the app to process it through TfLiteAnalyzerService and SeverityEngine
    // Since this is async and pushes to the Navigation stack, we need pumpAndSettle
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 5. Verify the block overlay is shown
    // We can search for typical overlay texts, for instance "Blocked" or "This app has been blocked"
    final blockTextFinder = find.textContaining('blocked', skipOffstage: false);
    
    // Alternatively, look for typical UI components on the block screen, 
    // such as a "Return to Home" or "Close" button.
    expect(blockTextFinder, findsWidgets, reason: "Block screen was not displayed after grooming message");
  });
}
