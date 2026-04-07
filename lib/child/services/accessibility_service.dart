// child/services/accessibility_service.dart — Permission helper for all monitoring services
// Uses the setup channel to check/request permissions for:
//   - Accessibility service
//   - Notification listener
//   - Custom keyboard (IME)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const _setup = MethodChannel('com.kova.child/setup');

  /// Check if accessibility permission is granted
  static Future<bool> isAccessibilityPermissionGranted() async {
    try {
      final result = await _setup.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking accessibility permission: $e');
      return false;
    }
  }

  /// Request accessibility permission (opens system settings)
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _setup.invokeMethod<void>('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error requesting accessibility permission: $e');
    }
  }

  /// Check if notification listener is enabled
  static Future<bool> isNotificationListenerEnabled() async {
    try {
      final result = await _setup.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking notification listener: $e');
      return false;
    }
  }

  /// Open notification listener settings
  static Future<void> requestNotificationListenerPermission() async {
    try {
      await _setup.invokeMethod<void>('openNotificationListenerSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  /// Check if KOVA keyboard is enabled and selected
  static Future<bool> isKeyboardEnabled() async {
    try {
      final result = await _setup.invokeMethod<bool>('isKeyboardEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking keyboard: $e');
      return false;
    }
  }

  /// Open input method settings to enable KOVA keyboard
  static Future<void> requestKeyboardPermission() async {
    try {
      await _setup.invokeMethod<void>('openInputMethodSettings');
    } catch (e) {
      debugPrint('Error opening IME settings: $e');
    }
  }

  /// Show keyboard picker to switch to KOVA keyboard
  static Future<void> showKeyboardPicker() async {
    try {
      await _setup.invokeMethod<void>('openInputMethodPicker');
    } catch (e) {
      debugPrint('Error showing IME picker: $e');
    }
  }

  /// Check all services status at once
  static Future<Map<String, bool>> checkAllServices() async {
    final results = await Future.wait([
      isAccessibilityPermissionGranted(),
      isNotificationListenerEnabled(),
      isKeyboardEnabled(),
    ]);
    return {
      'accessibility': results[0],
      'notifications': results[1],
      'keyboard': results[2],
    };
  }
}
