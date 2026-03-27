// Dart data model for Dashboard (aggregated response)
import 'package:kova/models/alert.dart';
import 'package:kova/models/app_control.dart';

class DashboardChild {
  final String id;
  final String name;
  final int age;
  final bool isOnline;
  final DateTime? lastSeen;

  DashboardChild({
    required this.id,
    required this.name,
    required this.age,
    required this.isOnline,
    this.lastSeen,
  });

  factory DashboardChild.fromJson(Map<String, dynamic> json) {
    return DashboardChild(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
    );
  }
}

class DashboardData {
  final DashboardChild child;
  final int safetyScore;
  final int alertCount;
  final int criticalCount;
  final bool hasAlerts;
  final List<AppControl> monitoredApps;
  final List<Alert> recentAlerts;

  DashboardData({
    required this.child,
    required this.safetyScore,
    required this.alertCount,
    required this.criticalCount,
    required this.hasAlerts,
    required this.monitoredApps,
    required this.recentAlerts,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      child: DashboardChild.fromJson(json['child']),
      safetyScore: json['safetyScore'] ?? 95,
      alertCount: json['alertCount'] ?? 0,
      criticalCount: json['criticalCount'] ?? 0,
      hasAlerts: json['hasAlerts'] ?? false,
      monitoredApps: (json['monitoredApps'] as List? ?? [])
          .map((a) => AppControl.fromJson(a))
          .toList(),
      recentAlerts: (json['recentAlerts'] as List? ?? [])
          .map((a) => Alert.fromJson(a))
          .toList(),
    );
  }
}
