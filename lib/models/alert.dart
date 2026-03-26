// Dart data model for Alert
class Alert {
  final String id;
  final String childId;
  final String? childName;
  final String appName;
  final String alertType;
  final String severity;
  final String? senderInfo;
  final String? contentPreview;
  final double aiConfidence;
  final bool isResolved;
  final String? resolvedAction;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  Alert({
    required this.id,
    required this.childId,
    this.childName,
    required this.appName,
    required this.alertType,
    required this.severity,
    this.senderInfo,
    this.contentPreview,
    required this.aiConfidence,
    required this.isResolved,
    this.resolvedAction,
    this.resolvedAt,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      childId: json['childId'] ?? json['child_id'] ?? '',
      childName: json['childName'] ?? json['child_name'],
      appName: json['appName'] ?? json['app_name'] ?? '',
      alertType: json['alertType'] ?? json['alert_type'] ?? '',
      severity: json['severity'] as String,
      senderInfo: json['senderInfo'] ?? json['sender_info'],
      contentPreview: json['contentPreview'] ?? json['content_preview'],
      aiConfidence: (json['aiConfidence'] ?? json['ai_confidence'] ?? 0).toDouble(),
      isResolved: json['isResolved'] ?? json['is_resolved'] ?? false,
      resolvedAction: json['resolvedAction'] ?? json['resolved_action'],
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : json['resolved_at'] != null
              ? DateTime.parse(json['resolved_at'])
              : null,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'childName': childName,
        'appName': appName,
        'alertType': alertType,
        'severity': severity,
        'senderInfo': senderInfo,
        'contentPreview': contentPreview,
        'aiConfidence': aiConfidence,
        'isResolved': isResolved,
        'resolvedAction': resolvedAction,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Returns true if this is a high-priority alert
  bool get isCritical => severity == 'high' || severity == 'critical';
}
