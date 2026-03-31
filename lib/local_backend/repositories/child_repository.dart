// local_backend/repositories/child_repository.dart — Child CRUD operations
import 'package:uuid/uuid.dart';
import 'dart:math';

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

  /// Get all children linked to this device
  Future<List<ChildModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('children', orderBy: 'created_at DESC');
    return rows.map(ChildModel.fromMap).toList();
  }

  /// Get all unlinked children (pending connection)
  Future<List<ChildModel>> getAllUnlinked() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'children',
      where: 'linked = 0 AND pair_code_exp > ?',
      whereArgs: [now],
      orderBy: 'created_at DESC',
    );
    return rows.map(ChildModel.fromMap).toList();
  }

  /// Get a specific child by ID
  /// Generate 8 deterministic 6-digit pairing codes based on child ID
  /// This ensures both parent and child generate the same codes
  List<String> generatePairingCodes(String childId) {
    final random = Random(childId.hashCode); // Seed with child ID for determinism
    final codes = <String>{};
    while (codes.length < 8) {
      // Generate 6-digit code (000000 to 999999)
      final code = random.nextInt(1000000).toString().padLeft(6, '0');
      codes.add(code);
    }
    return codes.toList();
  }

  /// Validate if a 6-digit code matches any of the 8 valid codes for this child
  Future<bool> validatePairingCode(String childId, String code) async {
    final validCodes = generatePairingCodes(childId);
    return validCodes.contains(code);
  }

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

  /// Create a new child and generate a pairing code
  /// Returns the child ID
  Future<String> create(String name, {int age = 10, String? avatarPath}) async {
    final db = await _db.database;
    final id = const Uuid().v4();
    final code = _generateCode();
    final expiration = DateTime.now()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    await db.insert('children', {
      'id': id,
      'name': name,
      'age': age,
      'avatar_path': avatarPath,
      'pair_code': code,
      'pair_code_exp': expiration,
      'linked': 0,
      'score': 100,
    });

    return id;
  }

  /// Get a child by their pairing code (if still valid)
  /// Used during child setup when entering the code
  /// Now validates against all 8 generated pairing codes
  Future<ChildModel?> getByCode(String code) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Get all unlinked children
    final rows = await db.query(
      'children',
      where: 'linked = 0 AND pair_code_exp > ?',
      whereArgs: [now],
    );
    
    // Check if code matches any of the 8 generated codes for each child
    for (final row in rows) {
      final child = ChildModel.fromMap(row);
      final validCodes = generatePairingCodes(child.id);
      if (validCodes.contains(code)) {
        return child;
      }
    }
    
    return null;
  }

  /// Mark a child as linked (code accepted, setup complete)
  /// Clear the pairing code so it can't be reused
  Future<void> markLinked(String id) async {
    final db = await _db.database;
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

  /// Update child's safety score
  /// Score is clamped to 0-100
  Future<int> updateScore(String id, int delta) async {
    final db = await _db.database;

    // Get current score
    final rows = await db.query('children', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return 100;

    final currentScore = rows.first['score'] as int? ?? 100;
    final newScore = (currentScore + delta).clamp(0, 100);

    // Update score
    await db.update(
      'children',
      {'score': newScore},
      where: 'id = ?',
      whereArgs: [id],
    );

    // Record in score history
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

  /// Delete a child and all associated alerts
  Future<void> delete(String id) async {
    final db = await _db.database;
    await _db.reset(); // Also reset global state if needed, but repository specific:
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

  /// Generate a random 6-digit pairing code
  String _generateCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10).toString()).join();
  }
}
