// parent/services/dashboard_data_service.dart — Dashboard data provider
// Provides real data from repositories to DashboardScreen

import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';
import 'package:kova/shared/models/alert_model.dart';
import 'package:kova/shared/services/local_storage.dart';

class DashboardDataService extends ChangeNotifier {
  final _childRepo = ChildRepository();
  final _alertRepo = AlertRepository();

  List<ChildModel>? _children;
  List<AlertModel>? _alerts;
  String? _parentName;
  bool _loading = false;
  String? _error;

  // Getters matching what DashboardScreen expects
  List<ChildModel>? get children => _children;
  List<AlertModel>? get alerts => _alerts;
  String? get parentName => _parentName ?? 'Parent';
  bool get loading => _loading;
  String? get error => _error;

  // Active child (first child for now, can be expanded later)
  ChildModel? get activeChild =>
      _children != null && _children!.isNotEmpty ? _children!.first : null;

  // Dashboard metrics
  int get alertCount => _alerts?.where((a) => !a.read).length ?? 0;

  int get safetyScore {
    if (_children == null || _children!.isEmpty) return 100;
    final scores = _children!.map((c) => c.score).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    return avgScore.toInt();
  }

  bool get hasAlerts => alertCount > 0;

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
      _parentName = await LocalStorage.getString('parent_name');

      _error = null;
    } catch (e) {
      _error = 'Error loading dashboard: $e';
      print(_error);
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

  // Get child by ID
  ChildModel? getChildById(String id) {
    if (_children == null) return null;
    try {
      return _children!.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
