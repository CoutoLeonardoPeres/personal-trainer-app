import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/access/permission_service.dart';
import '../../core/auth/app_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/app_bottom_nav.dart';
import '../../core/workout/workout_live_deep_link_controller.dart';
import '../../core/widgets/gradient_app_bar.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/mandatory_password_change_scaffold.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../../data/sync/supabase_auto_pull_scheduler.dart';
import '../cadastro/cadastro_hub_page.dart';
import '../calendar/calendar_day_flow.dart';
import '../calendar/calendar_page.dart';
import '../performance/performance_page.dart'
    show AnamneseQuizDialog, PerformancePage;
import '../planning/planning_page.dart';
import '../settings/settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const routeName = '/main';

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MainNavTab _tab = MainNavTab.calendar;
  bool _tabLoading = false;
  var _deepLinkListenerAttached = false;
  WorkoutLiveDeepLinkController? _deepLink;

  /// Um flush de cada vez: vários [notifyListeners] não podem correr [take] + abrir
  /// folha em paralelo (cada um re-pendurava o mesmo id e enfileirava N aberturas).
  Future<void> _workoutDeepLinkFlushChain = Future.value();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deepLink ??= context.read<WorkoutLiveDeepLinkController>();
    if (!_deepLinkListenerAttached) {
      _deepLinkListenerAttached = true;
      _deepLink!.addListener(_onWorkoutDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enqueueWorkoutDeepLinkFlush();
      });
    }
  }

  @override
  void dispose() {
    _deepLink?.removeListener(_onWorkoutDeepLink);
    super.dispose();
  }

  void _onWorkoutDeepLink() {
    _enqueueWorkoutDeepLinkFlush();
  }

  void _enqueueWorkoutDeepLinkFlush() {
    _workoutDeepLinkFlushChain = _workoutDeepLinkFlushChain.then(
      (_) => _flushWorkoutDeepLinkOnce(),
    );
  }

  Future<void> _flushWorkoutDeepLinkOnce() async {
    final c = _deepLink;
    if (c == null || !mounted) return;
    final req = c.takePendingRequest();
    if (req == null) return;
    await _select(MainNavTab.calendar);
    if (!mounted) return;
    final repo = context.read<AppDataRepository>();
    await CalendarDayFlow.openDayWorkoutSheetById(
      context,
      repo,
      req.dayWorkoutId,
      preferRestTimerOverlay: req.preferRestTimerOverlay,
    );
  }

  Future<void> _select(MainNavTab tab) async {
    if (tab == _tab) return;
    setState(() => _tabLoading = true);
    await context.read<AppDataRepository>().warmUp();
    if (!mounted) return;
    setState(() {
      _tab = tab;
      _tabLoading = false;
    });
    // [IndexedStack] mantém separadores montados off-screen: ao voltar ao separador,
    // força importação da nuvem (calendário + planejamento alinhados iPhone/tablet).
    if (mounted &&
        (tab == MainNavTab.calendar || tab == MainNavTab.planning)) {
      final db = context.read<AppDatabase>();
      final sync = context.read<SupabaseSyncController>();
      final session = context.read<AppSession>();
      SupabaseAutoPullScheduler.scheduleAfterResume(
        db: db,
        sync: sync,
        session: session,
        delay: Duration.zero,
        bypassMinInterval: true,
      );
    }
  }

  String _title(MainNavTab t) => switch (t) {
    MainNavTab.performance => 'Performance',
    MainNavTab.calendar => 'Calendário',
    MainNavTab.planning => 'Planejamento',
    MainNavTab.cadastro => 'Cadastro',
  };

  List<MainNavTab> _orderedTabs(PermissionService perm) => [
    if (perm.canOpenPerformanceTab) MainNavTab.performance,
    MainNavTab.calendar,
    if (perm.canOpenPlanningTab) MainNavTab.planning,
    if (perm.canOpenCadastroTab) MainNavTab.cadastro,
  ];

  Widget _buildMainContent(
    BuildContext context,
    AppDataRepository repo,
    PermissionService perm,
    List<MainNavTab> tabs,
  ) {
    if (!tabs.contains(_tab) && tabs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = tabs.first);
      });
    }
    final ix = tabs.indexOf(_tab);
    final useIndex = ix >= 0 ? ix : 0;

    final children = <Widget>[
      if (perm.canOpenPerformanceTab) const PerformancePage(),
      const CalendarPage(),
      if (perm.canOpenPlanningTab) const PlanningPage(),
      if (perm.canOpenCadastroTab) const CadastroHubPage(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: buildGradientAppBar(
        automaticallyImplyLeading: false,
        centerTitleInToolbar: true,
        title: Text(_title(_tab)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FuturisticBackground(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      AppBottomNav.barHeight,
                ),
                child: IndexedStack(
                  index: useIndex.clamp(0, children.length - 1),
                  children: children,
                ),
              ),
            ),
          ),
          if (_tabLoading) const FuturisticLoadingOverlay(indicatorSize: 72),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        tabsInOrder: tabs,
        selected: tabs.contains(_tab) ? _tab : tabs.first,
        onSelect: (t) {
          if (!tabs.contains(t)) return;
          unawaited(_select(t));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final repo = context.watch<AppDataRepository>();

    if (session.isStudent && session.studentId != null) {
      return StreamBuilder<StudentEntity?>(
        stream: repo.watchStudentById(session.studentId!),
        builder: (context, snap) {
          final stu = snap.data;
          if (stu == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: FuturisticLoadingView(size: 56),
                ),
              );
            }
            return const Scaffold(
              body: Center(child: Text('Aluno não encontrado.')),
            );
          }
          final perms = PermissionService(session: session, student: stu);
          if (perms.mustBlockAppForAnamnese) {
            return PopScope(
              canPop: false,
              child: Scaffold(
                backgroundColor: AppColors.background,
                body: FuturisticBackground(
                  child: SafeArea(
                    child:
                        FutureBuilder<
                          List<({DateTime at, Map<String, String> answers})>
                        >(
                          future: repo.studentAnamneseHistory(
                            studentId: stu.id,
                            limit: 1,
                          ),
                          builder: (context, h) {
                            final init = h.data?.isNotEmpty == true
                                ? h.data!.first.answers
                                : const <String, String>{};
                            return AnamneseQuizDialog(
                              repo: repo,
                              studentId: stu.id,
                              studentName: stu.name,
                              initialAnswers: init,
                              embedded: true,
                              mandatory: true,
                            );
                          },
                        ),
                  ),
                ),
              ),
            );
          }
          if (stu.mustChangePassword) {
            return MandatoryPasswordChangeScaffold(repo: repo);
          }
          final tabs = _orderedTabs(perms);
          return _buildMainContent(context, repo, perms, tabs);
        },
      );
    }

    if (session.isPersonalTrainer && session.personalId != null) {
      return StreamBuilder<PersonalEntity?>(
        stream: repo.watchPersonalById(session.personalId!),
        builder: (context, snap) {
          final p = snap.data;
          final perms = PermissionService(session: session, personal: p);
          final tabs = _orderedTabs(perms);
          return _buildMainContent(context, repo, perms, tabs);
        },
      );
    }

    final perms = PermissionService(session: session);
    final tabs = _orderedTabs(perms);
    return _buildMainContent(context, repo, perms, tabs);
  }
}
