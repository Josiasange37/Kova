// parent/services/alert_history_service.dart — Alert history with filtering
// Provides filtered alerts to AlertHistoryScreen

import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/models/alert_model.dart';

class AlertHistoryService extends ChangeNotifier {
  final _alertRepo = AlertRepository();

  List<AlertModel> _allAlerts = [];
  List<AlertModel> _filteredAlerts = [];

  // Filter state
  String _selectedApp = 'All';
  String _selectedTime = 'all';
  String _selectedStatus = 'all';

  bool _loading = false;
  String? _error;

  // Getters
  List<AlertModel> get allAlerts => _allAlerts;
  List<AlertModel> get filteredAlerts => _filteredAlerts;
  bool get loading => _loading;
  String? get error => _error;

  String get selectedApp => _selectedApp;
  String get selectedTime => _selectedTime;
  String get selectedStatus => _selectedStatus;

  // Stats from filtered alerts
  int get totalAlerts => _filteredAlerts.length;

  int get blocksCount => _filteredAlerts
      .where((a) => a.resolved && a.type.toLowerCase().contains('block'))
      .length;

  double get avgScore {
    if (_filteredAlerts.isEmpty) return 0.0;
    final total = _filteredAlerts
        .map((a) => (a.scoreText + a.scoreImage + a.scoreGrooming) / 3)
        .reduce((a, b) => a + b);
    return (total / _filteredAlerts.length * 100);
  }

  // Load all alerts
  Future<void> loadAlerts() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _allAlerts = await _alertRepo.getAll();
      _applyFilters();
      _error = null;
    } catch (e) {
      _error = 'Error loading alerts: $e';
      print(_error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Set app filter
  void setAppFilter(String app) {
    _selectedApp = app;
    _applyFilters();
  }

  // Set time filter
  void setTimeFilter(String time) {
    _selectedTime = time;
    _applyFilters();
  }

  // Set status filter
  void setStatusFilter(String status) {
    _selectedStatus = status;
    _applyFilters();
  }

  // Apply all filters
  void _applyFilters() {
    _filteredAlerts = _allAlerts.where((alert) {
      // App filter
      if (_selectedApp != 'All' && alert.app != _selectedApp.toLowerCase()) {
        return false;
      }

      // Time filter
      if (_selectedTime != 'all') {
        final now = DateTime.now();
        final alertTime = alert.createdAt;

        switch (_selectedTime) {
          case 'today':
            if (alertTime.day != now.day ||
                alertTime.month != now.month ||
                alertTime.year != now.year) {
              return false;
            }
            break;
          case 'week':
            if (now.difference(alertTime).inDays > 7) return false;
            break;
          case 'month':
            if (now.difference(alertTime).inDays > 30) return false;
            break;
        }
      }

      // Status filter
      if (_selectedStatus == 'unread' && alert.read) return false;
      if (_selectedStatus == 'resolved' && !alert.resolved) return false;

      return true;
    }).toList();

    notifyListeners();
  }

  // Mark alert as read
  Future<void> markRead(String alertId) async {
    try {
      await _alertRepo.markRead(alertId);
      final index = _allAlerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        _allAlerts[index] = _allAlerts[index].copyWith(read: true);
      }
      _applyFilters();
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  // Resolve alert
  Future<void> resolve(String alertId) async {
    try {
      await _alertRepo.resolve(alertId);
      final index = _allAlerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        _allAlerts[index] = _allAlerts[index].copyWith(resolved: true);
      }
      _applyFilters();
    } catch (e) {
      print('Error resolving alert: $e');
    }
  }

  // Delete alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _alertRepo.delete(alertId);
      _allAlerts.removeWhere((a) => a.id == alertId);
      _applyFilters();
    } catch (e) {
      print('Error deleting alert: $e');
    }
  }

  // Refresh alerts
  Future<void> refresh() => loadAlerts();
}
