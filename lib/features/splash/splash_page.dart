import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/app_session.dart';
import '../../core/diagnostic/launch_diagnostic.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../shell/main_shell.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int _buildLogCount = 0;

  @override
  void initState() {
    super.initState();
    bootTrace('SplashPage.initState');
    // Primeiro frame antes de path_provider/SQLite: reduz “gesture gate timed out”
    // e conflitos com o ciclo de vida no iOS ao reabrir o app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bootTrace('SplashPage.postFrame', 'iniciar _boot');
      if (!mounted) return;
      unawaited(_boot());
    });
  }

  Future<void> _boot() async {
    try {
      bootTrace('Splash._boot', 'start');
      logLaunch('Splash._boot start');
      final db = context.read<AppDatabase>();
      final session = context.read<AppSession>();
      final repo = context.read<AppDataRepository>();
      bootTrace('Splash._boot', 'providers OK');
      await Future<void>.delayed(Duration.zero);
      bootTrace('Splash._boot', 'warmUp…');
      await repo.warmUp();
      bootTrace('Splash._boot', 'bootstrapIfNeeded…');
      await session.bootstrapIfNeeded(db);
      bootTrace('Splash._boot', 'delay 600ms');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      bootTrace('Splash._boot', 'pushReplacementNamed MainShell');
      logLaunch('Splash._boot navigate MainShell');
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pushReplacementNamed(MainShell.routeName);
      bootTrace('Splash._boot', 'navegação enviada');
    } catch (e, st) {
      bootTrace('Splash._boot FAILED', e);
      logLaunch('Splash._boot FAILED', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Falha ao iniciar: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_buildLogCount < 6) {
      bootTrace('SplashPage.build', '#$_buildLogCount');
      _buildLogCount++;
    }
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: AppColors.splashMint,
          fontWeight: FontWeight.bold,
          fontSize: 32,
          letterSpacing: 0.4,
        );

    // Sem Image.asset aqui: decode da foto de fundo atrasava o 1º frame ~10s no dispositivo
    // e gerava “gesture gate timed out” / inversão de prioridade no Skia (font metrics).
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.backgroundDeep,
              AppColors.background,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Personal Trainer',
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              const SizedBox(height: 12),
              Text(
                'Powered by Leonardo Peres',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.splashMint,
                  strokeWidth: 3.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
