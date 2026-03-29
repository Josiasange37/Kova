// shared/services/local_storage.dart — SharedPreferences wrapper
import 'package:shared_preferences/shared_preferences.dart';

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

  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static int? getInt(String key) => _prefs.getInt(key);

  static Future<bool> setInt(String key, int value) =>
      _prefs.setInt(key, value);
}
