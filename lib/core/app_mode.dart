// core/app_mode.dart — App mode management (parent vs child)
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// The two operating modes for KOVA
enum AppMode { parent, child, notConfigured }

/// Manages app mode selection and persistence
/// This is the heart of the dual-mode system
class AppModeManager {
  static const String _modeKey = 'app_mode';
  static const String _childIdKey = 'child_id';
  static const String _parentPinHashKey = 'parent_pin_hash';

  /// Get the currently configured app mode
  static Future<AppMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey);
    return switch (mode) {
      'parent' => AppMode.parent,
      'child' => AppMode.child,
      _ => AppMode.notConfigured,
    };
  }

  /// Initialize app as PARENT MODE with a PIN
  /// Called after user creates PIN on welcome screen
  static Future<void> setParentMode(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await prefs.setString(_modeKey, 'parent');
    await prefs.setString(_parentPinHashKey, hash);
  }

  /// Initialize app as CHILD MODE using a pairing code
  /// The pairing code links to a parent's child record
  /// This is called from child_pairing_screen after code entry
  static Future<bool> setChildMode(String pairCode) async {
    // Import will be resolved when repositories are ready
    // For now, validate code format (8 chars alphanumeric)
    if (pairCode.length != 8) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, 'child');
    await prefs.setString(_childIdKey, pairCode);

    return true;
  }

  /// Verify parent PIN for sensitive operations
  /// (e.g., viewing child alerts, changing settings)
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_parentPinHashKey);
    if (storedHash == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return hash == storedHash;
  }

  /// Get the linked child ID (child mode only)
  /// This is the pairing code that identifies which child record
  /// this device is monitoring for
  static Future<String?> getChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_childIdKey);
  }

  /// Reset app mode (requires PIN for security)
  /// Use this to switch between parent and child mode
  static Future<bool> resetMode(String pin) async {
    // Only parent can reset
    final isValid = await verifyPin(pin);
    if (!isValid) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modeKey);
    await prefs.remove(_childIdKey);
    return true;
  }

  /// Get parent PIN hash (for storage/comparison only)
  /// Never expose the actual PIN
  static Future<String?> getPinHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_parentPinHashKey);
  }
}
