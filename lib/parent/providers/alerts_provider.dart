// parent/providers/alerts_provider.dart — State for alerts
import 'package:flutter/foundation.dart';

import 'package:kova/local_backend/repositories/alert_repository.dart';

class AlertsProvider extends ChangeNotifier {
  final _repo = AlertRepository();

  List<AlertModel> _alerts = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;
  String? _currentFilter; // 'all', 'unread', 'critical'

  // Getters
  List<AlertModel> get alerts => _alerts;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  String? get error => _error;
  String? get currentFilter => _currentFilter;

  /// Load alerts with optional filters
  Future<void> loadAlerts({
    String? childId,
    bool? read,
    String? severity,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _alerts = await _repo.getAll(
        childId: childId,
        read: read,
        severity: severity,
        limit: 100,
      );
    } catch (e) {
      _error = 'Erreur lors du chargement des alertes: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Load unread count
  Future<void> loadUnreadCount({String? childId}) async {
    try {
      _unreadCount = await _repo.getUnreadCount(childId);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du comptage: $e';
      notifyListeners();
    }
  }

  /// Apply filter
  Future<void> applyFilter(String filter, {String? childId}) async {
    _currentFilter = filter;
    _loading = true;
    notifyListeners();

    try {
      switch (filter) {
        case 'unread':
          await loadAlerts(childId: childId, read: false);
          break;
        case 'critical':
          await loadAlerts(childId: childId, severity: 'critical');
          break;
        default:
          await loadAlerts(childId: childId);
      }
    } catch (e) {
      _error = 'Erreur lors de l\'application du filtre: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Mark alert as read
  Future<void> markRead(String alertId) async {
    try {
      await _repo.markRead(alertId);
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx >= 0) {
        _alerts[idx] = _alerts[idx].copyWith(read: true);
        _unreadCount = (_unreadCount - 1).clamp(0, 99999);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Resolve alert
  Future<void> resolveAlert(String alertId) async {
    try {
      await _repo.resolve(alertId);
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx >= 0) {
        _alerts[idx] = _alerts[idx].copyWith(resolved: true);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Delete alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _repo.delete(alertId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
    }
  }

  /// Get alert by ID
  AlertModel? getAlert(String alertId) {
    try {
      return _alerts.firstWhere((a) => a.id == alertId);
    } catch (_) {
      return null;
    }
  }

  /// Refresh alerts
  Future<void> refresh({String? childId}) async {
    await loadAlerts(childId: childId);
    await loadUnreadCount(childId: childId);
  }
}
