import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:3000/api/auth';
  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  String? get token => _token;

  Future<void> init() async {
    _token = await _storage.read(key: 'jwt_token');
  }

  Future<bool> get isLoggedIn async {
    if (_token == null) await init();
    return _token != null;
  }

  Future<bool> register(String name, String phone, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'phone': phone, 'pin': pin}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        await _storage.write(key: 'jwt_token', value: _token);
        
        // Store parent info
        if (data['parent'] != null) {
          await _storage.write(key: 'parent_id', value: data['parent']['id']);
          await _storage.write(key: 'parent_name', value: data['parent']['name']);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<bool> login(String phone, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        await _storage.write(key: 'jwt_token', value: _token);
        
        // Store parent info
        if (data['parent'] != null) {
          await _storage.write(key: 'parent_id', value: data['parent']['id']);
          await _storage.write(key: 'parent_name', value: data['parent']['name']);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/verify-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'pin': pin}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('PIN verification error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'parent_id');
    await _storage.delete(key: 'parent_name');
    await _storage.delete(key: 'active_child_id');
  }

  Future<String?> getParentId() async {
    return await _storage.read(key: 'parent_id');
  }
}
