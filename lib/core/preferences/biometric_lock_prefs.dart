import 'package:shared_preferences/shared_preferences.dart';

const _kBiometricOnResume = 'app_biometric_lock_on_resume';

/// Proteção opcional ao voltar do segundo plano (Face ID / impressão digital).
class BiometricLockPrefs {
  static Future<bool> get enabled async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kBiometricOnResume) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBiometricOnResume, v);
  }
}
