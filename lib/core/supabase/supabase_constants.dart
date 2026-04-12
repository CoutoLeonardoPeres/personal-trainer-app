/// URL padrão do projeto [projectRef]; pode ser sobrescrita no build com
/// `--dart-define=SUPABASE_URL=https://SEU_REF.supabase.co` (deve coincidir com o painel).
abstract final class SupabaseConstants {
  static const String projectDisplayName = 'Personal Gym';
  static const String projectRef = 'onmzbyltmbdkuodirfow';
  static const String defaultUrl = 'https://onmzbyltmbdkuodirfow.supabase.co';

  /// URL efetiva: `SUPABASE_URL` (trim, sem barra final) ou [defaultUrl].
  static String resolvedUrl() {
    const fromEnv = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    var base = fromEnv.trim().isNotEmpty ? fromEnv.trim() : defaultUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }
}
