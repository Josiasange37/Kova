// providers/app_state.dart — Central state management for KOVA (bridges old screens to new repositories)
import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/models/alert.dart';
import 'package:kova/models/app_control.dart';
import 'package:kova/models/child_profile.dart';
import 'package:kova/models/dashboard.dart';
import 'package:kova/models/settings.dart';
import 'package:uuid/uuid.dart';

class AppState extends ChangeNotifier {
  final _childRepo = ChildRepository();
  final _alertRepo = AlertRepository();

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
    _isLoggedIn = LocalStorage.getAppMode() == 'parent';
    _parentId = LocalStorage.getChildId(); // Placeholder for parent ID

    if (_isLoggedIn) {
      await _loadData();
    }

    notifyListeners();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load children from repository
      final childModels = await _childRepo.getAll();
      final now = DateTime.now();

      _children = childModels
          .map(
            (m) => ChildProfile(
              id: m.id,
              parentId: _parentId ?? '',
              name: m.name,
              age: 10, // Placeholder age
              safetyScore: 95,
              isOnline: m.linked,
              deviceId: null,
              lastSeen: now,
              createdAt: m.createdAt,
            ),
          )
          .toList();

      // Active child
      _activeChildId = LocalStorage.getChildId();
      if (_activeChildId == null && _children.isNotEmpty) {
        _activeChildId = _children.first.id;
        await LocalStorage.setChildId(_activeChildId!);
      }

      // Load dashboard + alerts + apps for active child
      if (_activeChildId != null) {
        await _refreshChildData();
      }

