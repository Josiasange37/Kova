// shared/services/notification_service.dart — Local push notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize local notifications
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const initSettings = InitializationSettings(android: androidSettings);

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

    const details = NotificationDetails(android: androidDetails);

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

    const details = NotificationDetails(android: androidDetails);

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
