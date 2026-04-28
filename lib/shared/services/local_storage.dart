// shared/services/local_storage.dart — SharedPreferences wrapper
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Wrapper around SharedPreferences for consistent key management
/// Handles all app-level preferences (mode, child IDs, settings)
class LocalStorage {
  static late final SharedPreferences _prefs;

  /// Initialize LocalStorage once at app start
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// --- Mode & Authentication ---

  static Future<void> setAppMode(String mode) =>
      _prefs.setString('app_mode', mode);

  static String? getAppMode() => _prefs.getString('app_mode');

  static Future<void> setParentPinHash(String hash) =>
      _prefs.setString('parent_pin_hash', hash);

  static String? getParentPinHash() => _prefs.getString('parent_pin_hash');

  static Future<void> setChildId(String childId) =>
      _prefs.setString('child_id', childId);

  static String? getChildId() => _prefs.getString('child_id');

  static Future<void> setPairToken(String token) =>
      _prefs.setString('pair_token', token);

  static String getPairToken() => _prefs.getString('pair_token') ?? '';

  static Future<void> setParentDeviceId(String id) =>
      _prefs.setString('parent_device_id', id);

  static String getParentDeviceId() => _prefs.getString('parent_device_id') ?? '';

  static Future<void> setChildDeviceId(String id) =>
      _prefs.setString('child_device_id', id);

  static String getChildDeviceId() => _prefs.getString('child_device_id') ?? '';

  static Future<void> setLastChildPeer(Map<String, dynamic> data) =>
      _prefs.setString('last_child_peer', jsonEncode(data));

  static Map<String, dynamic>? getLastChildPeer() {
    final str = _prefs.getString('last_child_peer');
    if (str != null && str.isNotEmpty) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    return null;
  }

  /// --- Parent Settings ---

  static Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool('notifications_enabled', enabled);

  static bool getNotificationsEnabled() =>
      _prefs.getBool('notifications_enabled') ?? true;

  static Future<void> setAlertSoundEnabled(bool enabled) =>
      _prefs.setBool('alert_sound_enabled', enabled);

  static bool getAlertSoundEnabled() =>
      _prefs.getBool('alert_sound_enabled') ?? true;

  static Future<void> setSensitivityLevel(String level) =>
      _prefs.setString('sensitivity_level', level);

  static String getSensitivityLevel() =>
      _prefs.getString('sensitivity_level') ?? 'medium';

  static Future<void> setAutoBlockEnabled(bool enabled) =>
      _prefs.setBool('auto_block_enabled', enabled);

  static bool getAutoBlockEnabled() =>
      _prefs.getBool('auto_block_enabled') ?? false;

  /// --- Child Settings ---

  static Future<void> setAccessibilityEnabled(bool enabled) =>
      _prefs.setBool('accessibility_enabled', enabled);

  static bool getAccessibilityEnabled() =>
      _prefs.getBool('accessibility_enabled') ?? false;

  static Future<void> setSetupCompleted(bool completed) =>
      _prefs.setBool('setup_completed', completed);

  static bool getSetupCompleted() => _prefs.getBool('setup_completed') ?? false;

  /// --- Generic Methods ---

  static Future<bool> remove(String key) => _prefs.remove(key);

  static Future<bool> clear() => _prefs.clear();

  static String getString(String key, [String? defaultValue]) =>
      _prefs.getString(key) ?? defaultValue ?? '';

  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  static bool getBool(String key, [bool? defaultValue]) =>
      _prefs.getBool(key) ?? defaultValue ?? false;

  static Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static int getInt(String key, [int? defaultValue]) =>
      _prefs.getInt(key) ?? defaultValue ?? 0;

  static Future<bool> setInt(String key, int value) =>
      _prefs.setInt(key, value);
}
