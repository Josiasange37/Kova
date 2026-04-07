// local_backend/repositories/child_repository.dart — Child CRUD operations
import 'package:uuid/uuid.dart';

import '../database/database_service.dart';

/// Model for child data
class ChildModel {
  final String id;
  final String name;
  final int age;
  final String? avatarPath;
  final String? pairCode;
  final int? pairCodeExp;
  final bool linked;
  final int score;
  final Map<String, bool> appControls;
  final DateTime createdAt;

  ChildModel({
    required this.id,
    required this.name,
    this.age = 10,
    this.avatarPath,
    this.pairCode,
    this.pairCodeExp,
    required this.linked,
    required this.score,
    required this.appControls,
    required this.createdAt,
  });

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int? ?? 10,
      avatarPath: map['avatar_path'] as String?,
      pairCode: map['pair_code'] as String?,
      pairCodeExp: map['pair_code_exp'] as int?,
      linked: (map['linked'] as int? ?? 0) == 1,
      score: map['score'] as int? ?? 100,
      appControls: {
        'whatsapp': ((map['app_whatsapp'] ?? 1) as int) == 1,
        'tiktok': ((map['app_tiktok'] ?? 1) as int) == 1,
        'facebook': ((map['app_facebook'] ?? 1) as int) == 1,
        'instagram': ((map['app_instagram'] ?? 1) as int) == 1,
        'sms': ((map['app_sms'] ?? 1) as int) == 1,
      },
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'avatar_path': avatarPath,
    'pair_code': pairCode,
    'pair_code_exp': pairCodeExp,
    'linked': linked ? 1 : 0,
    'score': score,
    'app_whatsapp': (appControls['whatsapp'] ?? false) ? 1 : 0,
    'app_tiktok': (appControls['tiktok'] ?? false) ? 1 : 0,
    'app_facebook': (appControls['facebook'] ?? false) ? 1 : 0,
    'app_instagram': (appControls['instagram'] ?? false) ? 1 : 0,
    'app_sms': (appControls['sms'] ?? false) ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  ChildModel copyWith({
    String? id,
    String? name,
    int? age,
    String? avatarPath,
    String? pairCode,
    int? pairCodeExp,
    bool? linked,
    int? score,
    Map<String, bool>? appControls,
    DateTime? createdAt,
  }) {
    return ChildModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      avatarPath: avatarPath ?? this.avatarPath,
      pairCode: pairCode ?? this.pairCode,
      pairCodeExp: pairCodeExp ?? this.pairCodeExp,
      linked: linked ?? this.linked,
      score: score ?? this.score,
      appControls: appControls ?? this.appControls,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Repository for child operations
class ChildRepository {
  final _db = DatabaseService();

  // ─────────────────────────────────────────────
  // Pairing Code Pool (100 pre-registered codes)
  // ─────────────────────────────────────────────

  /// Pick a random unused code from the pre-registered pool
  /// and assign it to this child. Returns the 6-digit code.
  Future<String> assignPairingCode(String childId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // First release any previously assigned (but unused) code for this child
    await db.update(
      'pairing_codes',
      {'used': 0, 'child_id': null, 'assigned_at': null},
      where: 'child_id = ? AND used = 0',
      whereArgs: [childId],
    );

    // Pick a random unused code
    final rows = await db.query(
      'pairing_codes',
      where: 'used = 0 AND child_id IS NULL',
      orderBy: 'RANDOM()',
      limit: 1,
    );

    if (rows.isEmpty) {
      // All 100 codes are used — recycle oldest used codes
      await db.execute(
        'UPDATE pairing_codes SET used = 0, child_id = NULL, assigned_at = NULL, used_at = NULL '
        'WHERE rowid IN (SELECT rowid FROM pairing_codes WHERE used = 1 ORDER BY used_at ASC LIMIT 10)',
      );
      // Try again
      final recycled = await db.query(
        'pairing_codes',
        where: 'used = 0 AND child_id IS NULL',
        orderBy: 'RANDOM()',
        limit: 1,
      );
      if (recycled.isEmpty) throw Exception('No pairing codes available');
      final code = recycled.first['code'] as String;
      await db.update(
        'pairing_codes',
        {'child_id': childId, 'assigned_at': now},
        where: 'code = ?',
        whereArgs: [code],
      );
      // Also update the child record
      await db.update(
        'children',
        {'pair_code': code, 'pair_code_exp': now + 600000}, // 10 min
        where: 'id = ?',
        whereArgs: [childId],
      );
      return code;
    }

    final code = rows.first['code'] as String;

    // Mark code as assigned to this child
    await db.update(
      'pairing_codes',
      {'child_id': childId, 'assigned_at': now},
      where: 'code = ?',
      whereArgs: [code],
    );

    // Also store in the child record for quick lookup
    await db.update(
      'children',
      {'pair_code': code, 'pair_code_exp': now + 600000}, // expires in 10 min
      where: 'id = ?',
      whereArgs: [childId],
    );

    return code;
  }

  /// Verify a 6-digit code against the pre-registered pool.
  /// Returns the child ID if valid, null otherwise.
  Future<String?> verifyPairingCode(String code) async {
    final db = await _db.database;

    // Look up this code in the pool
    final rows = await db.query(
      'pairing_codes',
      where: 'code = ? AND child_id IS NOT NULL AND used = 0',
      whereArgs: [code],
    );

    if (rows.isEmpty) return null;

    final childId = rows.first['child_id'] as String?;
    if (childId == null) return null;

    // Verify the child exists and is unlinked
    final childRows = await db.query(
      'children',
      where: 'id = ? AND linked = 0',
      whereArgs: [childId],
    );
    if (childRows.isEmpty) return null;

    return childId;
  }

  /// Mark a pairing code as used (after successful connection)
  Future<void> markCodeUsed(String code) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'pairing_codes',
      {'used': 1, 'used_at': now},
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  /// Get all available (unused, unassigned) codes count
  Future<int> getAvailableCodesCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM pairing_codes WHERE used = 0 AND child_id IS NULL',
    );
    return result.first['cnt'] as int? ?? 0;
  }

