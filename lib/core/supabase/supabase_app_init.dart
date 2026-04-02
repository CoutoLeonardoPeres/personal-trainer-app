import 'package:supabase_flutter/supabase_flutter.dart';

import '../diagnostic/launch_diagnostic.dart';
import 'supabase_bootstrap.dart';
import 'supabase_constants.dart';
import 'supabase_prefs_config.dart';

/// Chave pública do app (compile-time).
///
/// Recomendado: `SUPABASE_ANON_KEY` (JWT). Nunca `service_role` no cliente.
String readSupabasePublicKeyFromEnvironment() {
  const legacy = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  if (legacy.trim().isNotEmpty) return legacy.trim();
  return const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  ).trim();
}

/// Inicializa o cliente Supabase (prefs ou dart-define). Chame **depois** de
/// [runApp] (ex.: no 1º [WidgetsBinding.instance.addPostFrameCallback]) para
/// não bloquear o 1º frame no iOS (LaunchScreen + FlutterView brancos).
Future<void> initializeSupabaseApp() async {
  bootTrace('initializeSupabaseApp', 'entry');
  try {
    final publicKey = readSupabasePublicKeyFromEnvironment();
    final supabaseUrl = SupabaseConstants.resolvedUrl();
    if (publicKey.isNotEmpty) {
      supabaseFromDartDefine = true;
      bootTrace('initializeSupabaseApp', 'chave dart-define');
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: publicKey,
        );
        supabaseAppEnabled = true;
        bootTrace('initializeSupabaseApp', 'Supabase.initialize OK (define)');
        logLaunch('Supabase.initialize ok (dart-define)');
      } catch (e, st) {
        bootTrace('initializeSupabaseApp', 'Supabase.initialize FALHOU (define): $e');
        logLaunch('Supabase.initialize falhou', error: e, stackTrace: st);
        supabaseAppEnabled = false;
      }
      return;
    }

    bootTrace('initializeSupabaseApp', 'ler prefs…');
    final fromPrefs = await SupabasePrefsConfig.loadForStartup();
    if (fromPrefs != null) {
      bootTrace('initializeSupabaseApp', 'prefs com chave → initialize');
      try {
        await Supabase.initialize(
          url: fromPrefs.url,
          anonKey: fromPrefs.anonKey,
        );
        supabaseAppEnabled = true;
        bootTrace('initializeSupabaseApp', 'Supabase.initialize OK (prefs)');
        logLaunch('Supabase.initialize ok (SharedPreferences)');
      } catch (e, st) {
        bootTrace('initializeSupabaseApp', 'Supabase.initialize FALHOU (prefs): $e');
        logLaunch('Supabase.initialize falhou (prefs)', error: e, stackTrace: st);
        supabaseAppEnabled = false;
      }
    } else {
      bootTrace('initializeSupabaseApp', 'sem chave (dart-define nem prefs)');
      logLaunch('Supabase desativado (sem chave: dart-define nem prefs)');
    }
  } finally {
    bootTrace('initializeSupabaseApp', 'exit');
  }
}
