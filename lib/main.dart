import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/personal_app.dart';
import 'core/diagnostic/launch_diagnostic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS: não fixar orientação — alinha com UISupportedInterfaceOrientations (revisão App Store).
  if (defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
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
