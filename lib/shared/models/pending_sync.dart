import 'dart:convert';

class PendingSync {
  final String id;
  final String type; // 'history' or 'alert'
  final String payload; // JSON string of the object
  final DateTime createdAt;

  PendingSync({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  factory PendingSync.fromMap(Map<String, dynamic> map) {
    return PendingSync(
      id: map['id'] as String,
      type: map['type'] as String,
      payload: map['payload'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }
}
