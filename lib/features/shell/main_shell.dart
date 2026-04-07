import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/app_bottom_nav.dart';
import '../../core/widgets/gradient_app_bar.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/widgets/supabase_traffic_indicator.dart';
import '../../data/repositories/app_data_repository.dart';
import '../cadastro/cadastro_hub_page.dart';
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
  static const _prefNavTabIndex = 'main_shell_nav_tab_index';

  MainNavTab _tab = MainNavTab.calendar;
  bool _tabLoading = false;

  @override
  void initState() {
    super.initState();
    _restoreTabFromPrefs();
  }

  Future<void> _restoreTabFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    final i = p.getInt(_prefNavTabIndex);
    if (!mounted) return;
    if (i != null &&
        i >= 0 &&
        i < MainNavTab.values.length &&
        i != _tab.index) {
      setState(() => _tab = MainNavTab.values[i]);
    }
  }

  Future<void> _persistTab(MainNavTab tab) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefNavTabIndex, tab.index);
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
    await _persistTab(tab);
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
        showSupabaseTrafficIndicator: false,
        leading: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SupabaseTrafficIndicator(),
          ),
        ),
        leadingWidth: 68,
        automaticallyImplyLeading: false,
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
