// Dart data model for App Control
class AppControl {
  final String appId;
  final String controlId;
  final String appName;
  final String? packageName;
  final String monitoringType;
  final bool isConnected;
  final String? iconName;
  final String? iconColor;
  final String sensitivity;
  final bool isBlocked;
  final bool isEnabled;

  AppControl({
    required this.appId,
    required this.controlId,
    required this.appName,
    this.packageName,
    required this.monitoringType,
    required this.isConnected,
    this.iconName,
    this.iconColor,
    required this.sensitivity,
    required this.isBlocked,
    required this.isEnabled,
  });

  factory AppControl.fromJson(Map<String, dynamic> json) {
    return AppControl(
      appId: json['appId'] ?? json['app_id'] ?? '',
      controlId: json['controlId'] ?? json['control_id'] ?? '',
      appName: json['appName'] ?? json['app_name'] ?? '',
      packageName: json['packageName'] ?? json['package_name'],
      monitoringType: json['monitoringType'] ?? json['monitoring_type'] ?? 'automatic',
      isConnected: json['isConnected'] ?? json['is_connected'] ?? false,
      iconName: json['iconName'] ?? json['icon_name'],
      iconColor: json['iconColor'] ?? json['icon_color'],
      sensitivity: json['sensitivity'] ?? 'medium',
      isBlocked: json['isBlocked'] ?? json['is_blocked'] ?? false,
      isEnabled: json['isEnabled'] ?? json['is_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'controlId': controlId,
        'appName': appName,
        'packageName': packageName,
        'monitoringType': monitoringType,
        'isConnected': isConnected,
        'iconName': iconName,
        'iconColor': iconColor,
        'sensitivity': sensitivity,
        'isBlocked': isBlocked,
        'isEnabled': isEnabled,
      };
}
