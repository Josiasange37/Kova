// child/services/accessibility_service.dart — Accessibility permission helper
// Wrapper around accessibility_bridge for permission checking

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const platform = MethodChannel('com.kova.app/accessibility');

  /// Check if accessibility permission is granted
  static Future<bool> isAccessibilityPermissionGranted() async {
    try {
      final result = await platform.invokeMethod<bool>(
        'isAccessibilityEnabled',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking accessibility permission: $e');
      return false;
    }
  }

  /// Request accessibility permission (opens system settings)
  static Future<void> requestAccessibilityPermission() async {
    try {
      await platform.invokeMethod<void>('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error requesting accessibility permission: $e');
    }
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await platform.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking service status: $e');
      return false;
    }
  }
}
