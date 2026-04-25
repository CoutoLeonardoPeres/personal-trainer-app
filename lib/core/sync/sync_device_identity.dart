import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SyncDeviceIdentity {
  SyncDeviceIdentity._();

  static const _kDeviceIdKey = 'sync_device_id_v1';
  static Future<String>? _memoized;

  static Future<String> getOrCreate() {
    return _memoized ??= _readOrCreate();
  }

  static Future<String> _readOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await prefs.setString(_kDeviceIdKey, created);
    return created;
  }
}