  // ─────────────────────────────────────────────
  // Child CRUD
  // ─────────────────────────────────────────────

  /// Get all children
  Future<List<ChildModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('children', orderBy: 'created_at DESC');
    return rows.map(ChildModel.fromMap).toList();
  }

  /// Get all unlinked children (pending connection)
  Future<List<ChildModel>> getAllUnlinked() async {
    final db = await _db.database;
    final rows = await db.query(
      'children',
      where: 'linked = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(ChildModel.fromMap).toList();
  }

  /// Get a specific child by ID
  Future<ChildModel?> getById(String id) async {
    final db = await _db.database;
    final result = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ChildModel.fromMap(result.first);
  }

  /// Create a new child and assign a pairing code from the pool
  /// Returns the child ID
  Future<String> create(String name, {int age = 10, String? avatarPath}) async {
    final db = await _db.database;
    final id = const Uuid().v4();

    await db.insert('children', {
      'id': id,
      'name': name,
      'age': age,
      'avatar_path': avatarPath,
      'linked': 0,
      'score': 100,
    });

    // Assign a code from the pre-registered pool
    await assignPairingCode(id);

    return id;
  }

  /// Get a child by their pairing code
  /// Uses the pairing_codes table for verification
  Future<ChildModel?> getByCode(String code) async {
    final childId = await verifyPairingCode(code);
    if (childId == null) return null;
    return getById(childId);
  }

  /// Mark a child as linked (code accepted, setup complete)
  /// Also marks the pairing code as used
  Future<void> markLinked(String id) async {
    final db = await _db.database;

    // Get the child's current code to mark it used
    final child = await getById(id);
    if (child?.pairCode != null) {
      await markCodeUsed(child!.pairCode!);
    }

    await db.update(
      'children',
      {'linked': 1, 'pair_code': null, 'pair_code_exp': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update app control setting (enable/disable monitoring)
  Future<void> updateAppControl(String id, String app, bool enabled) async {
    final db = await _db.database;
    final column = 'app_${app.toLowerCase()}';
    await db.update(
      'children',
      {column: enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update child's safety score (clamped 0-100)
  Future<int> updateScore(String id, int delta) async {
    final db = await _db.database;

    final rows = await db.query('children', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return 100;

    final currentScore = rows.first['score'] as int? ?? 100;
    final newScore = (currentScore + delta).clamp(0, 100);

    await db.update(
      'children',
      {'score': newScore},
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.insert('score_history', {
      'id': const Uuid().v4(),
      'child_id': id,
      'delta': delta,
      'reason': 'alert_detected',
      'score_after': newScore,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return newScore;
  }

  /// Delete a child and release its pairing code
  Future<void> delete(String id) async {
    final db = await _db.database;

    // Release any assigned code back to pool
    await db.update(
      'pairing_codes',
      {'used': 0, 'child_id': null, 'assigned_at': null, 'used_at': null},
      where: 'child_id = ?',
      whereArgs: [id],
    );

    await db.transaction((txn) async {
      await txn.delete('alerts', where: 'child_id = ?', whereArgs: [id]);
      await txn.delete('score_history', where: 'child_id = ?', whereArgs: [id]);
      await txn.delete('app_controls', where: 'child_id = ?', whereArgs: [id]);
      await txn.delete('children', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Update child name
  Future<void> updateName(String id, String name) async {
    final db = await _db.database;
    await db.update('children', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  /// Update child age
  Future<void> updateAge(String id, int age) async {
    final db = await _db.database;
    await db.update('children', {'age': age}, where: 'id = ?', whereArgs: [id]);
  }
}
