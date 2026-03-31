// parent/services/child_profile_service.dart — Child profile management
// Handles child profile creation and pairing code generation

import 'package:flutter/foundation.dart';
import 'package:kova/local_backend/repositories/child_repository.dart';

class ChildProfileService extends ChangeNotifier {
  final _childRepo = ChildRepository();

  String? _childId;
  String _childName = '';
  int _age = 10;
  String? _avatarPath;
  String? _pairCode;
  DateTime? _pairCodeExpiry;
  bool _saving = false;
  String? _error;

  // Getters
  String? get childId => _childId;
  String get childName => _childName;
  int get age => _age;
  String? get avatarPath => _avatarPath;
  String? get pairCode => _pairCode;
  DateTime? get pairCodeExpiry => _pairCodeExpiry;
  bool get saving => _saving;
  String? get error => _error;

  // Computed properties
  String get modeName {
    if (_age < 8) return 'Strict mode';
    if (_age <= 12) return 'Standard mode';
    return 'Teen mode';
  }

  String get modeDescription {
    if (_age < 8) return 'Maximum protection for young kids';
    if (_age <= 12) return 'Balanced protection for pre-teens';
    return 'Flexible protection for teenagers';
  }

  // Update child name
  void setChildName(String name) {
    _childName = name;
    notifyListeners();
  }

  // Update age
  void setAge(int age) {
    _age = age.clamp(3, 18);
    notifyListeners();
  }

  // Update avatar
  void setAvatarPath(String? path) {
    _avatarPath = path;
    notifyListeners();
  }

  // Save child profile and generate pairing code
  Future<bool> saveChildProfile() async {
    if (_childName.trim().isEmpty) {
      _error = 'Child name is required';
      notifyListeners();
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      // Create child in repository (generates pairing code automatically)
      _childId = await _childRepo.create(_childName, age: _age, avatarPath: _avatarPath);

      // Get the created child to retrieve the pairing code
      final child = await _childRepo.getById(_childId!);
      if (child != null) {
        _pairCode = child.pairCode;
        _pairCodeExpiry = child.pairCodeExp != null
            ? DateTime.fromMillisecondsSinceEpoch(child.pairCodeExp!)
            : null;
      }

      _error = null;
      return true;
    } catch (e) {
      _error = 'Error saving child profile: $e';
      debugPrint(_error);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // Check if child is linked (paired with child device)
  Future<bool> isChildLinked() async {
    if (_childId == null) return false;

    try {
      final child = await _childRepo.getById(_childId!);
      return child?.linked ?? false;
    } catch (e) {
      return false;
    }
  }

  // Reset state for new child
  void reset() {
    _childId = null;
    _childName = '';
    _age = 10;
    _avatarPath = null;
    _pairCode = null;
    _pairCodeExpiry = null;
    _error = null;
    notifyListeners();
  }
}
