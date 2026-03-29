// local_backend/database/database_service.dart — SQLite initialization & management
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton service that manages the SQLite database
/// All database operations go through this service
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  factory DatabaseService() => _instance;

  /// Get or initialize the database
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database file and create tables
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'kova_local.db');
    return openDatabase(path, version: 1, onCreate: _createTables);
  }

  /// Create all tables on first run
  Future<void> _createTables(Database db, int version) async {
    // ── Config Table ──
    // Stores app-level configuration
    await db.execute('''
      CREATE TABLE IF NOT EXISTS config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ── Children Table ──
    // Stores child profiles (for parent mode) or child identity (for child mode)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS children (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        pair_code       TEXT,
        pair_code_exp   INTEGER,
        linked          INTEGER DEFAULT 0,
        score           INTEGER DEFAULT 100,
        app_whatsapp    INTEGER DEFAULT 1,
        app_tiktok      INTEGER DEFAULT 1,
        app_facebook    INTEGER DEFAULT 1,
        app_instagram   INTEGER DEFAULT 1,
        app_sms         INTEGER DEFAULT 1,
        created_at      INTEGER DEFAULT (strftime('%s','now'))
      )
    ''');

    // ── Alerts Table ──
    // Stores detected incidents (inappropriate content, suspicious contacts, etc.)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alerts (
        id              TEXT PRIMARY KEY,
        child_id        TEXT NOT NULL,
        app             TEXT NOT NULL,
        type            TEXT NOT NULL,
        severity        TEXT NOT NULL,
        score_text      REAL DEFAULT 0.0,
        score_image     REAL DEFAULT 0.0,
        score_grooming  REAL DEFAULT 0.0,
        read            INTEGER DEFAULT 0,
        resolved        INTEGER DEFAULT 0,
        created_at      INTEGER DEFAULT (strftime('%s','now')),
        FOREIGN KEY(child_id) REFERENCES children(id)
      )
    ''');

    // ── Score History Table ──
    // Tracks changes to child safety score over time
    await db.execute('''
      CREATE TABLE IF NOT EXISTS score_history (
        id              TEXT PRIMARY KEY,
        child_id        TEXT NOT NULL,
        delta           INTEGER NOT NULL,
        reason          TEXT NOT NULL,
        score_after     INTEGER NOT NULL,
        created_at      INTEGER DEFAULT (strftime('%s','now')),
        FOREIGN KEY(child_id) REFERENCES children(id)
      )
    ''');

    // ── App Controls Table ──
    // Stores per-app monitoring settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_controls (
        id              TEXT PRIMARY KEY,
        child_id        TEXT NOT NULL,
        app_name        TEXT NOT NULL,
        monitoring_enabled INTEGER DEFAULT 1,
        block_enabled   INTEGER DEFAULT 0,
        created_at      INTEGER DEFAULT (strftime('%s','now')),
        FOREIGN KEY(child_id) REFERENCES children(id)
      )
    ''');

    // ── Pending Sync Table ──
    // Stores alerts waiting to sync to parent device (when on same WiFi)
    // Not used in MVP (no WiFi sync) but kept for future
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id              TEXT PRIMARY KEY,
        type            TEXT NOT NULL,
        payload         TEXT NOT NULL,
        created_at      INTEGER DEFAULT (strftime('%s','now'))
      )
    ''');
  }

  /// Close the database
  Future<void> close() async {
    _database?.close();
    _database = null;
  }

  /// Reset the entire database (dangerous — use with caution)
  Future<void> reset() async {
    final db = await database;
    await db.execute('DELETE FROM pending_sync');
    await db.execute('DELETE FROM score_history');
    await db.execute('DELETE FROM app_controls');
    await db.execute('DELETE FROM alerts');
    await db.execute('DELETE FROM children');
    await db.execute('DELETE FROM config');
  }
}
