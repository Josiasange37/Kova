import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// All permissions the PARENT device needs to function correctly.
/// Call [checkAndRequestAll] on first launch and after onboarding.
class ParentPermissionService {
  static const _channel = MethodChannel('com.kova.child/setup');

  // ─── Permission Status Snapshot ──────────────────────────────────────────
  /// Returns a map of all permission statuses. Used to drive the UI.
  static Future<Map<String, bool>> getStatus() async {
    if (!Platform.isAndroid) {
      return {
        'notifications': true,
        'nearbyWifi': true,
        'battery': true,
        'exactAlarm': true,
      };
    }

    final notif = await Permission.notification.isGranted;
    final nearbyWifi = await _isNearbyWifiGranted();
    final battery = await _isBatteryOptimizationIgnored();
    final exactAlarm = await _isExactAlarmGranted();

    return {
      'notifications': notif,
      'nearbyWifi': nearbyWifi,
      'battery': battery,
      'exactAlarm': exactAlarm,
    };
  }

  /// True only if every REQUIRED permission is granted.
  /// Optional permissions (battery, exactAlarm) don't block the app.
  static Future<bool> allRequiredGranted() async {
    final s = await getStatus();
    return (s['notifications'] ?? false) && (s['nearbyWifi'] ?? false);
  }

  // ─── Individual Request Methods ───────────────────────────────────────────

  /// Request POST_NOTIFICATIONS (Android 13+).
  static Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Request NEARBY_WIFI_DEVICES (Android 12+).
  /// Required for UDP LAN discovery — without it the parent cannot find
  /// the child on the local network. Silently granted on Android < 12.
  static Future<bool> requestNearbyWifi() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _getSdkVersion();
    if (sdk < 31) return true; // Not needed below Android 12
    final result = await Permission.nearbyWifiDevices.request();
    return result.isGranted;
  }

  /// Open battery optimization settings (user action required — cannot be
  /// granted programmatically without prompting via system dialog).
  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (e) {
      debugPrint('⚠️ Battery optimization request failed: $e');
    }
  }

  /// Request SCHEDULE_EXACT_ALARM (Android 12+).
  static Future<bool> requestExactAlarm() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await Permission.scheduleExactAlarm.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('⚠️ Exact alarm permission not available: $e');
      return true; // Not critical
    }
  }

  // ─── Convenience: request everything at once ──────────────────────────────
  static Future<bool> checkAndRequestAll(BuildContext context) async {
    await requestNotifications();
    await requestNearbyWifi();
    await requestExactAlarm();

    final battery = await _isBatteryOptimizationIgnored();
    if (!battery && context.mounted) {
      await _showBatteryDialog(context);
    }

    final notif = await Permission.notification.isGranted;
    if (!notif && context.mounted) {
      await _showNotificationDeniedDialog(context);
    }

    return await allRequiredGranted();
  }

  // ─── Quick checks ─────────────────────────────────────────────────────────

  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Future<bool> _isNearbyWifiGranted() async {
    try {
      final sdk = await _getSdkVersion();
      if (sdk < 31) return true;
      return await Permission.nearbyWifiDevices.isGranted;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> _isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isExactAlarmGranted() async {
    try {
      final sdk = await _getSdkVersion();
      if (sdk < 31) return true;
      return await Permission.scheduleExactAlarm.isGranted;
    } catch (_) {
      return true;
    }
  }

  static int? _cachedSdk;
  static Future<int> _getSdkVersion() async {
    if (_cachedSdk != null) return _cachedSdk!;
    try {
      final sdk = await _channel.invokeMethod<int>('getSdkVersion') ?? 30;
      _cachedSdk = sdk;
      return sdk;
    } catch (_) {
      _cachedSdk = 30;
      return 30;
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  static Future<void> _showBatteryDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Text('🔋 ', style: TextStyle(fontSize: 24)),
            Text('Battery Optimization', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Disable battery optimization so KOVA keeps receiving alerts '
          'even when your screen is off.\n\n'
          'On Xiaomi/MIUI: Settings → Apps → KOVA → '
          'Energy Saver → No restrictions',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await requestBatteryOptimization();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Future<void> _showNotificationDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Text('🔔 ', style: TextStyle(fontSize: 24)),
            Text('Notifications Required', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'KOVA needs notification permission to alert you immediately '
          'when your child is in danger.\n\n'
          'Without this permission, you will receive NO alerts.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ignore', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
