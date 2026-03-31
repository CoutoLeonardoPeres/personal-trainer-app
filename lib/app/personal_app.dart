import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../data/local/app_database.dart';
import '../data/repositories/app_data_repository.dart';
import '../features/shell/main_shell.dart';
import '../features/splash/splash_page.dart';

class PersonalTrainerApp extends StatelessWidget {
  const PersonalTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (_) => AppDatabase(),
          dispose: (_, db) => db.close(),
        ),
        ProxyProvider<AppDatabase, AppDataRepository>(
          update: (_, db, _) => AppDataRepository(db),
        ),
      ],
      child: MaterialApp(
        title: 'Personal Trainer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashPage(),
        routes: {
          MainShell.routeName: (_) => const MainShell(),
        },
      ),
    );
  }
}
