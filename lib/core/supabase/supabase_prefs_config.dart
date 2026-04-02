import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_constants.dart';

/// Chave anon e URL opcional guardadas no aparelho (quando não há `--dart-define`).
abstract final class SupabasePrefsConfig {
  static const _kAnon = 'app_supabase_anon_key_v1';
  static const _kUrl = 'app_supabase_url_v1';

  static String normalizeUrl(String raw) {
    var b = raw.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  static Future<({String url, String anonKey})?> loadForStartup() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString(_kAnon)?.trim() ?? '';
    if (k.isEmpty) return null;
    final uRaw = p.getString(_kUrl)?.trim() ?? '';
    final url = uRaw.isEmpty
        ? SupabaseConstants.defaultUrl
        : normalizeUrl(uRaw);
    return (url: url, anonKey: k);
  }

  static Future<void> save({required String anonKey, String? url}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAnon, anonKey.trim());
    if (url != null && url.trim().isNotEmpty) {
      await p.setString(_kUrl, normalizeUrl(url));
    } else {
      await p.remove(_kUrl);
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAnon);
    await p.remove(_kUrl);
  }

  static Future<bool> hasSavedCredentials() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_kAnon)?.trim().isNotEmpty ?? false);
  }
}
