// models/app_control.dart — App Control data model
class AppControl {
  final String id;
  final String childId;
  final String appName;
  final String? packageName;
  final String category;
  final String sensitivity;
  final bool isBlocked;
  final bool isMonitored;
  final DateTime createdAt;

  AppControl({
    required this.id,
    required this.childId,
    required this.appName,
    this.packageName,
    required this.category,
    required this.sensitivity,
    required this.isBlocked,
    required this.isMonitored,
    required this.createdAt,
  });

  // ── SQLite serialization ──

  factory AppControl.fromMap(Map<String, dynamic> map) {
    return AppControl(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      appName: map['app_name'] as String,
      packageName: map['package_name'] as String?,
      category: map['category'] as String? ?? 'social',
      sensitivity: map['sensitivity'] as String? ?? 'normal',
      isBlocked: (map['is_blocked'] as int? ?? 0) == 1,
      isMonitored: (map['is_monitored'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'app_name': appName,
    'package_name': packageName,
    'category': category,
    'sensitivity': sensitivity,
    'is_blocked': isBlocked ? 1 : 0,
    'is_monitored': isMonitored ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  // ── JSON compat ──

  factory AppControl.fromJson(Map<String, dynamic> json) {
    return AppControl(
      id: json['id'] ?? json['appId'] ?? json['controlId'] ?? '',
      childId: json['childId'] ?? json['child_id'] ?? '',
      appName: json['appName'] ?? json['app_name'] ?? '',
      packageName: json['packageName'] ?? json['package_name'],
      category: json['category'] ?? 'social',
      sensitivity: json['sensitivity'] ?? 'normal',
      isBlocked: json['isBlocked'] ?? json['is_blocked'] ?? false,
      isMonitored: json['isMonitored'] ?? json['is_monitored'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'childId': childId,
    'appName': appName,
    'packageName': packageName,
    'category': category,
    'sensitivity': sensitivity,
    'isBlocked': isBlocked,
    'isMonitored': isMonitored,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Copy with modifications
  AppControl copyWith({
    String? sensitivity,
    bool? isBlocked,
    bool? isMonitored,
  }) {
    return AppControl(
      id: id,
      childId: childId,
      appName: appName,
      packageName: packageName,
      category: category,
      sensitivity: sensitivity ?? this.sensitivity,
      isBlocked: isBlocked ?? this.isBlocked,
      isMonitored: isMonitored ?? this.isMonitored,
      createdAt: createdAt,
    );
  }
}
