import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/parent.dart';
import '../models/child_profile.dart';
import '../models/app_control.dart';
import '../models/alert.dart';
import '../models/settings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kova_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Parent Table
    await db.execute('''
CREATE TABLE parent (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  pin_salt TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');

    // 2. Child Profile Table
    await db.execute('''
CREATE TABLE children (
  id TEXT PRIMARY KEY,
  parent_id TEXT NOT NULL,
  name TEXT NOT NULL,
  age INTEGER NOT NULL,
  safety_score INTEGER NOT NULL DEFAULT 100,
  is_online INTEGER NOT NULL DEFAULT 0,
  device_id TEXT,
  last_seen TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE CASCADE
)
''');

    // 3. Settings Table
    await db.execute('''
CREATE TABLE settings (
  id TEXT PRIMARY KEY,
  parent_id TEXT NOT NULL,
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  alert_sound INTEGER NOT NULL DEFAULT 1,
  auto_block INTEGER NOT NULL DEFAULT 0,
  sensitivity_level TEXT NOT NULL DEFAULT 'medium',
  daily_report INTEGER NOT NULL DEFAULT 1,
  screen_time_limit INTEGER NOT NULL DEFAULT 120,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE CASCADE
)
''');

    // 4. App Controls Table
    await db.execute('''
CREATE TABLE app_controls (
  id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT,
  category TEXT NOT NULL DEFAULT 'social',
  sensitivity TEXT NOT NULL DEFAULT 'normal',
  is_blocked INTEGER NOT NULL DEFAULT 0,
  is_monitored INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
)
''');

    // 5. Alerts Table
    await db.execute('''
CREATE TABLE alerts (
  id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  child_name TEXT,
  app_name TEXT NOT NULL,
  alert_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  sender_info TEXT,
  content_preview TEXT,
  ai_confidence REAL NOT NULL DEFAULT 0.0,
  is_resolved INTEGER NOT NULL DEFAULT 0,
  resolved_action TEXT,
  resolved_at TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (child_id) REFERENCES children (id) ON DELETE CASCADE
)
''');
  }

  // ================= PARENT METHODS =================
  Future<Parent> insertParent(Parent parent) async {
    final db = await instance.database;
    await db.insert('parent', parent.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return parent;
  }

  Future<Parent?> getParent() async {
    final db = await instance.database;
    final maps = await db.query('parent', limit: 1);
    if (maps.isNotEmpty) {
      return Parent.fromMap(maps.first);
    }
    return null;
  }

  // ================= CHILD PROFILES =================
  Future<ChildProfile> insertChild(ChildProfile child) async {
    final db = await instance.database;
    await db.insert('children', child.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return child;
  }

  Future<ChildProfile?> getChild(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ChildProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ChildProfile>> getAllChildren() async {
    final db = await instance.database;
    final maps = await db.query('children', orderBy: 'created_at ASC');
    return maps.map((map) => ChildProfile.fromMap(map)).toList();
  }

  Future<int> updateChild(ChildProfile child) async {
    final db = await instance.database;
    return db.update(
      'children',
      child.toMap(),
      where: 'id = ?',
      whereArgs: [child.id],
    );
  }

  Future<int> deleteChild(String id) async {
    final db = await instance.database;
    return await db.delete(
      'children',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================= ALERTS =================
  Future<Alert> insertAlert(Alert alert) async {
    final db = await instance.database;
    await db.insert('alerts', alert.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return alert;
  }

  Future<List<Alert>> getAlertsForChild(String childId) async {
    final db = await instance.database;
    final maps = await db.query(
      'alerts',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  Future<List<Alert>> getAllUnresolvedAlerts() async {
    final db = await instance.database;
    final maps = await db.query(
      'alerts',
      where: 'is_resolved = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  Future<int> markAlertResolved(String alertId, {String? action}) async {
    final db = await instance.database;
    return db.update(
      'alerts',
      {
        'is_resolved': 1,
        'resolved_action': action,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<int> getUnresolvedAlertsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM alerts WHERE is_resolved = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ================= APP CONTROLS =================
  Future<AppControl> insertAppControl(AppControl control) async {
    final db = await instance.database;
    await db.insert('app_controls', control.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return control;
  }

  Future<List<AppControl>> getAppControlsForChild(String childId) async {
    final db = await instance.database;
    final maps = await db.query(
      'app_controls',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'app_name ASC',
    );
    return maps.map((map) => AppControl.fromMap(map)).toList();
  }

  Future<int> updateAppControl(AppControl control) async {
    final db = await instance.database;
    return db.update(
      'app_controls',
      control.toMap(),
      where: 'id = ?',
      whereArgs: [control.id],
    );
  }

  Future<int> deleteAppControl(String id) async {
    final db = await instance.database;
    return await db.delete(
      'app_controls',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================= SETTINGS =================
  Future<KovaSettings> upsertSettings(KovaSettings settings) async {
    final db = await instance.database;
    await db.insert('settings', settings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return settings;
  }

  Future<KovaSettings?> getSettings() async {
    final db = await instance.database;
    final maps = await db.query('settings', limit: 1);
    if (maps.isNotEmpty) {
      return KovaSettings.fromMap(maps.first);
    }
    return null;
  }
}
