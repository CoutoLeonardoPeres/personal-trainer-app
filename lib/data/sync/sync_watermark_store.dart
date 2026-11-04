import 'package:shared_preferences/shared_preferences.dart';

/// Cursor/watermark de pull incremental por tabela + escopo.
abstract final class SyncWatermarkStore {
  SyncWatermarkStore._();

  static String _key(String table, String scope) => 'sync_wm_${table}_$scope';

  static Future<DateTime?> getWatermark({
    required String table,
    String scope = 'global',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(table, scope));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static Future<void> setWatermark({
    required String table,
    required DateTime at,
    String scope = 'global',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(table, scope), at.toUtc().toIso8601String());
  }

  static Future<void> advanceWatermark({
    required String table,
    required DateTime candidate,
    String scope = 'global',
  }) async {
    final cur = await getWatermark(table: table, scope: scope);
    if (cur == null || candidate.isAfter(cur)) {
      await setWatermark(table: table, at: candidate, scope: scope);
    }
  }

  static String scopeForSession({
    bool fullCloud = false,
    String? personalId,
    String? studentId,
  }) {
    if (studentId != null && studentId.isNotEmpty) {
      return 'student:$studentId';
    }
    if (personalId != null && personalId.isNotEmpty) {
      return 'personal:$personalId';
    }
    if (fullCloud) return 'admin';
    return 'global';
  }
}
