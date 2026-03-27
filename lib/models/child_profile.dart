// models/child_profile.dart — Child Profile data model
class ChildProfile {
  final String id;
  final String parentId;
  final String name;
  final int age;
  final int safetyScore;
  final bool isOnline;
  final String? deviceId;
  final DateTime? lastSeen;
  final DateTime createdAt;

  ChildProfile({
    required this.id,
    required this.parentId,
    required this.name,
    required this.age,
    required this.safetyScore,
    required this.isOnline,
    this.deviceId,
    this.lastSeen,
    required this.createdAt,
  });

  // ── SQLite serialization ──

  factory ChildProfile.fromMap(Map<String, dynamic> map) {
    return ChildProfile(
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      safetyScore: map['safety_score'] as int? ?? 95,
      isOnline: (map['is_online'] as int? ?? 0) == 1,
      deviceId: map['device_id'] as String?,
      lastSeen: map['last_seen'] != null
          ? DateTime.parse(map['last_seen'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'parent_id': parentId,
    'name': name,
    'age': age,
    'safety_score': safetyScore,
    'is_online': isOnline ? 1 : 0,
    'device_id': deviceId,
    'last_seen': lastSeen?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  // ── JSON compat (kept for flexibility) ──

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      parentId: json['parent_id'] ?? json['parentId'] ?? '',
      name: json['name'] as String,
      age: json['age'] as int,
      safetyScore: json['safety_score'] ?? json['safetyScore'] ?? 95,
      isOnline: json['is_online'] ?? json['isOnline'] ?? false,
      deviceId: json['device_id'] ?? json['deviceId'],
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentId': parentId,
    'name': name,
    'age': age,
    'safetyScore': safetyScore,
    'isOnline': isOnline,
    'deviceId': deviceId,
    'lastSeen': lastSeen?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  /// Initial letter for avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
