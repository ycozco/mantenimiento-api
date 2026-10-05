import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_preferences.dart';

class DevicePreferencesService {
  static const String _keyThemeMode = 'device_theme_mode';
  static const String _keyNotifications = 'device_notifications_enabled';
  static const String _keyCompactView = 'device_compact_view';
  static const String _keyLastScreen = 'device_last_screen';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Carga las preferencias locales del dispositivo
  Future<DevicePreferences> getPreferences() async {
    final prefs = await _getPrefs();
    return DevicePreferences(
      themeMode: prefs.getString(_keyThemeMode) ?? 'dark',
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
      compactView: prefs.getBool(_keyCompactView) ?? false,
      lastScreen: prefs.getString(_keyLastScreen),
    );
  }

  /// Guarda todas las preferencias locales
  Future<void> updatePreferences(DevicePreferences preferences) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyThemeMode, preferences.themeMode);
    await prefs.setBool(_keyNotifications, preferences.notificationsEnabled);
    await prefs.setBool(_keyCompactView, preferences.compactView);
    if (preferences.lastScreen != null) {
      await prefs.setString(_keyLastScreen, preferences.lastScreen!);
    } else {
      await prefs.remove(_keyLastScreen);
    }
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyNotifications, enabled);
  }

  Future<void> setCompactView(bool compact) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyCompactView, compact);
  }
}
