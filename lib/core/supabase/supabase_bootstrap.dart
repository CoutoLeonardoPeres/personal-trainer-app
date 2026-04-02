/// `true` somente após [Supabase.initialize] bem-sucedido em [main].
/// Não chame [Supabase.instance] antes disso (assert em debug).
bool supabaseAppEnabled = false;

/// `true` se a chave veio de `--dart-define` (tem prioridade sobre prefs).
bool supabaseFromDartDefine = false;
