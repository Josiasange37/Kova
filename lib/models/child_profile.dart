// Dart data model for Child Profile
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
}
