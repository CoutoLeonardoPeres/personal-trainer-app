import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/auth/app_session.dart';
import '../core/diagnostic/launch_diagnostic.dart';
import '../core/supabase/supabase_app_init.dart';
import '../core/auth/supabase_auth_bridge.dart';
import '../core/supabase/supabase_auth_service.dart';
import '../core/supabase/supabase_sync_controller.dart';
import '../core/notifications/workout_activity_local_notifier.dart';
import '../core/workout/rest_timer_sound.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/version/app_version_marker.dart';
import '../core/workout/rest_live_activity_controller.dart';
import '../core/workout/workout_live_deep_link_controller.dart';
import '../core/widgets/biometric_resume_lock.dart';
import '../core/widgets/modern_loading.dart';
import '../core/widgets/student_workout_live_activity_bar.dart';
import '../data/local/app_database.dart';
import '../data/repositories/app_data_repository.dart';
import '../data/sync/remote_sync_service.dart';
import '../data/sync/supabase_cloud_fidelity_checker.dart';
import '../data/sync/modern_remote_sync_service.dart';
import '../features/auth/local_login_page.dart';
import '../features/auth/password_recovery_page.dart';
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
    required this.deepLink,
  });

  final AppDatabase db;
  final AppSession session;
  final SupabaseSyncController sync;
  final SupabaseCloudFidelityChecker fidelity;
  final AppDataRepository repo;
  final RemoteSyncService remoteSync;
  final WorkoutLiveDeepLinkController deepLink;
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
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  _LoadedServices? _services;
  Object? _loadError;
  bool _loadStarted = false;
  String? _lastBootBuildMode;
  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription? _authSubscription;
  ModernRemoteSyncService? _modernSync;
  bool _authenticatedCloudServicesStarted = false;
  bool _keepScreenOnApplied = false;

  Future<void> _setKeepScreenOn(bool enabled) async {
    if (_keepScreenOnApplied == enabled) return;
    _keepScreenOnApplied = enabled;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Best effort: se o plugin falhar, o app segue normalmente.
    }
  }

  void _cancelAppLinks() {
    _appLinkSubscription?.cancel();
    _appLinkSubscription = null;
  }

  Future<void> _handleWorkoutAppLink(Uri uri, _LoadedServices s) async {
    if (uri.scheme != 'apppersonal') return;
    // Supabase OAuth callback (Google/GitHub).
    if (uri.host == 'login-callback') {
      try {
        await SupabaseAuthService.handleAuthCallback(uri);
        if (uri.queryParameters['flow'] == 'recovery') {
          _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
            PasswordRecoveryPage.routeName,
            (_) => false,
          );
          return;
        }
        await SupabaseAuthBridge.tryHydrateAppSessionFromSupabaseAuth(
          db: s.db,
          session: s.session,
        );
        await s.repo.refreshSessionPersonalAdminFlag();
      } catch (e, st) {
        logLaunch('OAuth callback error', error: e, stackTrace: st);
      }
      return;
    }
    if (uri.host != 'workout') return;
    final pathOk =
        uri.path == '/register-set' ||
        (uri.pathSegments.length == 1 &&
            uri.pathSegments.first == 'register-set');
    if (!pathOk) return;

    final wid = uri.queryParameters['wid']?.trim();
    String? id;
    if (wid != null && wid.isNotEmpty) {
      final w = await s.repo.getDayWorkout(wid);
      if (w != null && w.status == 'started') {
        id = w.id;
      }
    }
    if (id == null) {
      final list = await s.repo.fetchAccessibleStartedDayWorkouts();
      if (list.isNotEmpty) id = list.first.id;
    }
    if (id == null) return;
    s.deepLink.requestOpenActiveSheet(id, preferRestTimerOverlay: true);
  }

  void _startAppLinks(_LoadedServices s) {
    _cancelAppLinks();
    final appLinks = AppLinks();
    _appLinkSubscription = appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleWorkoutAppLink(uri, s));
    });
    unawaited(
      appLinks.getInitialLink().then((uri) {
        if (uri != null && mounted) {
          unawaited(_handleWorkoutAppLink(uri, s));
        }
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    final marker = kAppVersionMarker.trim().isEmpty
        ? 'sem APP_VERSION_MARKER'
        : kAppVersionMarker.trim();
    bootTrace('PersonalTrainerApp.initState', 'marker=$marker');
    logLaunch('PersonalTrainerApp.initState marker=$marker');
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setKeepScreenOn(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bootTrace(
        'PersonalTrainerApp.postFrameCallback',
        'agendar _loadServices',
      );
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
      final remoteSync = ModernRemoteSyncService(db, sync);
      _modernSync = remoteSync;
      final repo = AppDataRepository(
        db,
        session,
        remoteSync: remoteSync,
        syncController: sync,
      );
      final deepLink = WorkoutLiveDeepLinkController();
      final bundle = _LoadedServices(
        db: db,
        session: session,
        sync: sync,
        fidelity: fidelity,
        repo: repo,
        remoteSync: remoteSync,
        deepLink: deepLink,
      );
      if (!mounted) return;
      bootTrace('_loadServices', 'AppDatabase + repo OK → setState(services)');
      setState(() {
        _services = bundle;
        _loadError = null;
      });
      unawaited(bundle.repo.applyPremiumTierExpiryDowngrades());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _services != bundle) return;
        _startAppLinks(bundle);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bootTrace('postFrame', 'após services → Supabase/cloud');
        if (!mounted) return;
        unawaited(_initSupabaseThenCloudServices());
      });
    } catch (e, st) {
      bootTrace('_loadServices FAILED', e);
      logLaunch(
        'PersonalTrainerApp._loadServices FAILED',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _initSupabaseThenCloudServices() async {
    final s = _services;
    if (s == null) return;
    bootTrace(
      'initializeSupabaseApp',
      'início (sem timeout — evita corrida com startHeartbeat)',
    );
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
    _authSubscription ??= SupabaseAuthService.onAuthStateChange.listen((_) {
      unawaited(_startAuthenticatedCloudServices());
    });
    await _startAuthenticatedCloudServices();
  }

  Future<void> _startAuthenticatedCloudServices() async {
    final s = _services;
    if (s == null || !mounted || _authenticatedCloudServicesStarted) return;
    // Não iniciar tarefas nativas ou sincronização remota antes do login.
    // Além de evitar chamadas anônimas, isso impede que plugins de áudio e
    // notificações disputem a inicialização da tela de autenticação no iOS.
    if (SupabaseAuthService.currentSession == null) {
      bootTrace('cloud', 'sessão ausente; serviços adiados até o login');
      return;
    }
    _authenticatedCloudServicesStarted = true;
    bootTrace('cloud', 'recover queue + startHeartbeat + RPC sync');
    await s.remoteSync.recoverPendingWork();
    s.sync.startHeartbeat();
    _modernSync?.startPolling();
    unawaited(WorkoutActivityLocalNotifier.instance.ensureInitialized());
    unawaited(RestTimerSound.preload());
  }

  void _retryLoad() {
    final old = _services;
    _cancelAppLinks();
    _authSubscription?.cancel();
    _authSubscription = null;
    _authenticatedCloudServicesStarted = false;
    setState(() {
      _loadError = null;
      _services = null;
      _loadStarted = false;
    });
    if (old != null) {
      _modernSync?.dispose();
      _modernSync = null;
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
    _cancelAppLinks();
    _authSubscription?.cancel();
    _authSubscription = null;
    unawaited(_setKeepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    final s = _services;
    if (s != null) {
      _modernSync?.dispose();
      _modernSync = null;
      s.repo.dispose();
      s.fidelity.dispose();
      s.sync.dispose();
      s.db.close();
    }
    super.dispose();
  }

  /// iOS (cenas / NSUserActivity) pode enviar URLs via canal `pushRouteInformation`.
  /// O [MaterialApp] tentaria `Navigator.pushNamed` com esse URL e falhava → log nativo
  /// «Failed to handle route information in Flutter.» Consumimos o que não é rota nomeada.
  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final pathOnly = uri.path.isEmpty ? '/' : uri.path;
    if (pathOnly == MainShell.routeName ||
        pathOnly == LocalLoginPage.routeName) {
      return false;
    }
    if (uri.scheme == 'apppersonal') {
      final s = _services;
      if (s != null) {
        unawaited(_handleWorkoutAppLink(uri, s));
      }
      return true;
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final s = _services;
      if (s != null && uri.host == 'login-callback') {
        unawaited(_handleWorkoutAppLink(uri, s));
      }
      return true;
    }
    return true;
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
        unawaited(_setKeepScreenOn(true));
        if (SupabaseAuthService.currentSession != null) {
          _modernSync?.startPolling();
          unawaited(WorkoutActivityLocalNotifier.instance.ensureInitialized());
          unawaited(RestTimerSound.preload());
        }
        unawaited(s.repo.applyPremiumTierExpiryDowngrades());
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        unawaited(_setKeepScreenOn(false));
        _modernSync?.stopPolling();
        // Mantém o Realtime ligado em pausa para o aluno continuar a “empurrar”
        // atualizações para personal/admin (SnackBar / notificação). O SO pode
        // suspender o socket; ao [resumed] fazemos [reconnectAfterResume].
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
        ChangeNotifierProvider<RestLiveActivityController>(
          create: (_) => RestLiveActivityController(),
        ),
        ChangeNotifierProvider<WorkoutLiveDeepLinkController>.value(
          value: s.deepLink,
        ),
      ],
      child: MaterialApp(
        title: 'Personal Gym',
        navigatorKey: _rootNavigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => BiometricResumeLock(
          rootNavigatorKey: _rootNavigatorKey,
          child: StudentWorkoutLiveActivityLayer(child: child),
        ),
        home: const SplashPage(),
        routes: {
          MainShell.routeName: (_) => const MainShell(),
          LocalLoginPage.routeName: (_) => const LocalLoginPage(),
          PasswordRecoveryPage.routeName: (_) => const PasswordRecoveryPage(),
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
                'Personal Gym',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.splashMint,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 28),
              ModernLoadingIndicator(size: 52),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.message, required this.onRetry});

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
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
