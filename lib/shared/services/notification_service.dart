// shared/services/notification_service.dart — Local push notifications
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Stream controller to broadcast notification clicks
  static final _onNotificationClick = StreamController<String?>.broadcast();
  static Stream<String?> get onNotificationClick => _onNotificationClick.stream;

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

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Broadcast the payload when notification is tapped
        _onNotificationClick.add(response.payload);
      },
    );
  }

  /// Check if the app was launched via a notification tap (Cold Start)
  static Future<void> checkForLaunchNotification() async {
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      final response = details.notificationResponse;
      if (response != null && response.payload != null) {
        // Delay slightly to ensure listeners are registered
        Future.delayed(const Duration(milliseconds: 500), () {
          _onNotificationClick.add(response.payload);
        });
      }
    }
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

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      id: alertId?.hashCode ?? 0,
      title: title,
      body: body,
      notificationDetails: details,
      payload: alertId,
    );
  }

  /// Show a critical alert with high priority
  static Future<void> showCriticalAlert(
    String title,
    String body, {
    String? alertId,
  }) async {
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

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      id: alertId?.hashCode ?? DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: details,
      payload: alertId,
    );
  }

  /// Cancel a notification
  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
