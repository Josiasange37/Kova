// parent/providers/children_provider.dart — State for child management
import 'package:flutter/foundation.dart';

import 'package:kova/local_backend/repositories/child_repository.dart';

class ChildrenProvider extends ChangeNotifier {
  final _repo = ChildRepository();

  List<ChildModel> _children = [];
  bool _loading = false;
  String? _error;

  // Getters
  List<ChildModel> get children => _children;
  bool get loading => _loading;
  String? get error => _error;

  /// Load all children from database
  Future<void> loadChildren() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _children = await _repo.getAll();
    } catch (e) {
      _error = 'Erreur lors du chargement des enfants: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create a new child
  Future<String?> addChild(String name) async {
    try {
      final childId = await _repo.create(name);
      await loadChildren();
      return childId;
    } catch (e) {
      _error = 'Erreur lors de la création de l\'enfant: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete a child
  Future<bool> deleteChild(String childId) async {
    try {
      await _repo.delete(childId);
      await loadChildren();
      return true;
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update app monitoring for a child
  Future<void> updateAppControl(
    String childId,
    String app,
    bool enabled,
  ) async {
    try {
      await _repo.updateAppControl(childId, app, enabled);
      // Update local state
      final idx = _children.indexWhere((c) => c.id == childId);
      if (idx >= 0) {
        _children[idx] = _children[idx].copyWith(
          appControls: {..._children[idx].appControls, app: enabled},
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur lors de la mise à jour: $e';
      notifyListeners();
    }
  }

  /// Get a child by ID
  ChildModel? getChild(String childId) {
    try {
      return _children.firstWhere((c) => c.id == childId);
    } catch (_) {
      return null;
    }
  }

  /// Get a child by pairing code
  Future<ChildModel?> getChildByCode(String code) async {
    try {
      return await _repo.getByCode(code);
    } catch (e) {
      _error = 'Code invalide: $e';
      notifyListeners();
      return null;
    }
  }

  /// Refresh data
  Future<void> refresh() => loadChildren();
}
