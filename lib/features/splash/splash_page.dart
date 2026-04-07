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
  bool _bootStarted = false;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    bootTrace('SplashPage.initState');
    // Primeiro frame antes de path_provider/SQLite: reduz “gesture gate timed out”
    // e conflitos com o ciclo de vida no iOS ao reabrir o app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bootTrace('SplashPage.postFrame', 'iniciar _boot');
      if (!mounted || _bootStarted) return;
      _bootStarted = true;
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
      if (_bootError != null && mounted) {
        setState(() => _bootError = null);
      }
      await Future<void>.delayed(Duration.zero);
      bootTrace('Splash._boot', 'warmUp…');
      await repo.warmUp();
      bootTrace('Splash._boot', 'bootstrapIfNeeded…');
      await session.bootstrapIfNeeded(db);
      await session.repairSessionIfInconsistent(db);
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
      setState(() => _bootError = e.toString());
    }
  }

  void _retryBoot() {
    setState(() {
      _bootStarted = false;
      _bootError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bootStarted) return;
      _bootStarted = true;
      unawaited(_boot());
    });
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

    // Foto de fundo com [FilterQuality.low] e overlays sem opacidade total para o 1º frame
    // não travar no decode e a imagem continuar visível (gradiente opaco cobria tudo).
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/fitness_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.low,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background.withValues(alpha: 0.45),
                  AppColors.backgroundDeep.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                  if (_bootError == null)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: AppColors.splashMint,
                        strokeWidth: 3.2,
                      ),
                    )
                  else ...[
                    Text(
                      'Falha ao iniciar o app',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bootError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _retryBoot,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
