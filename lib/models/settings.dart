// models/settings.dart — KOVA Settings data model
class KovaSettings {
  final String id;
  final String parentId;
  final bool notificationsEnabled;
  final bool alertSound;
  final bool autoBlock;
  final String sensitivityLevel;
  final bool dailyReport;
  final int screenTimeLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  KovaSettings({
    required this.id,
    required this.parentId,
    required this.notificationsEnabled,
    required this.alertSound,
    required this.autoBlock,
    required this.sensitivityLevel,
    required this.dailyReport,
    required this.screenTimeLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── SQLite serialization ──

  factory KovaSettings.fromMap(Map<String, dynamic> map) {
    return KovaSettings(
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      notificationsEnabled: (map['notifications_enabled'] as int? ?? 1) == 1,
      alertSound: (map['alert_sound'] as int? ?? 1) == 1,
      autoBlock: (map['auto_block'] as int? ?? 0) == 1,
      sensitivityLevel: map['sensitivity_level'] as String? ?? 'medium',
      dailyReport: (map['daily_report'] as int? ?? 1) == 1,
      screenTimeLimit: map['screen_time_limit'] as int? ?? 120,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'notifications_enabled': notificationsEnabled ? 1 : 0,
    'alert_sound': alertSound ? 1 : 0,
    'auto_block': autoBlock ? 1 : 0,
    'sensitivity_level': sensitivityLevel,
    'daily_report': dailyReport ? 1 : 0,
    'screen_time_limit': screenTimeLimit,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  // ── JSON compat ──

  factory KovaSettings.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return KovaSettings(
      id: json['id'] ?? '',
      parentId: json['parentId'] ?? json['parent_id'] ?? '',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      alertSound: json['alertSound'] ?? true,
      autoBlock: json['autoBlock'] ?? false,
      sensitivityLevel: json['sensitivityLevel'] ?? 'medium',
      dailyReport: json['dailyReport'] ?? true,
      screenTimeLimit: json['screenTimeLimit'] ?? 120,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : now,
    );
  }

  /// Copy with modifications
  KovaSettings copyWith({
    bool? notificationsEnabled,
    bool? alertSound,
    bool? autoBlock,
    String? sensitivityLevel,
    bool? dailyReport,
    int? screenTimeLimit,
  }) {
    return KovaSettings(
      id: id,
      parentId: parentId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      alertSound: alertSound ?? this.alertSound,
      autoBlock: autoBlock ?? this.autoBlock,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      dailyReport: dailyReport ?? this.dailyReport,
      screenTimeLimit: screenTimeLimit ?? this.screenTimeLimit,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
