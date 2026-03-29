// local_backend/repositories/alert_repository.dart — Alert CRUD operations
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_service.dart';

/// Model for alert data
class AlertModel {
  final String id;
  final String childId;
  final String app;
  final String type;
  final String severity;
  final double scoreText;
  final double scoreImage;
  final double scoreGrooming;
  final bool read;
  final bool resolved;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.childId,
    required this.app,
    required this.type,
    required this.severity,
    required this.scoreText,
    required this.scoreImage,
    required this.scoreGrooming,
    required this.read,
    required this.resolved,
    required this.createdAt,
  });

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      app: map['app'] as String,
      type: map['type'] as String,
      severity: map['severity'] as String,
      scoreText: (map['score_text'] as num? ?? 0).toDouble(),
      scoreImage: (map['score_image'] as num? ?? 0).toDouble(),
      scoreGrooming: (map['score_grooming'] as num? ?? 0).toDouble(),
      read: (map['read'] as int? ?? 0) == 1,
      resolved: (map['resolved'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'app': app,
    'type': type,
    'severity': severity,
    'score_text': scoreText,
    'score_image': scoreImage,
    'score_grooming': scoreGrooming,
    'read': read ? 1 : 0,
    'resolved': resolved ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  AlertModel copyWith({
    String? id,
    String? childId,
    String? app,
    String? type,
    String? severity,
    double? scoreText,
    double? scoreImage,
    double? scoreGrooming,
    bool? read,
    bool? resolved,
    DateTime? createdAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      app: app ?? this.app,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      scoreText: scoreText ?? this.scoreText,
      scoreImage: scoreImage ?? this.scoreImage,
      scoreGrooming: scoreGrooming ?? this.scoreGrooming,
      read: read ?? this.read,
      resolved: resolved ?? this.resolved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns true if alert is critical/high severity
  bool get isCritical => severity == 'critical' || severity == 'high';

  /// Returns a color-coded label
  String get severityLabel => switch (severity) {
    'critical' => 'CRITICAL',
    'high' => 'HIGH',
    'medium' => 'MEDIUM',
    'low' => 'LOW',
    _ => severity.toUpperCase(),
  };
}

/// Repository for alert operations
class AlertRepository {
  final _db = DatabaseService();

  /// Create a new alert
  /// Returns the alert ID
  Future<String> create({
    required String childId,
    required String app,
    required String type,
    required String severity,
    required double scoreText,
    required double scoreImage,
    required double scoreGrooming,
  }) async {
    final db = await _db.database;
    final id = const Uuid().v4();

    await db.insert('alerts', {
      'id': id,
      'child_id': childId,
      'app': app,
      'type': type,
      'severity': severity,
      'score_text': scoreText,
      'score_image': scoreImage,
      'score_grooming': scoreGrooming,
      'read': 0,
      'resolved': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return id;
  }

  /// Get all alerts with optional filters
  Future<List<AlertModel>> getAll({
    String? childId,
    bool? read,
    String? severity,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (childId != null) {
      conditions.add('child_id = ?');
      args.add(childId);
    }
    if (read != null) {
      conditions.add('read = ?');
      args.add(read ? 1 : 0);
    }
    if (severity != null) {
      conditions.add('severity = ?');
      args.add(severity);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    final rows = await db.query(
      'alerts',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(AlertModel.fromMap).toList();
  }

  /// Get a single alert by ID
  Future<AlertModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('alerts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AlertModel.fromMap(rows.first);
  }

  /// Count unread alerts
  Future<int> getUnreadCount(String? childId) async {
    final db = await _db.database;

    if (childId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM alerts WHERE read = 0 AND child_id = ?',
        [childId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } else {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM alerts WHERE read = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
  }

  /// Mark an alert as read
  Future<void> markRead(String id) async {
    final db = await _db.database;
    await db.update('alerts', {'read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Mark an alert as resolved
  Future<void> resolve(String id) async {
    final db = await _db.database;
    await db.update(
      'alerts',
      {'resolved': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an alert
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  /// Get critical alerts only
  Future<List<AlertModel>> getCritical(String? childId) async {
    return getAll(childId: childId, severity: 'critical', limit: 100);
  }

  /// Get alerts from last N hours
  Future<List<AlertModel>> getRecent(String? childId, int hours) async {
    final db = await _db.database;
    final since = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;

    final where = childId != null
        ? 'child_id = ? AND created_at > ?'
        : 'created_at > ?';
    final whereArgs = childId != null ? [childId, since] : [since];

    final rows = await db.query(
      'alerts',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map(AlertModel.fromMap).toList();
  }

  /// Delete all resolved alerts for a child
  Future<int> deleteResolved(String childId) async {
    final db = await _db.database;
    return await db.delete(
      'alerts',
      where: 'child_id = ? AND resolved = 1',
      whereArgs: [childId],
    );
  }
}
