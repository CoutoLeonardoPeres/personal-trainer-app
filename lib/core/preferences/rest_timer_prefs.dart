import 'package:shared_preferences/shared_preferences.dart';

/// Som ao fim do descanso entre séries (timer regressivo).
class RestTimerPrefs {
  RestTimerPrefs._();

  static const _kSound = 'rest_timer_sound_enabled';

  static Future<bool> isSoundEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSound) ?? true;
  }

  static Future<void> setSoundEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSound, value);
  }
}
