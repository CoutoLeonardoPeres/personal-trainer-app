import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de execução para economizar bateria durante treino.
class WorkoutRuntimePrefs {
  WorkoutRuntimePrefs._();

  static const _kRestIntervalEnabled = 'workout_rest_interval_enabled';
  static const _kLiveActivityEnabled = 'workout_live_activity_enabled';

  static bool? _restIntervalEnabledCache;
  static bool? _liveActivityEnabledCache;

  static Future<bool> isRestIntervalEnabled() async {
    final cached = _restIntervalEnabledCache;
    if (cached != null) return cached;
    final p = await SharedPreferences.getInstance();
    final value = p.getBool(_kRestIntervalEnabled) ?? true;
    _restIntervalEnabledCache = value;
    return value;
  }

  static Future<void> setRestIntervalEnabled(bool value) async {
    _restIntervalEnabledCache = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRestIntervalEnabled, value);
  }

  static Future<bool> isLiveActivityEnabled() async {
    final cached = _liveActivityEnabledCache;
    if (cached != null) return cached;
    final p = await SharedPreferences.getInstance();
    final value = p.getBool(_kLiveActivityEnabled) ?? true;
    _liveActivityEnabledCache = value;
    return value;
  }

  static Future<void> setLiveActivityEnabled(bool value) async {
    _liveActivityEnabledCache = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLiveActivityEnabled, value);
  }
}
