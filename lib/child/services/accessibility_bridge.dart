// child/services/accessibility_bridge.dart — Legacy bridge retained for compatibility
// The real communication now flows through MonitoringBridge (3 channels).
// This file provides the static analysis methods used by other components.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'detection_orchestrator.dart';

class AccessibilityBridge {

  /// Initialize the accessibility bridge
  /// In the new architecture, MonitoringBridge handles data flow.
  /// This just ensures the native side knows the child ID.
  static Future<void> initialize(String childId) async {
    try {
      // Store child ID in shared prefs via setup channel
      if (kDebugMode) {
        debugPrint('📡 AccessibilityBridge: childId=$childId (delegating to MonitoringBridge)');
      }
    } catch (e) {
      debugPrint('Error initializing accessibility bridge: $e');
    }
  }

  /// Send alert to native side for display/storage
  static Future<void> sendAlert(Map<String, dynamic> alert) async {
    // Alerts are now handled by DetectionOrchestrator directly
    if (kDebugMode) {
      debugPrint('📢 Alert: ${alert['severity']} in ${alert['app']}');
    }
  }

  /// Block an app/conversation
  static Future<void> blockApp(String childId, String app) async {
    try {
      const blocker = MethodChannel('com.kova.child/blocker');
      await blocker.invokeMethod<void>('blockApp', {
        'childId': childId,
        'pkg': app,
      });
    } catch (e) {
      debugPrint('Error blocking app: $e');
    }
  }

  /// Disable monitoring temporarily
  static Future<void> pauseMonitoring(String childId) async {
    // DetectionOrchestrator.instance.stop() handles this now
    DetectionOrchestrator.instance.stop();
  }

  /// Re-enable monitoring
  static Future<void> resumeMonitoring(String childId) async {
    // DetectionOrchestrator.instance.start() handles this now
    await DetectionOrchestrator.instance.start();
  }

  /// Cleanup
  static Future<void> tearDown() async {
    DetectionOrchestrator.instance.stop();
  }
}
