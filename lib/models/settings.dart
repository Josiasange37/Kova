// Dart data model for Settings
class KovaSettings {
  final String? parentName;
  final String? parentPhone;
  final String? childName;
  final int? childAge;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final String language;
  final bool notificationsEnabled;
  final bool weeklyReportEnabled;

  KovaSettings({
    this.parentName,
    this.parentPhone,
    this.childName,
    this.childAge,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.language,
    required this.notificationsEnabled,
    required this.weeklyReportEnabled,
  });

  factory KovaSettings.fromJson(Map<String, dynamic> json) {
    return KovaSettings(
      parentName: json['parentName'],
      parentPhone: json['parentPhone'],
      childName: json['childName'],
      childAge: json['childAge'],
      quietHoursEnabled: json['quietHoursEnabled'] ?? false,
      quietHoursStart: json['quietHoursStart'] ?? '22:00',
      quietHoursEnd: json['quietHoursEnd'] ?? '07:00',
      language: json['language'] ?? 'en',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      weeklyReportEnabled: json['weeklyReportEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'quietHoursEnabled': quietHoursEnabled,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'language': language,
        'notificationsEnabled': notificationsEnabled,
        'weeklyReportEnabled': weeklyReportEnabled,
      };
}
