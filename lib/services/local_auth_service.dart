// services/local_auth_service.dart — Offline authentication via SQLite
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:kova/models/parent.dart';
import 'package:kova/services/database_helper.dart';

class LocalAuthService {
  final _db = DatabaseHelper.instance;
  final _storage = const FlutterSecureStorage();
  static const _uuid = Uuid();

  // Singleton
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  String? _parentId;
  String? _parentName;

  String? get parentId => _parentId;
  String? get parentName => _parentName;

  /// Initialize from secure storage (call once at app start)
  Future<void> init() async {
    _parentId = await _storage.read(key: 'parent_id');
    _parentName = await _storage.read(key: 'parent_name');
  }

  /// Whether a parent is currently logged in
  Future<bool> get isLoggedIn async {
    if (_parentId == null) await init();
    return _parentId != null;
  }

  /// Register a new parent
  Future<bool> register(String name, String phone, String pin) async {
    try {
      final db = await _db.database;

      // Check if phone already exists
      final existing = await db.query(
        'parents',
        where: 'phone = ?',
        whereArgs: [phone],
      );
      if (existing.isNotEmpty) return false;

      final id = _uuid.v4();
      final salt = _generateSalt();
      final hash = _hashPin(pin, salt);

      await db.insert('parents', {
        'id': id,
        'name': name,
        'phone': phone,
        'pin_hash': hash,
        'pin_salt': salt,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Store session
      _parentId = id;
      _parentName = name;
      await _storage.write(key: 'parent_id', value: id);
      await _storage.write(key: 'parent_name', value: name);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Registration error: $e');
      return false;
    }
  }

  /// Login with phone + PIN
  Future<bool> login(String phone, String pin) async {
    try {
      final db = await _db.database;

      final results = await db.query(
        'parents',
        where: 'phone = ?',
        whereArgs: [phone],
      );

      if (results.isEmpty) return false;

      final parent = Parent.fromMap(results.first);
      final hash = _hashPin(pin, parent.pinSalt);

      if (hash != parent.pinHash) return false;

      // Store session
      _parentId = parent.id;
      _parentName = parent.name;
      await _storage.write(key: 'parent_id', value: parent.id);
      await _storage.write(key: 'parent_name', value: parent.name);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Login error: $e');
      return false;
    }
  }

  /// Verify PIN for current parent
  Future<bool> verifyPin(String pin) async {
    try {
      if (_parentId == null) return false;

      final db = await _db.database;
      final results = await db.query(
        'parents',
        where: 'id = ?',
        whereArgs: [_parentId],
      );

      if (results.isEmpty) return false;

      final parent = Parent.fromMap(results.first);
      final hash = _hashPin(pin, parent.pinSalt);

      return hash == parent.pinHash;
    } catch (e) {
      // ignore: avoid_print
      print('PIN verification error: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _parentId = null;
    _parentName = null;
    await _storage.delete(key: 'parent_id');
    await _storage.delete(key: 'parent_name');
    await _storage.delete(key: 'active_child_id');
  }

  /// Get parent ID from secure storage
  Future<String?> getParentId() async {
    _parentId ??= await _storage.read(key: 'parent_id');
    return _parentId;
  }

  /// Get parent name from secure storage
  Future<String?> getParentName() async {
    _parentName ??= await _storage.read(key: 'parent_name');
    return _parentName;
  }

  /// Auto-login the first registered parent (post-onboarding flow)
  Future<void> autoLogin() async {
    try {
      final db = await _db.database;
      final results = await db.query('parents', limit: 1);
      if (results.isEmpty) return;

      final parent = Parent.fromMap(results.first);
      _parentId = parent.id;
      _parentName = parent.name;
      await _storage.write(key: 'parent_id', value: parent.id);
      await _storage.write(key: 'parent_name', value: parent.name);
    } catch (e) {
      // ignore: avoid_print
      print('Auto-login error: $e');
    }
  }

  // ── Crypto helpers ──

  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
