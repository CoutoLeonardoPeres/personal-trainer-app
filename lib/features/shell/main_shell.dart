import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/app_bottom_nav.dart';
import '../../core/workout/workout_live_deep_link_controller.dart';
import '../../core/widgets/gradient_app_bar.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/modern_loading.dart';
import '../../data/repositories/app_data_repository.dart';
import '../cadastro/cadastro_hub_page.dart';
import '../calendar/calendar_day_flow.dart';
import '../calendar/calendar_page.dart';
import '../performance/performance_page.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deepLink ??= context.read<WorkoutLiveDeepLinkController>();
    if (!_deepLinkListenerAttached) {
      _deepLinkListenerAttached = true;
      _deepLink!.addListener(_onWorkoutDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_flushWorkoutDeepLink());
      });
    }
  }

  @override
  void dispose() {
    _deepLink?.removeListener(_onWorkoutDeepLink);
    super.dispose();
  }

  void _onWorkoutDeepLink() {
    unawaited(_flushWorkoutDeepLink());
  }

  Future<void> _flushWorkoutDeepLink() async {
    final c = _deepLink;
    if (c == null || !mounted) return;
    final id = c.takePendingWorkoutId();
    if (id == null) return;
    await _select(MainNavTab.calendar);
    if (!mounted) return;
    final repo = context.read<AppDataRepository>();
    await CalendarDayFlow.openDayWorkoutSheetById(context, repo, id);
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
  }

  String _title(MainNavTab t) => switch (t) {
        MainNavTab.performance => 'Performance',
        MainNavTab.calendar => 'Calendário',
        MainNavTab.planning => 'Planejamento',
        MainNavTab.cadastro => 'Cadastro',
      };

  @override
  Widget build(BuildContext context) {
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
                  bottom: MediaQuery.paddingOf(context).bottom +
                      AppBottomNav.barHeight,
                ),
                child: IndexedStack(
                  index: _tab.index,
                  children: const [
                    PerformancePage(),
                    CalendarPage(),
                    PlanningPage(),
                    CadastroHubPage(),
                  ],
                ),
              ),
            ),
          ),
          if (_tabLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ModernLoadingIndicator(size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Atualizando…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selected: _tab,
        onSelect: _select,
      ),
    );
  }
}
