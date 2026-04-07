import 'package:flutter/material.dart';

import 'app/personal_app.dart';
import 'core/diagnostic/launch_diagnostic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorLogging();
  installBootDiagnostics();
  bootTrace('main()', 'ensureInitialized + logs globais + [BOOT]');
  logLaunch(
    'main() Dart OK — crash antes disto: Mac → Console.app → iPhone → filtrar Runner/ ou AppDelegate',
  );
  logLaunch('main() started — runApp imediato (Supabase no 1º frame)');
  // Supabase + SharedPreferences em [PersonalTrainerApp] após o 1º frame:
  // evita vários segundos de ecrã branco no iOS (LaunchScreen + FlutterView nativos).
  runApp(const PersonalTrainerApp());
}
