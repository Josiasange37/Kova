// parent/services/app_control_service.dart — App control management
// Manages per-app monitoring settings

import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';
import 'package:kova/local_backend/repositories/alert_repository.dart';

class AppControlService extends ChangeNotifier {
  final _childRepo = ChildRepository();
  final _alertRepo = AlertRepository();

  List<ChildModel> _children = [];
  final Map<String, AppControlData> _appData = {};
  bool _loading = false;
  String? _error;

  // Getters
  List<ChildModel> get children => _children;
  Map<String, AppControlData> get appData => _appData;
  bool get loading => _loading;
  String? get error => _error;

  // Load children and calculate app data
  Future<void> loadAppControls() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _children = await _childRepo.getAll();
      await _calculateAppData();
      _error = null;
    } catch (e) {
      _error = 'Error loading app controls: $e';
      debugPrint(_error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Calculate app statistics
  Future<void> _calculateAppData() async {
    final apps = ['whatsapp', 'tiktok', 'facebook', 'instagram', 'sms', 'x'];

    for (final app in apps) {
      // Get alerts for this app (across all children)
      final allAlerts = await _alertRepo.getAll();
      final appAlerts = allAlerts
          .where((a) => a.app.toLowerCase() == app)
          .toList();

      final alertCount = appAlerts.length;
      final blockCount = appAlerts.where((a) => a.resolved).length;

      // Check if app is enabled for any child
      final isEnabled = _children.any((c) => c.appControls[app] ?? true);

      _appData[app] = AppControlData(
        name: _formatAppName(app),
        alerts: alertCount,
        blocks: blockCount,
        enabled: isEnabled,
        sensitivity: 1, // Default sensitivity
        blocking: blockCount > 0 ? 1 : 0,
      );
    }
  }

  String _formatAppName(String app) {
    switch (app) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'tiktok':
        return 'TikTok';
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'sms':
        return 'SMS';
      case 'x':
        return 'X';
      default:
        return app;
    }
  }

  // Toggle app monitoring for a child
  Future<void> toggleAppControl(
    String childId,
    String app,
    bool enabled,
  ) async {
    try {
      await _childRepo.updateAppControl(childId, app, enabled);

      // Update local state
      final index = _children.indexWhere((c) => c.id == childId);
      if (index >= 0) {
        _children[index] = _children[index].copyWith(
          appControls: {..._children[index].appControls, app: enabled},
        );
      }

      // Recalculate app data
      await _calculateAppData();
    } catch (e) {
      debugPrint('Error toggling app control: $e');
    }
  }

  // Refresh data
  Future<void> refresh() => loadAppControls();
}

// Data class for app control info
class AppControlData {
  final String name;
  final int alerts;
  final int blocks;
  final bool enabled;
  final int sensitivity;
  final int blocking;

  AppControlData({
    required this.name,
    required this.alerts,
    required this.blocks,
    required this.enabled,
    required this.sensitivity,
    required this.blocking,
  });
}
