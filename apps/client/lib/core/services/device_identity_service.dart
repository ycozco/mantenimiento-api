import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stores a non-secret, stable identifier for this local installation.
/// NATS credentials and organization membership must never be stored here.
class DeviceIdentityService {
  static const _deviceIdKey = 'sync_device_id_v1';
  static const _uuid = Uuid();

  final Future<SharedPreferences> Function() _preferences;

  DeviceIdentityService({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<String> getOrCreateDeviceId() async {
    final prefs = await _preferences();
    final current = prefs.getString(_deviceIdKey);
    if (current != null && current.isNotEmpty) return current;

    final created = _uuid.v4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }
}
