import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kova/models/alert.dart';
import 'package:kova/models/app_control.dart';
import 'package:kova/models/child_profile.dart';
import 'package:kova/models/dashboard.dart';
import 'package:kova/models/settings.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  final _storage = const FlutterSecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper to get active child ID (in a real app, this would be selected by the user)
  Future<String?> getActiveChildId() async {
    String? childId = await _storage.read(key: 'active_child_id');
    if (childId == null) {
      // Fetch children and set the first one as active
      final children = await getChildren();
      if (children.isNotEmpty) {
        childId = children.first.id;
        await _storage.write(key: 'active_child_id', value: childId);
      }
    }
    return childId;
  }

  // --- Children API ---

  Future<List<ChildProfile>> getChildren() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/children'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChildProfile.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get children error: $e');
      return [];
    }
  }

  Future<ChildProfile?> addChild(String name, int age) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/children'),
        headers: headers,
        body: json.encode({'name': name, 'age': age}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final child = ChildProfile.fromJson(data['child']);

        // Save as active child if none exists
        final currentActive = await _storage.read(key: 'active_child_id');
        if (currentActive == null) {
          await _storage.write(key: 'active_child_id', value: child.id);
        }

        return child;
      }
      return null;
    } catch (e) {
      print('Add child error: $e');
      return null;
    }
  }

  // --- Pairing API ---

  Future<String?> generatePairingCode(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pairing/generate'),
        headers: headers,
        body: json.encode({'childId': childId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'];
      }
      return null;
    } catch (e) {
      print('Generate pairing code error: $e');
      return null;
    }
  }

  // --- Dashboard API ---

  Future<DashboardData?> getDashboardData(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/$childId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DashboardData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get dashboard error: $e');
      return null;
    }
  }

  // --- Alerts API ---

  Future<List<Alert>> getAlerts({
    String? childId,
    String? severity,
    bool? resolved,
  }) async {
    try {
      final headers = await _getHeaders();

      // Build query string
      final queryParams = <String>[];
      if (childId != null) queryParams.add('childId=$childId');
      if (severity != null) queryParams.add('severity=$severity');
      if (resolved != null) queryParams.add('resolved=$resolved');

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.join('&')}'
          : '';

      final response = await http.get(
        Uri.parse('$baseUrl/alerts$queryString'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Alert.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get alerts error: $e');
      return [];
    }
  }

  Future<Alert?> getAlertDetail(String alertId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/alerts/$alertId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Alert.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get alert detail error: $e');
      return null;
    }
  }

  Future<bool> resolveAlert(String alertId, String action) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/alerts/$alertId/action'),
        headers: headers,
        body: json.encode({'action': 'resolve', 'resolution': action}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Resolve alert error: $e');
      return false;
    }
  }

  // --- Apps API ---

  Future<List<AppControl>> getMonitoredApps(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/apps/$childId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AppControl.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get apps error: $e');
      return [];
    }
  }

  Future<bool> updateAppControl(
    String appId, {
    String? sensitivity,
    bool? isBlocked,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (sensitivity != null) body['sensitivity'] = sensitivity;
      if (isBlocked != null) body['isBlocked'] = isBlocked;

      final response = await http.put(
        Uri.parse('$baseUrl/apps/$appId/control'),
        headers: headers,
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update app control error: $e');
      return false;
    }
  }

  // --- Settings API ---

  Future<KovaSettings?> getSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return KovaSettings.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get settings error: $e');
      return null;
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
        body: json.encode(settings),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update settings error: $e');
      return false;
    }
  }
}
