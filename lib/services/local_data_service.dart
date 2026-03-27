// services/local_data_service.dart — All CRUD operations via SQLite
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:kova/models/alert.dart';
import 'package:kova/models/app_control.dart';
import 'package:kova/models/child_profile.dart';
import 'package:kova/models/dashboard.dart';
import 'package:kova/models/settings.dart';
import 'package:kova/services/database_helper.dart';

class LocalDataService {
  final _db = DatabaseHelper.instance;
  final _storage = const FlutterSecureStorage();
  static const _uuid = Uuid();

  // Singleton
  static final LocalDataService _instance = LocalDataService._internal();
  factory LocalDataService() => _instance;
  LocalDataService._internal();

  // ═══════════════════════════════════════════════
  // ──  Children
  // ═══════════════════════════════════════════════

  Future<List<ChildProfile>> getChildren(String parentId) async {
    final db = await _db.database;
    final results = await db.query(
      'children',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => ChildProfile.fromMap(m)).toList();
  }

  Future<ChildProfile?> getChild(String childId) async {
    final db = await _db.database;
    final results = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [childId],
    );
    if (results.isEmpty) return null;
    return ChildProfile.fromMap(results.first);
  }

  Future<ChildProfile?> addChild(String parentId, String name, int age) async {
    try {
      final db = await _db.database;
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      await db.insert('children', {
        'id': id,
        'parent_id': parentId,
        'name': name,
        'age': age,
        'safety_score': 95,
        'is_online': 0,
        'created_at': now,
      });

      // Set as active child if none exists
      final currentActive = await _storage.read(key: 'active_child_id');
      if (currentActive == null) {
        await _storage.write(key: 'active_child_id', value: id);
      }

      return await getChild(id);
    } catch (e) {
      // ignore: avoid_print
      print('Add child error: $e');
      return null;
    }
  }

  Future<bool> updateChild(String childId, {String? name, int? age}) async {
    try {
      final db = await _db.database;
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (age != null) updates['age'] = age;
      if (updates.isEmpty) return true;

      await db.update('children', updates,
          where: 'id = ?', whereArgs: [childId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the active child ID
  Future<String?> getActiveChildId(String parentId) async {
    String? childId = await _storage.read(key: 'active_child_id');
    if (childId == null) {
      final children = await getChildren(parentId);
      if (children.isNotEmpty) {
        childId = children.first.id;
        await _storage.write(key: 'active_child_id', value: childId);
      }
    }
    return childId;
  }

  Future<void> setActiveChildId(String childId) async {
    await _storage.write(key: 'active_child_id', value: childId);
  }

  // ═══════════════════════════════════════════════
  // ──  Alerts
  // ═══════════════════════════════════════════════

  Future<List<Alert>> getAlerts({
    String? childId,
    String? severity,
    bool? resolved,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (childId != null) {
      conditions.add('a.child_id = ?');
      args.add(childId);
    }
    if (severity != null) {
      conditions.add('a.severity = ?');
      args.add(severity);
    }
    if (resolved != null) {
      conditions.add('a.is_resolved = ?');
      args.add(resolved ? 1 : 0);
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT a.*, c.name as child_name
      FROM alerts a
      LEFT JOIN children c ON a.child_id = c.id
      $whereClause
      ORDER BY a.created_at DESC
    ''', args);

    return results.map((m) => Alert.fromMap(m)).toList();
  }

  Future<Alert?> getAlert(String alertId) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT a.*, c.name as child_name
      FROM alerts a
      LEFT JOIN children c ON a.child_id = c.id
      WHERE a.id = ?
    ''', [alertId]);

    if (results.isEmpty) return null;
    return Alert.fromMap(results.first);
  }

  Future<Alert?> addAlert({
    required String childId,
    required String appName,
    required String alertType,
    required String severity,
    String? senderInfo,
    String? contentPreview,
    double aiConfidence = 0.85,
  }) async {
    try {
      final db = await _db.database;
      final id = _uuid.v4();

      await db.insert('alerts', {
        'id': id,
        'child_id': childId,
        'app_name': appName,
        'alert_type': alertType,
        'severity': severity,
        'sender_info': senderInfo,
        'content_preview': contentPreview,
        'ai_confidence': aiConfidence,
        'is_resolved': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update child safety score
      await _recalculateSafetyScore(childId);

      return await getAlert(id);
    } catch (e) {
      // ignore: avoid_print
      print('Add alert error: $e');
      return null;
    }
  }

  Future<bool> resolveAlert(String alertId, String action) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        'alerts',
        {
          'is_resolved': 1,
          'resolved_action': action,
          'resolved_at': now,
        },
        where: 'id = ?',
        whereArgs: [alertId],
      );

      // Get alert to find child
      final alert = await getAlert(alertId);
      if (alert != null) {
        await _recalculateSafetyScore(alert.childId);
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Resolve alert error: $e');
      return false;
    }
  }

  /// Recalculate safety score based on unresolved alerts
  Future<void> _recalculateSafetyScore(String childId) async {
    final db = await _db.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as total,
             SUM(CASE WHEN severity = 'critical' THEN 1 ELSE 0 END) as critical,
             SUM(CASE WHEN severity = 'high' THEN 1 ELSE 0 END) as high,
             SUM(CASE WHEN severity = 'medium' THEN 1 ELSE 0 END) as medium
      FROM alerts
      WHERE child_id = ? AND is_resolved = 0
    ''', [childId]);

    if (result.isEmpty) return;

    final row = result.first;
    final critical = (row['critical'] as int?) ?? 0;
    final high = (row['high'] as int?) ?? 0;
    final medium = (row['medium'] as int?) ?? 0;

    // Each critical = -15, high = -10, medium = -5
    int score = 100 - (critical * 15) - (high * 10) - (medium * 5);
    score = score.clamp(0, 100);

    await db.update(
      'children',
      {'safety_score': score},
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  // ═══════════════════════════════════════════════
  // ──  App Controls
  // ═══════════════════════════════════════════════

  Future<List<AppControl>> getMonitoredApps(String childId) async {
    final db = await _db.database;
    final results = await db.query(
      'app_controls',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'app_name ASC',
    );
    return results.map((m) => AppControl.fromMap(m)).toList();
  }

  Future<AppControl?> addMonitoredApp({
    required String childId,
    required String appName,
    String? packageName,
    String category = 'social',
    String sensitivity = 'normal',
  }) async {
    try {
      final db = await _db.database;
      final id = _uuid.v4();

      await db.insert('app_controls', {
        'id': id,
        'child_id': childId,
        'app_name': appName,
        'package_name': packageName,
        'category': category,
        'sensitivity': sensitivity,
        'is_blocked': 0,
        'is_monitored': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final results = await db.query(
        'app_controls',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return AppControl.fromMap(results.first);
    } catch (e) {
      // ignore: avoid_print
      print('Add app error: $e');
      return null;
    }
  }

  Future<bool> updateAppControl(
    String appId, {
    String? sensitivity,
    bool? isBlocked,
    bool? isMonitored,
  }) async {
    try {
      final db = await _db.database;
      final updates = <String, dynamic>{};
      if (sensitivity != null) updates['sensitivity'] = sensitivity;
      if (isBlocked != null) updates['is_blocked'] = isBlocked ? 1 : 0;
      if (isMonitored != null) updates['is_monitored'] = isMonitored ? 1 : 0;
      if (updates.isEmpty) return true;

      await db.update('app_controls', updates,
          where: 'id = ?', whereArgs: [appId]);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Update app control error: $e');
      return false;
    }
  }

  Future<bool> removeApp(String appId) async {
    try {
      final db = await _db.database;
      await db.delete('app_controls', where: 'id = ?', whereArgs: [appId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  Dashboard (aggregate queries)
  // ═══════════════════════════════════════════════

  Future<DashboardData?> getDashboardData(String childId) async {
    try {
      final db = await _db.database;

      // Get child
      final childResults = await db.query(
        'children',
        where: 'id = ?',
        whereArgs: [childId],
      );
      if (childResults.isEmpty) return null;
      final childMap = childResults.first;

      // Get alert counts
      final alertCountResult = await db.rawQuery('''
        SELECT COUNT(*) as total,
               SUM(CASE WHEN severity IN ('critical','high') THEN 1 ELSE 0 END) as critical
        FROM alerts
        WHERE child_id = ? AND is_resolved = 0
      ''', [childId]);

      final alertCount = (alertCountResult.first['total'] as int?) ?? 0;
      final criticalCount = (alertCountResult.first['critical'] as int?) ?? 0;

      // Get monitored apps
      final apps = await getMonitoredApps(childId);

      // Get recent alerts (last 5)
      final recentAlertResults = await db.rawQuery('''
        SELECT a.*, c.name as child_name
        FROM alerts a
        LEFT JOIN children c ON a.child_id = c.id
        WHERE a.child_id = ?
        ORDER BY a.created_at DESC
        LIMIT 5
      ''', [childId]);

      return DashboardData(
        child: DashboardChild(
          id: childMap['id'] as String,
          name: childMap['name'] as String,
          age: childMap['age'] as int,
          isOnline: (childMap['is_online'] as int?) == 1,
          lastSeen: childMap['last_seen'] != null
              ? DateTime.parse(childMap['last_seen'] as String)
              : null,
        ),
        safetyScore: childMap['safety_score'] as int? ?? 95,
        alertCount: alertCount,
        criticalCount: criticalCount,
        hasAlerts: alertCount > 0,
        monitoredApps: apps,
        recentAlerts:
            recentAlertResults.map((m) => Alert.fromMap(m)).toList(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Get dashboard error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  Settings
  // ═══════════════════════════════════════════════

  Future<KovaSettings?> getSettings(String parentId) async {
    final db = await _db.database;
    final results = await db.query(
      'settings',
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );
    if (results.isEmpty) return null;
    return KovaSettings.fromMap(results.first);
  }

  Future<bool> updateSettings(KovaSettings settings) async {
    try {
      final db = await _db.database;
      await db.update(
        'settings',
        settings.toMap(),
        where: 'id = ?',
        whereArgs: [settings.id],
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Update settings error: $e');
      return false;
    }
  }

  Future<KovaSettings> ensureSettings(String parentId) async {
    final existing = await getSettings(parentId);
    if (existing != null) return existing;

    // Create default settings
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('settings', {
      'id': id,
      'parent_id': parentId,
      'notifications_enabled': 1,
      'alert_sound': 1,
      'auto_block': 0,
      'sensitivity_level': 'medium',
      'daily_report': 1,
      'screen_time_limit': 120,
      'created_at': now,
      'updated_at': now,
    });

    return (await getSettings(parentId))!;
  }

  // ═══════════════════════════════════════════════
  // ──  Pairing Codes
  // ═══════════════════════════════════════════════

  Future<String?> generatePairingCode(String childId) async {
    try {
      final db = await _db.database;
      final id = _uuid.v4();
      final code = _generateCode();
      final expiresAt =
          DateTime.now().add(const Duration(minutes: 15)).toIso8601String();

      await db.insert('pairing_codes', {
        'id': id,
        'child_id': childId,
        'code': code,
        'is_used': 0,
        'expires_at': expiresAt,
        'created_at': DateTime.now().toIso8601String(),
      });

      return code;
    } catch (e) {
      // ignore: avoid_print
      print('Generate pairing code error: $e');
      return null;
    }
  }

  Future<String?> validatePairingCode(String code) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      'pairing_codes',
      where: 'code = ? AND is_used = 0 AND expires_at > ?',
      whereArgs: [code, now],
    );

    if (results.isEmpty) return null;

    final childId = results.first['child_id'] as String;

    // Mark as used
    await db.update(
      'pairing_codes',
      {'is_used': 1},
      where: 'id = ?',
      whereArgs: [results.first['id']],
    );

    return childId;
  }

  String _generateCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
