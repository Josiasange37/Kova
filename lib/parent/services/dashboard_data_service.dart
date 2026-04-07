// parent/services/dashboard_data_service.dart — Dashboard data provider
// Provides real data from repositories + remote alerts from network

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/models/network_alert.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/shared/services/network_sync_service.dart';
import 'package:kova/shared/services/notification_service.dart';

// Re-export ChildModel for consumers of this service
export 'package:kova/local_backend/repositories/child_repository.dart' show ChildModel;

class DashboardDataService extends ChangeNotifier {
  final _childRepo = ChildRepository();
  final _alertRepo = AlertRepository();
  final _networkSync = NetworkSyncService();

  StreamSubscription? _alertSub;
  StreamSubscription? _connectionSub;

  List<ChildModel>? _children;
  List<AlertModel>? _alerts;
  String? _parentName;
  String? _activeChildId;
  bool _loading = false;
  String? _error;
  NetworkConnectionState _connectionState = NetworkConnectionState.none;

  // Getters matching what DashboardScreen expects
  List<ChildModel>? get children => _children;
  List<AlertModel>? get alerts => _alerts;
  String? get parentName => _parentName ?? 'Parent';
  bool get loading => _loading;
  String? get error => _error;
  NetworkConnectionState get connectionState => _connectionState;
  bool get isLanConnected => _connectionState == NetworkConnectionState.lan;
  bool get isInternetConnected => _connectionState == NetworkConnectionState.internet;

  // Active child (use stored active child or first child)
  ChildModel? get activeChild {
    if (_children == null || _children!.isEmpty) return null;
    if (_activeChildId != null) {
      try {
        return _children!.firstWhere((c) => c.id == _activeChildId);
      } catch (_) {
        return _children!.first;
      }
    }
    return _children!.first;
  }

  // Dashboard metrics
  int get alertCount => _alerts?.where((a) => !a.read).length ?? 0;

  int get safetyScore {
    if (_children == null || _children!.isEmpty) return 100;
    final scores = _children!.map((c) => c.score).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    return avgScore.toInt();
  }

  bool get hasAlerts => alertCount > 0;

  /// Initialize and start listening for remote alerts
  void startListening() {
    // Listen for alerts from network (both LAN and Vercel relay)
    _alertSub = _networkSync.onAlertReceived.listen(_handleRemoteAlert);

    // Listen for connection state changes
    _connectionSub = _networkSync.onConnectionStateChanged.listen((state) {
      _connectionState = state;
      notifyListeners();
      if (kDebugMode) debugPrint('🌐 Dashboard connection: ${state.name}');
    });
  }

  /// Handle an alert received from a remote child device
  Future<void> _handleRemoteAlert(NetworkAlertSummary alert) async {
    try {
      // Find the child this alert belongs to
      final child = activeChild;
      if (child == null) return;

      // Save alert to local database
      final alertId = await _alertRepo.create(
        childId: child.id,
        app: alert.app,
        type: alert.alertType,
        severity: alert.severity,
        scoreText: alert is NetworkAlertFull ? alert.scoreText : 0.0,
        scoreImage: alert is NetworkAlertFull ? alert.scoreImage : 0.0,
        scoreGrooming: alert is NetworkAlertFull ? alert.scoreGrooming : 0.0,
      );

      // Show notification
      final isLan = _connectionState == NetworkConnectionState.lan;
      final title = isLan
          ? '🚨 Alert: ${alert.alertType}'
          : '⚠️ ${alert.severity.toUpperCase()} Alert';
      final body = isLan && alert is NetworkAlertFull
          ? '${alert.app}: ${alert.contentPreview ?? alert.alertType}'
          : '${alert.app} — ${alert.alertType}';

      await NotificationService.showAlert(title, body);

      // Refresh dashboard data
      await loadDashboardData();

      if (kDebugMode) {
        debugPrint('📥 Remote alert saved: $alertId (via ${isLan ? "LAN" : "internet"})');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to process remote alert: $e');
    }
  }

  // Load all dashboard data
  Future<void> loadDashboardData() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Load children from repository
      _children = await _childRepo.getAll();

      // Load alerts from repository
      _alerts = await _alertRepo.getAll();

      // Load parent name from local storage
      _parentName = LocalStorage.getString('parent_name');

      _error = null;
    } catch (e) {
      _error = 'Error loading dashboard: $e';
      debugPrint(_error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Refresh dashboard data
  Future<void> refresh() => loadDashboardData();

  // Update parent name
  Future<void> updateParentName(String name) async {
    await LocalStorage.setString('parent_name', name);
    _parentName = name;
    notifyListeners();
  }

  // Update child profile (name and age)
  Future<void> updateChildProfile(String childId, String name, int age) async {
    await _childRepo.updateName(childId, name);
    await _childRepo.updateAge(childId, age);
    // Reload to reflect changes
    await loadDashboardData();
  }

  // Delete a child and all associated data
  Future<void> deleteChild(String childId) async {
    await _childRepo.delete(childId);
    // If deleted child was active, clear the active child
    if (_activeChildId == childId) {
      _activeChildId = null;
      await LocalStorage.remove('child_id');
    }
    // Reload to reflect changes
    await loadDashboardData();
  }

  // Update active child
  Future<void> setActiveChild(String childId) async {
    _activeChildId = childId;
    await LocalStorage.setChildId(childId);
    notifyListeners();
  }

  // Get child by ID
  ChildModel? getChildById(String id) {
    if (_children == null) return null;
    try {
      return _children!.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}
