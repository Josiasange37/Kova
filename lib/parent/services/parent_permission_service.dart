import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// All permissions the PARENT device needs to function correctly.
/// Call [checkAndRequestAll] on first launch and after onboarding.
///
/// Each "Grant" button opens the EXACT system settings page for that
/// permission, so the user only needs to flip one toggle and come back.
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

  static Future<bool> allRequiredGranted() async {
    final s = await getStatus();
    // Nearby Wi-Fi is optional (falls back to relay if denied/hidden by OS)
    return (s['notifications'] ?? false);
  }

  // ─── Individual Request Methods ───────────────────────────────────────────
  // Each method requests the permission. If denied, it opens the exact
  // system settings page so the user can grant it manually.

  /// Request POST_NOTIFICATIONS (Android 13+).
  /// If denied or permanently denied, opens the app notification settings.
  static Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    final result = await Permission.notification.request();
    if (result.isGranted) return true;

    // Denied — open the app's notification settings page directly
    await _openAppNotificationSettings();
    return false;
  }

  /// Request NEARBY_WIFI_DEVICES and Bluetooth (Android 12+).
  /// Some tablets/OS skins require both to show the "Nearby devices" permission group.
  static Future<bool> requestNearbyWifi() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _getSdkVersion();
    if (sdk < 31) return true; // Not needed below Android 12
    
    // Request all "Nearby devices" permissions together to satisfy strict OS skins
    final statuses = await [
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    
    if (statuses[Permission.nearbyWifiDevices] == PermissionStatus.granted ||
        statuses[Permission.bluetoothScan] == PermissionStatus.granted) {
      return true;
    }

    // Denied — open the app's permission settings so user can find "Nearby devices"
    await openAppSettings();
    return false;
  }

  /// Open battery optimization settings (user action required — cannot be
  /// granted programmatically without prompting via system dialog).
  /// Opens the EXACT battery optimization exemption page.
  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
      // Fallback: open the general battery settings page
      try {
        await _channel.invokeMethod('openBatterySettings');
      } catch (_) {
        await openAppSettings();
      }
    }
  }

  /// Request SCHEDULE_EXACT_ALARM (Android 12+).
  /// If the system doesn't show a dialog, opens the alarms settings page.
  static Future<bool> requestExactAlarm() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) return true;

      // Open the exact alarm settings page directly
      await _openExactAlarmSettings();
      return false;
    } catch (e) {
      debugPrint('Exact alarm permission not available: $e');
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

  /// Start parent foreground protection service (persistence)
  static Future<void> startParentProtectionService() async {
    try {
      await _channel.invokeMethod<void>('startParentProtection');
    } catch (e) {
      debugPrint('Error starting parent protection service: $e');
    }
  }

  // ─── Quick checks ─────────────────────────────────────────────────────────

  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  // ─── Settings Openers (via MethodChannel) ─────────────────────────────────

  /// Opens the app's notification settings page
  /// (Settings > Apps > KOVA > Notifications)
  static Future<void> _openAppNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('openNotificationSettings failed: $e');
      // Fallback to generic app settings
      await openAppSettings();
    }
  }

  /// Opens the Exact Alarm settings page
  /// (Settings > Apps > Special access > Alarms & reminders)
  static Future<void> _openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('openExactAlarmSettings failed: $e');
      await openAppSettings();
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Future<bool> _isNearbyWifiGranted() async {
    try {
      final sdk = await _getSdkVersion();
      if (sdk < 31) return true;
      
      // ── Bug Fix: Check multiple permission sources ─────────────────────────
      // Some Android skins (MIUI, OneUI) may grant nearby devices via bluetooth
      // instead of the dedicated nearbyWifiDevices permission
      final nearbyWifi = await Permission.nearbyWifiDevices.isGranted;
      final bluetoothScan = await Permission.bluetoothScan.isGranted;
      final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      final location = await Permission.location.isGranted;
      
      // Return true if ANY of the related permissions are granted
      // This handles OEM-specific permission groupings
      return nearbyWifi || bluetoothScan || bluetoothConnect || location;
    } catch (e) {
      debugPrint('⚠️ Nearby WiFi permission check error: $e');
      // On error, assume granted to avoid blocking the user
      // The actual LAN functionality will fail gracefully if truly denied
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_saver_outlined, color: Color(0xFF1B2B6B), size: 24),
            SizedBox(width: 8),
            Text('Battery Optimization',
                style: TextStyle(color: Color(0xFF1B2B6B), fontSize: 18)),
          ],
        ),
        content: const Text(
          'Disable battery optimization so KOVA keeps receiving alerts '
          'even when your screen is off.\n\n'
          'On Xiaomi/MIUI: Settings > Apps > KOVA > '
          'Energy Saver > No restrictions',
          style: TextStyle(color: Color(0xFF7F8C9B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: Color(0xFF7F8C9B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await requestBatteryOptimization();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: Color(0xFFE74C3C), size: 24),
            SizedBox(width: 8),
            Text('Notifications Required',
                style: TextStyle(color: Color(0xFF1B2B6B), fontSize: 18)),
          ],
        ),
        content: const Text(
          'KOVA needs notification permission to alert you immediately '
          'when your child is in danger.\n\n'
          'Without this permission, you will receive NO alerts.',
          style: TextStyle(color: Color(0xFF7F8C9B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ignore',
                style: TextStyle(color: Color(0xFF7F8C9B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openAppNotificationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
