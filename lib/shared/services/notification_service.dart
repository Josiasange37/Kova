// shared/services/notification_service.dart — Local push notifications
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize local notifications
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    // Linux settings for desktop
    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Show an alert notification
  static Future<void> showAlert(
    String title,
    String body, {
    String? alertId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'kova_alerts',
      'KOVA Alerts',
      channelDescription: 'Important safety alerts from KOVA',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final linuxDetails = const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    final details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      alertId?.hashCode ?? 0,
      title,
      body,
      details,
    );
  }

  /// Show a critical alert with high priority
  static Future<void> showCriticalAlert(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'kova_critical',
      'KOVA Critical Alerts',
      channelDescription:
          'Critical safety alerts requiring immediate attention',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    final linuxDetails = const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  /// Cancel a notification
  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