      // Load settings
      _settings = KovaSettings(
        id: _parentId ?? const Uuid().v4(),
        parentId: _parentId ?? '',
        notificationsEnabled: LocalStorage.getNotificationsEnabled(),
        alertSound: LocalStorage.getAlertSoundEnabled(),
        autoBlock: false,
        sensitivityLevel: LocalStorage.getSensitivityLevel(),
        dailyReport: true,
        screenTimeLimit: 120,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshChildData() async {
    if (_activeChildId == null) return;

    // Load alerts
    final alertModels = await _alertRepo.getAll(childId: _activeChildId!);
    _alerts = alertModels
        .map(
          (m) => Alert(
            id: m.id,
            childId: m.childId,
            appName: m.app,
            alertType: m.type,
            severity: m.severity,
            contentPreview: null,
            aiConfidence: m.scoreText,
            isResolved: m.resolved,
            createdAt: m.createdAt,
          ),
        )
        .toList();

    // Load monitored apps (placeholder for now)
    _monitoredApps = [
      AppControl(
        id: 'whatsapp',
        childId: _activeChildId!,
        appName: 'WhatsApp',
        category: 'messaging',
        sensitivity: 'normal',
        isMonitored: true,
        isBlocked: false,
        createdAt: DateTime.now(),
      ),
      AppControl(
        id: 'instagram',
        childId: _activeChildId!,
        appName: 'Instagram',
        category: 'social',
        sensitivity: 'normal',
        isMonitored: true,
        isBlocked: false,
        createdAt: DateTime.now(),
      ),
      AppControl(
        id: 'tiktok',
        childId: _activeChildId!,
        appName: 'TikTok',
        category: 'social',
        sensitivity: 'high',
        isMonitored: true,
        isBlocked: false,
        createdAt: DateTime.now(),
      ),
    ];

    // Dashboard
    final activeChild = _children.firstWhere((c) => c.id == _activeChildId!);
    _dashboard = DashboardData(
      child: DashboardChild(
        id: activeChild.id,
        name: activeChild.name,
        age: activeChild.age,
        isOnline: activeChild.isOnline,
        lastSeen: activeChild.lastSeen,
      ),
      safetyScore: activeChild.safetyScore,
      alertCount: _alerts.length,
      criticalCount: _alerts.where((a) => a.isCritical).length,
      hasAlerts: _alerts.isNotEmpty,
      monitoredApps: _monitoredApps,
      recentAlerts: _alerts.take(5).toList(),
    );
  }

  // ═══════════════════════════════════════════════
  // ──  Auth Actions
  // ═══════════════════════════════════════════════

  Future<bool> register(String name, String phone, String pin) async {
    try {
      _isLoggedIn = true;
      _parentId = const Uuid().v4();
      _parentName = name;
      await LocalStorage.setAppMode('parent');
      await _loadData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error registering: $e');
      return false;
    }
  }

  Future<bool> login(String phone, String pin) async {
    try {
      _isLoggedIn = true;
      _parentId ??= const Uuid().v4();
      await LocalStorage.setAppMode('parent');
      await _loadData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    // Placeholder: always return true for now
    return true;
  }

  /// Mark as logged in after onboarding
  Future<void> markLoggedIn() async {
    _isLoggedIn = true;
    await LocalStorage.setAppMode('parent');
    if (_isLoggedIn && _parentId != null) {
      await _loadData();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _parentId = null;
    _parentName = null;
    _children = [];
    _activeChildId = null;
    _dashboard = null;
    _alerts = [];
    _monitoredApps = [];
    _settings = null;
    await LocalStorage.setAppMode('');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Child Actions
  // ═══════════════════════════════════════════════

  Future<ChildProfile?> addChild(String name, int age) async {
    if (_parentId == null) return null;

    try {
      final childId = await _childRepo.create(name);
      if (childId.isNotEmpty) {
        final childModels = await _childRepo.getAll();
        final now = DateTime.now();

        _children = childModels
            .map(
              (m) => ChildProfile(
                id: m.id,
                parentId: _parentId ?? '',
                name: m.name,
                age: age,
                safetyScore: 95,
                isOnline: m.linked,
                deviceId: null,
                lastSeen: now,
                createdAt: m.createdAt,
              ),
            )
            .toList();

        _activeChildId = childId;
        await LocalStorage.setChildId(childId);
        await _refreshChildData();
        notifyListeners();

        return ChildProfile(
          id: childId,
          parentId: _parentId!,
          name: name,
          age: age,
          safetyScore: 95,
          isOnline: false,
          deviceId: null,
          lastSeen: null,
          createdAt: now,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error adding child: $e');
      return null;
    }
  }

  Future<void> switchChild(String childId) async {
    _activeChildId = childId;
    await LocalStorage.setChildId(childId);
    await _refreshChildData();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Dashboard
  // ═══════════════════════════════════════════════

  Future<void> refreshDashboard() async {
    if (_activeChildId == null) return;
    await _refreshChildData();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // ──  Alert Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshAlerts() async {
    if (_activeChildId == null) return;
    await _refreshChildData();
    notifyListeners();
  }

  Future<bool> resolveAlert(String alertId, String action) async {
    try {
      await _alertRepo.resolve(alertId);
      await refreshAlerts();
      await refreshDashboard();
      return true;
    } catch (e) {
      debugPrint('Error resolving alert: $e');
      return false;
    }
  }

  Future<Alert?> getAlert(String alertId) async {
    try {
      final alertModel = await _alertRepo.getById(alertId);
      if (alertModel != null) {
        return Alert(
          id: alertModel.id,
          childId: alertModel.childId,
          appName: alertModel.app,
          alertType: alertModel.type,
          severity: alertModel.severity,
          contentPreview: null,
          aiConfidence: alertModel.scoreText,
          isResolved: alertModel.resolved,
          createdAt: alertModel.createdAt,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting alert: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  App Control Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshApps() async {
    if (_activeChildId == null) return;
    // Placeholder: apps are loaded in _refreshChildData
    notifyListeners();
  }

  Future<bool> updateAppControl(
    String appId, {
    String? sensitivity,
    bool? isBlocked,
    bool? isMonitored,
  }) async {
    try {
      // Placeholder: update app control in repository
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating app control: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  Settings Actions
  // ═══════════════════════════════════════════════

  Future<void> refreshSettings() async {
    if (_parentId == null) return;
    if (_settings != null) {
      notifyListeners();
    }
  }

  Future<bool> updateSettings(KovaSettings updated) async {
    try {
      _settings = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating settings: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // ──  Pairing
  // ═══════════════════════════════════════════════

  Future<String?> generatePairingCode() async {
    if (_activeChildId == null) return null;
    try {
      // Get the child to retrieve their pairing code
      final child = await _childRepo.getById(_activeChildId!);
      return child?.pairCode;
    } catch (e) {
      debugPrint('Error getting pairing code: $e');
      return null;
    }
  }
}
