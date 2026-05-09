import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages all permissions the parent app needs to function correctly.
/// Call checkAndRequestAll() on first launch and after onboarding.
class ParentPermissionService {
  static const _channel = MethodChannel('com.kova.child/setup');

  /// Returns true if ALL critical permissions are granted.
  static Future<bool> checkAndRequestAll(BuildContext context) async {
    final results = <String, bool>{};

    // 1. Notification permission (Android 13+ / API 33+)
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        final result = await Permission.notification.request();
        results['notifications'] = result.isGranted;
      } else {
        results['notifications'] = true;
      }
    }

    // 2. Battery optimization exemption (critical for MIUI — keeps alert polling alive)
    try {
      final isBatteryExempt = await _channel
          .invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
      if (!isBatteryExempt && context.mounted) {
        await _showBatteryDialog(context);
      }
      results['battery'] = true; // Non-blocking — user can skip
    } catch (e) {
      debugPrint('⚠️ Battery check failed: $e');
      results['battery'] = true;
    }

    // 3. Exact alarm permission (Android 12+ — needed for scheduled sync)
    if (Platform.isAndroid) {
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        if (!alarmStatus.isGranted) {
          await Permission.scheduleExactAlarm.request();
        }
      } catch (e) {
        debugPrint('⚠️ Alarm permission not available: $e');
      }
    }

    final notifGranted = results['notifications'] ?? false;

    if (!notifGranted && context.mounted) {
      await _showNotificationDeniedDialog(context);
    }

    debugPrint('✅ [PARENT PERMISSIONS] notifications=$notifGranted');
    return notifGranted;
  }

  /// Check if notification permission is granted (quick check, no dialog).
  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  static Future<void> _showBatteryDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('🔋 ', style: TextStyle(fontSize: 24)),
            Text('Optimisation batterie'),
          ],
        ),
        content: const Text(
          'Pour recevoir les alertes KOVA même quand l\'écran est éteint, '
          'désactivez l\'optimisation batterie pour KOVA.\n\n'
          'Sur MIUI: Paramètres → Applications → KOVA → '
          'Économie d\'énergie → Aucune restriction',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _channel.invokeMethod('requestIgnoreBatteryOptimization');
              } catch (e) {
                debugPrint('⚠️ Battery optimization request failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Désactiver',
              style: TextStyle(color: Colors.white),
            ),
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
        title: const Row(
          children: [
            Text('🔔 ', style: TextStyle(fontSize: 24)),
            Text('Notifications requises'),
          ],
        ),
        content: const Text(
          'KOVA a besoin des notifications pour vous alerter '
          'immédiatement quand votre enfant est en danger.\n\n'
          'Sans cette permission, vous ne recevrez AUCUNE alerte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ignorer'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Ouvrir Paramètres',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
