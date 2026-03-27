// providers/app_state.dart — Central state management for KOVA
import 'package:flutter/foundation.dart';
import 'package:kova/models/alert.dart';
import 'package:kova/models/app_control.dart';
import 'package:kova/models/child_profile.dart';
import 'package:kova/models/dashboard.dart';
import 'package:kova/models/settings.dart';
import 'package:kova/services/local_auth_service.dart';
import 'package:kova/services/local_data_service.dart';

class AppState extends ChangeNotifier {
  final _auth = LocalAuthService();
  final _data = LocalDataService();

  // ── Auth state ──
  bool _isLoggedIn = false;
  String? _parentId;
  String? _parentName;

  // ── Data state ──
  List<ChildProfile> _children = [];
  String? _activeChildId;
  DashboardData? _dashboard;
  List<Alert> _alerts = [];
  List<AppControl> _monitoredApps = [];
  KovaSettings? _settings;
  bool _isLoading = false;

  // ── Getters ──
  bool get isLoggedIn => _isLoggedIn;
  String? get parentId => _parentId;
  String? get parentName => _parentName;
  List<ChildProfile> get children => _children;
  String? get activeChildId => _activeChildId;
  DashboardData? get dashboard => _dashboard;
  List<Alert> get alerts => _alerts;
  List<AppControl> get monitoredApps => _monitoredApps;
  KovaSettings? get settings => _settings;
  bool get isLoading => _isLoading;

  ChildProfile? get activeChild {
    if (_activeChildId == null || _children.isEmpty) return null;
    try {
      return _children.firstWhere((c) => c.id == _activeChildId);
    } catch (_) {
      return _children.isNotEmpty ? _children.first : null;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  Initialization
  // ═══════════════════════════════════════════════

  /// Initialize state from storage — call once on app start
  Future<void> init() async {
    await _auth.init();
    _isLoggedIn = await _auth.isLoggedIn;
    _parentId = _auth.parentId;
    _parentName = _auth.parentName;

    if (_isLoggedIn && _parentId != null) {
      await _loadData();
    }

    notifyListeners();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load children
      _children = await _data.getChildren(_parentId!);

      // Active child
      _activeChildId = await _data.getActiveChildId(_parentId!);
      if (_activeChildId == null && _children.isNotEmpty) {
        _activeChildId = _children.first.id;
        await _data.setActiveChildId(_activeChildId!);
      }

      // Load dashboard + alerts + apps for active child
      if (_activeChildId != null) {
        await _refreshChildData();
      }

      // Settings
      _settings = await _data.ensureSettings(_parentId!);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshChildData() async {
    if (_activeChildId == null) return;
    _dashboard = await _data.getDashboardData(_activeChildId!);
    _alerts = await _data.getAlerts(childId: _activeChildId!);
    _monitoredApps = await _data.getMonitoredApps(_activeChildId!);
  }

  // ═══════════════════════════════════════════════
  // ──  Auth Actions
  // ═══════════════════════════════════════════════

  Future<bool> register(String name, String phone, String pin) async {
    final success = await _auth.register(name, phone, pin);
    if (success) {
      _isLoggedIn = true;
      _parentId = _auth.parentId;
      _parentName = _auth.parentName;
      await _loadData();
    }
    return success;
  }

  Future<bool> login(String phone, String pin) async {
    final success = await _auth.login(phone, pin);
    if (success) {
      _isLoggedIn = true;
      _parentId = _auth.parentId;
      _parentName = _auth.parentName;
      await _loadData();
    }
    return success;
  }

  Future<bool> verifyPin(String pin) => _auth.verifyPin(pin);

  /// Mark as logged in after onboarding — uses the first registered parent
  Future<void> markLoggedIn() async {
    await _auth.autoLogin();
    _isLoggedIn = await _auth.isLoggedIn;
    _parentId = _auth.parentId;
    _parentName = _auth.parentName;
    if (_isLoggedIn && _parentId != null) {
      await _loadData();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _isLoggedIn = false;
    _parentId = null;
    _parentName = null;
    _children = [];
    _activeChildId = null;
    _dashboard = null;
    _alerts = [];
    _monitoredApps = [];
    _settings = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Child Actions
  // ═══════════════════════════════════════════════

  Future<ChildProfile?> addChild(String name, int age) async {
    if (_parentId == null) return null;
    final child = await _data.addChild(_parentId!, name, age);
    if (child != null) {
      _children = await _data.getChildren(_parentId!);
      _activeChildId = child.id;
      await _data.setActiveChildId(child.id);
      await _refreshChildData();
      notifyListeners();
    }
    return child;
  }

  Future<void> switchChild(String childId) async {
    _activeChildId = childId;
    await _data.setActiveChildId(childId);
    await _refreshChildData();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Dashboard
  // ═══════════════════════════════════════════════

  Future<void> refreshDashboard() async {
    if (_activeChildId == null) return;
    _dashboard = await _data.getDashboardData(_activeChildId!);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Alert Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshAlerts() async {
    if (_activeChildId == null) return;
    _alerts = await _data.getAlerts(childId: _activeChildId!);
    notifyListeners();
  }

  Future<bool> resolveAlert(String alertId, String action) async {
    final success = await _data.resolveAlert(alertId, action);
    if (success) {
      await refreshAlerts();
      await refreshDashboard();
    }
    return success;
  }

  Future<Alert?> getAlert(String alertId) => _data.getAlert(alertId);

  // ═══════════════════════════════════════════════
  // ──  App Control Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshApps() async {
    if (_activeChildId == null) return;
    _monitoredApps = await _data.getMonitoredApps(_activeChildId!);
    notifyListeners();
  }

  Future<bool> updateAppControl(
    String appId, {
    String? sensitivity,
    bool? isBlocked,
    bool? isMonitored,
  }) async {
    final success = await _data.updateAppControl(
      appId,
      sensitivity: sensitivity,
      isBlocked: isBlocked,
      isMonitored: isMonitored,
    );
    if (success) await refreshApps();
    return success;
  }

  // ═══════════════════════════════════════════════
  // ──  Settings Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshSettings() async {
    if (_parentId == null) return;
    _settings = await _data.getSettings(_parentId!);
    notifyListeners();
  }

  Future<bool> updateSettings(KovaSettings updated) async {
    final success = await _data.updateSettings(updated);
    if (success) {
      _settings = updated;
      notifyListeners();
    }
    return success;
  }

  // ═══════════════════════════════════════════════
  // ──  Pairing
  // ═══════════════════════════════════════════════

  Future<String?> generatePairingCode() async {
    if (_activeChildId == null) return null;
    return _data.generatePairingCode(_activeChildId!);
  }
}
