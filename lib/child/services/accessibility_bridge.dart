// child/services/accessibility_bridge.dart — MethodChannel receiver for Kotlin service communication
// Handles calls from KovaAccessibilityService and forwards to detection orchestrator

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'detection_orchestrator.dart';

class AccessibilityBridge {
  static const platform = MethodChannel('com.kova.app/accessibility');

  /// Initialize the accessibility bridge
  /// Call this once at app startup
  static Future<void> initialize(String childId) async {
    try {
      await platform.invokeMethod<void>('initBridge', {'childId': childId});

      // Set up method call handler for alerts from native side
      platform.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      debugPrint('Error initializing accessibility bridge: $e');
    }
  }

  /// Handle method calls from native Kotlin service
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessage':
        return _handleMessage(call.arguments as Map<dynamic, dynamic>);

      case 'onConversation':
        return _handleConversation(call.arguments as Map<dynamic, dynamic>);

      case 'onUserReport':
        return _handleUserReport(call.arguments as Map<dynamic, dynamic>);

      case 'ping':
        return {'status': 'pong'};

      default:
        return {'error': 'Method not implemented: ${call.method}'};
    }
  }

  /// Handle single message detection
  /// Called by accessibility service on new message
  static Future<Map<String, dynamic>> _handleMessage(
    Map<dynamic, dynamic> data,
  ) async {
    try {
      final childId = data['childId'] as String?;
      final app = data['app'] as String?;
      final messageText = data['messageText'] as String? ?? '';
      final senderName = data['senderName'] as String?;
      final imagePaths = List<String>.from(data['imagePaths'] as List? ?? []);

      if (childId == null || app == null) {
        return {'alertCreated': false, 'error': 'Missing childId or app'};
      }

      // Run detection
      final alert = await DetectionOrchestrator.analyzeMessage(
        childId: childId,
        app: app,
        messageText: messageText,
        senderName: senderName,
        attachedImagePaths: imagePaths,
      );

      if (alert == null) {
        return {'alertCreated': false, 'reason': 'no_threat_detected'};
      }

      // Alert created - return to native for storage
      return {'alertCreated': true, 'alert': alert};
    } catch (e) {
      return {'alertCreated': false, 'error': e.toString()};
    }
  }

  /// Handle conversation thread analysis
  /// Called when user opens a conversation
  static Future<Map<String, dynamic>> _handleConversation(
    Map<dynamic, dynamic> data,
  ) async {
    try {
      final childId = data['childId'] as String?;
      final app = data['app'] as String?;
      final senderName = data['senderName'] as String?;
      final messages = List<Map<String, dynamic>>.from(
        (data['messages'] as List? ?? []).cast<Map<dynamic, dynamic>>().map(
          (m) => Map<String, dynamic>.from(m),
        ),
      );
      final metadata = data['metadata'] as String?;

      if (childId == null || app == null || senderName == null) {
        return {'alertCreated': false, 'error': 'Missing required fields'};
      }

      // Run detection
      final alert = await DetectionOrchestrator.analyzeConversation(
        childId: childId,
        app: app,
        senderName: senderName,
        messages: messages,
        metadata: metadata,
      );

      if (alert == null) {
        return {'alertCreated': false, 'reason': 'no_threat_detected'};
      }

      return {'alertCreated': true, 'alert': alert};
    } catch (e) {
      return {'alertCreated': false, 'error': e.toString()};
    }
  }

  /// Handle user-reported content
  /// Called when user manually reports harmful content
  static Future<Map<String, dynamic>> _handleUserReport(
    Map<dynamic, dynamic> data,
  ) async {
    try {
      final childId = data['childId'] as String?;
      final app = data['app'] as String?;
      final senderName = data['senderName'] as String?;
      final messages = List<Map<String, dynamic>>.from(
        (data['messages'] as List? ?? []).cast<Map<dynamic, dynamic>>().map(
          (m) => Map<String, dynamic>.from(m),
        ),
      );
      final reportText = data['reportText'] as String?;

      if (childId == null || app == null) {
        return {'alertCreated': false, 'error': 'Missing childId or app'};
      }

      // Run detection with user report flag
      final alert = await DetectionOrchestrator.analyzeUserReport(
        childId: childId,
        app: app,
        senderName: senderName ?? 'Unknown',
        messages: messages,
        userReportText: reportText,
      );

      return {'alertCreated': true, 'alert': alert};
    } catch (e) {
      return {'alertCreated': false, 'error': e.toString()};
    }
  }

  /// Send alert to native side for display/storage
  /// Call this after an alert is created
  static Future<void> sendAlert(Map<String, dynamic> alert) async {
    try {
      await platform.invokeMethod<void>('onAlertDetected', alert);
    } catch (e) {
      debugPrint('Error sending alert to native: $e');
    }
  }

  /// Block an app/conversation
  /// Called when parent sets block action
  static Future<void> blockApp(String childId, String app) async {
    try {
      await platform.invokeMethod<void>('blockApp', {
        'childId': childId,
        'app': app,
      });
    } catch (e) {
      debugPrint('Error blocking app: $e');
    }
  }

  /// Disable monitoring temporarily
  /// Called when child enters PIN or when monitoring should pause
  static Future<void> pauseMonitoring(String childId) async {
    try {
      await platform.invokeMethod<void>('pauseMonitoring', {
        'childId': childId,
      });
    } catch (e) {
      debugPrint('Error pausing monitoring: $e');
    }
  }

  /// Re-enable monitoring
  static Future<void> resumeMonitoring(String childId) async {
    try {
      await platform.invokeMethod<void>('resumeMonitoring', {
        'childId': childId,
      });
    } catch (e) {
      debugPrint('Error resuming monitoring: $e');
    }
  }

  /// Cleanup - call when child logs out
  static Future<void> tearDown() async {
    try {
      await platform.invokeMethod<void>('tearDownBridge');
    } catch (e) {
      debugPrint('Error tearing down bridge: $e');
    }
  }
}
