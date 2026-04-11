import 'package:uuid/uuid.dart';

class WebHistory {
  final String id;
  final String url;
  final String title;
  final DateTime createdAt;

  WebHistory({
    String? id,
    required this.url,
    required this.title,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory WebHistory.fromMap(Map<String, dynamic> map) {
    return WebHistory(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  factory WebHistory.fromJson(Map<String, dynamic> json) {
    return WebHistory(
      id: json['id'] as String?,
      url: json['url'] as String,
      title: json['title'] as String,
      createdAt: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'timestamp': createdAt.toIso8601String(),
    };
  }
}
