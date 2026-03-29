// parent/services/settings_service.dart — App settings management
// Manages user preferences and app settings

import 'package:flutter/foundation.dart';
import 'package:kova/shared/services/local_storage.dart';

class SettingsService extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = 'en';
  String _theme = 'light';
  bool _loading = false;

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get language => _language;
  String get theme => _theme;
  bool get loading => _loading;

  // Load settings from storage
  Future<void> loadSettings() async {
    _loading = true;
    notifyListeners();

    try {
      _notificationsEnabled = await LocalStorage.getBool(
        'notifications_enabled',
        true,
      );
      _soundEnabled = await LocalStorage.getBool('sound_enabled', true);
      _vibrationEnabled = await LocalStorage.getBool('vibration_enabled', true);
      _language = await LocalStorage.getString('language', 'en');
      _theme = await LocalStorage.getString('theme', 'light');
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Update notifications setting
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await LocalStorage.setBool('notifications_enabled', enabled);
    notifyListeners();
  }

  // Update sound setting
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await LocalStorage.setBool('sound_enabled', enabled);
    notifyListeners();
  }

  // Update vibration setting
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await LocalStorage.setBool('vibration_enabled', enabled);
    notifyListeners();
  }

  // Update language
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await LocalStorage.setString('language', lang);
    notifyListeners();
  }

  // Update theme
  Future<void> setTheme(String newTheme) async {
    _theme = newTheme;
    await LocalStorage.setString('theme', newTheme);
    notifyListeners();
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setNotificationsEnabled(true);
    await setSoundEnabled(true);
    await setVibrationEnabled(true);
    await setLanguage('en');
    await setTheme('light');
  }
}
