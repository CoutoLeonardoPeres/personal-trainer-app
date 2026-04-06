import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/auth/app_session.dart';
import '../core/diagnostic/launch_diagnostic.dart';
import '../core/supabase/supabase_app_init.dart';
import '../core/supabase/supabase_sync_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/local/app_database.dart';
import '../data/repositories/app_data_repository.dart';
import '../data/sync/remote_sync_service.dart';
import '../data/sync/supabase_auto_push_scheduler.dart';
import '../data/sync/supabase_cloud_fidelity_checker.dart';
import '../data/sync/supabase_remote_sync_service.dart';
import '../features/shell/main_shell.dart';
import '../features/splash/splash_page.dart';

class _LoadedServices {
  _LoadedServices({
    required this.db,
    required this.session,
    required this.sync,
    required this.fidelity,
    required this.repo,
    required this.remoteSync,
  });

  final AppDatabase db;
  final AppSession session;
  final SupabaseSyncController sync;
  final SupabaseCloudFidelityChecker fidelity;
  final AppDataRepository repo;
  final RemoteSyncService remoteSync;
}

/// Raiz do app: um único [MaterialApp] “de carregamento” e, depois,
/// **sempre** [MultiProvider] **por fora** do [MaterialApp] para as rotas
/// nomeadas (ex. [MainShell]) herdarem [Provider].
class PersonalTrainerApp extends StatefulWidget {
  const PersonalTrainerApp({super.key});

  @override
  State<PersonalTrainerApp> createState() => _PersonalTrainerAppState();
}

class _PersonalTrainerAppState extends State<PersonalTrainerApp>
    with WidgetsBindingObserver {
  _LoadedServices? _services;
  Object? _loadError;
  bool _loadStarted = false;
  String? _lastBootBuildMode;

  @override
  void initState() {
    super.initState();
    bootTrace('PersonalTrainerApp.initState');
    logLaunch('PersonalTrainerApp.initState');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bootTrace('PersonalTrainerApp.postFrameCallback', 'agendar _loadServices');
      if (!mounted || _loadStarted) return;
      _loadStarted = true;
      unawaited(_loadServices());
    });
  }

  Future<void> _loadServices() async {
    try {
      bootTrace('_loadServices', 'antes de Future.delayed(0)');
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      bootTrace('_loadServices', 'antes de AppDatabase()');
      logLaunch('PersonalTrainerApp._loadServices: AppDatabase()');
      final db = AppDatabase();
      final session = AppSession();
      final sync = SupabaseSyncController();
      final fidelity = SupabaseCloudFidelityChecker(db, sync);
      final remoteSync = SupabaseRemoteSyncService(db, sync);
      final repo = AppDataRepository(
        db,
        session,
        remoteSync: remoteSync,
      );
      final bundle = _LoadedServices(
        db: db,
        session: session,
        sync: sync,
        fidelity: fidelity,
        repo: repo,
        remoteSync: remoteSync,
      );
      if (!mounted) return;
      bootTrace('_loadServices', 'AppDatabase + repo OK → setState(services)');
      setState(() {
        _services = bundle;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bootTrace('postFrame', 'após services → Supabase/cloud');
        if (!mounted) return;
        unawaited(_initSupabaseThenCloudServices());
      });
    } catch (e, st) {
      bootTrace('_loadServices FAILED', e);
      logLaunch('PersonalTrainerApp._loadServices FAILED', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _initSupabaseThenCloudServices() async {
    final s = _services;
    if (s == null) return;
    bootTrace('initializeSupabaseApp', 'início (sem timeout — evita corrida com startHeartbeat)');
    try {
      // Não usar .timeout() aqui: se o futuro ainda estiver a inicializar ao expirar,
      // supabaseAppEnabled pode ficar false e o heartbeat nunca volta a tentar.
      await initializeSupabaseApp();
      bootTrace('initializeSupabaseApp', 'fim OK');
    } catch (e, st) {
      bootTrace('initializeSupabaseApp', 'erro: $e');
      logLaunch('initializeSupabaseApp erro', error: e, stackTrace: st);
    }
    if (!mounted) return;
    bootTrace('cloud', 'recover queue + startHeartbeat + fidelity');
    await s.remoteSync.recoverPendingWork();
    s.sync.startHeartbeat();
    s.fidelity.start();
    SupabaseAutoPushScheduler.scheduleAfterResume(db: s.db, sync: s.sync);
  }

  void _retryLoad() {
    final old = _services;
    setState(() {
      _loadError = null;
      _services = null;
      _loadStarted = false;
    });
    if (old != null) {
      old.repo.dispose();
      old.fidelity.dispose();
      old.sync.dispose();
      old.db.close();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadStarted = true;
      unawaited(_loadServices());
    });
  }

  @override
  void dispose() {
    logLaunch('PersonalTrainerApp.dispose — DB será fechado');
    WidgetsBinding.instance.removeObserver(this);
    final s = _services;
    if (s != null) {
      s.repo.dispose();
      s.fidelity.dispose();
      s.sync.dispose();
      s.db.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sair do stack síncrono do engine → evita coincidir com avisos Swift
    // "unsafeForcedSync … Concurrent context" no iOS 26 ao minimizar.
    scheduleMicrotask(() {
      if (!mounted) return;
      logLifecycle(state);
      final s = _services;
      if (s == null) return;
      if (state == AppLifecycleState.resumed) {
        SchedulerBinding.instance.scheduleTask(
          () => SupabaseAutoPushScheduler.scheduleAfterResume(
            db: s.db,
            sync: s.sync,
          ),
          Priority.idle,
          debugLabel: 'personalApp.supabaseAutoPushAfterResume',
        );
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        SupabaseAutoPushScheduler.cancelScheduledWork();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _loadError != null
        ? 'error'
        : _services == null
            ? 'loading'
            : 'app';
    if (_lastBootBuildMode != mode) {
      _lastBootBuildMode = mode;
      bootTrace('PersonalTrainerApp.build', 'modo=$mode');
    }

    if (_loadError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _StartupErrorView(
          message: _loadError.toString(),
          onRetry: _retryLoad,
        ),
      );
    }

    if (_services == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _StartupPlaceholder(),
      );
    }

    final s = _services!;
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: s.db),
        ChangeNotifierProvider<AppSession>.value(value: s.session),
        ChangeNotifierProvider<SupabaseSyncController>.value(value: s.sync),
        Provider<AppDataRepository>.value(value: s.repo),
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

/// Textos com estilo explícito (não depende só do [Theme]) — evita “vazio” se o tema atrasar.
class _StartupPlaceholder extends StatelessWidget {
  const _StartupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Personal Trainer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.splashMint,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 28),
              SizedBox(
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

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Não foi possível abrir o banco local',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
