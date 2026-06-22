import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../../data/sync/supabase_auto_pull_scheduler.dart';
import 'calendar_day_flow.dart';

/// Preenchimento das datas com treino — bem translúcido para o fundo aparecer.
Color _tint(Color base) => base.withValues(alpha: 0.24);

/// Calendário mensal em carrossel (PageView), alinhado ao [HomePage] do App_Calendar.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final PageController _pageController;
  late int _currentPageIndex;
  late DateTime _currentDate;
  late DateTime _selectedDay;
  var _dayTapInFlight = false;

  static final _reference = DateTime(2000, 1, 1);

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentPageIndex =
        (now.year - _reference.year) * 12 + (now.month - _reference.month);
    _currentDate = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _pageController = PageController(initialPage: _currentPageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      final sync = context.read<SupabaseSyncController>();
      final session = context.read<AppSession>();
      SupabaseAutoPullScheduler.scheduleAfterResume(
        db: db,
        sync: sync,
        session: session,
        delay: const Duration(milliseconds: 500),
        bypassMinInterval: true,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateFromPageIndex(int pageIndex) {
    final totalMonths = pageIndex;
    final year = _reference.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    return DateTime(year, month, 1);
  }

  void _changeMonth(int delta) {
    _pageController.animateToPage(
      _currentPageIndex + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isToday(DateTime date) {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Cor semântica do treino naquele dia (ícone e fundo quando não é hoje).
  /// Passado: verde só concluídos, vermelho se ainda há pendência.
  /// Futuro: azul se há programado/iniciado/agendado.
  /// Hoje: usa-se só para o ícone (fundo sempre branco).
  Color? _workoutAccentForDay(
    DateTime date,
    List<DayWorkoutEntity> list, {
    required bool includeCancelled,
  }) {
    final active = includeCancelled
        ? list
        : list.where((w) => w.status != 'cancelled').toList();
    if (active.isEmpty) return null;

    final day = _dateOnly(date);
    final today = _dateOnly(DateTime.now());

    final hasIncomplete = active.any(
      (w) =>
          w.status == 'programmed' ||
          w.status == 'started' ||
          w.status == 'scheduled',
    );
    final hasCompleted = active.any((w) => w.status == 'completed');

    if (day.isBefore(today)) {
      if (hasIncomplete) return AppColors.calendarIncomplete;
      if (hasCompleted) return AppColors.accentGreen;
      return null;
    }
    if (day.isAfter(today)) {
      if (hasIncomplete) return AppColors.calendarFutureProgrammed;
      if (hasCompleted) return AppColors.accentGreen;
      return null;
    }
    // Hoje
    if (hasIncomplete) return AppColors.calendarIncomplete;
    if (hasCompleted) return AppColors.accentGreen;
    return null;
  }

  bool _isCurrentMonthForDate(DateTime date, DateTime monthDate) =>
      date.year == monthDate.year && date.month == monthDate.month;

  bool _isCalendarShowingCurrentMonth() {
    final n = DateTime.now();
    return _currentDate.year == n.year && _currentDate.month == n.month;
  }

  String _monthTitle(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.year}';

  List<DateTime> _daysInMonth(DateTime monthStart) {
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final firstDayWeekday = firstDay.weekday;
    final days = <DateTime>[];
    // Segunda-feira como primeiro dia da grade (igual ao app de referência).
    final daysBefore = firstDayWeekday - 1;
    for (var i = daysBefore - 1; i >= 0; i--) {
      days.add(firstDay.subtract(Duration(days: i + 1)));
    }
    for (var day = 1; day <= lastDay.day; day++) {
      days.add(DateTime(monthStart.year, monthStart.month, day));
    }
    while (days.length < 42) {
      days.add(days.last.add(const Duration(days: 1)));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final isAdmin = repo.session.hasFullOrgAccess;
    final showCurrent = _isCalendarShowingCurrentMonth();
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final rangeEnd = DateTime(_currentDate.year, _currentDate.month + 1, 1);

    return StreamBuilder<List<DayWorkoutEntity>>(
      stream: repo.watchWorkoutsBetween(monthStart, rangeEnd),
      builder: (context, snap) {
        final workouts = snap.data ?? const <DayWorkoutEntity>[];
        final byDay = <String, List<DayWorkoutEntity>>{};
        for (final w in workouts) {
          final cal = weekScheduleLocalCalendarDate(w.dayDate);
          final k = '${cal.year}-${cal.month}-${cal.day}';
          byDay.putIfAbsent(k, () => []).add(w);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.accentPink, AppColors.accentGreen],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.calendar_today,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Calendário',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: showCurrent
                              ? AppColors.accentGreen.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: showCurrent
                                ? AppColors.accentGreen.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _monthTitle(_currentDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: showCurrent
                                ? AppColors.accentGreen
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Seg',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Ter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Qua',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Qui',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Sex',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Sáb',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Dom',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.accentGreen, height: 1),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                    _currentDate = _dateFromPageIndex(index);
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final db = context.read<AppDatabase>();
                    final sync = context.read<SupabaseSyncController>();
                    final session = context.read<AppSession>();
                    SupabaseAutoPullScheduler.scheduleAfterResume(
                      db: db,
                      sync: sync,
                      session: session,
                      delay: const Duration(milliseconds: 400),
                      bypassMinInterval: true,
                    );
                  });
                },
                itemBuilder: (context, index) {
                  final monthDate = _dateFromPageIndex(index);
                  final days = _daysInMonth(monthDate);
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: days.length,
                    itemBuilder: (context, i) {
                      final date = days[i];
                      final inMonth = _isCurrentMonthForDate(date, monthDate);
                      final today = _isToday(date);
                      final selected = _isSameDay(date, _selectedDay);
                      final key = '${date.year}-${date.month}-${date.day}';
                      final dayList = byDay[key] ?? const [];
                      final activeList = isAdmin
                          ? dayList
                          : dayList
                                .where((w) => w.status != 'cancelled')
                                .toList();
                      final hasWork = inMonth && activeList.isNotEmpty;
                      final accent = activeList.isEmpty
                          ? null
                          : _workoutAccentForDay(
                              date,
                              dayList,
                              includeCancelled: isAdmin,
                            );

                      final borderColor = today
                          ? Colors.white.withValues(alpha: 0.75)
                          : selected
                          ? AppColors.accentGreen.withValues(alpha: 0.85)
                          : (hasWork && accent != null)
                          ? accent.withValues(alpha: 0.5)
                          : Colors.transparent;
                      final borderWidth =
                          today || selected || (hasWork && accent != null)
                          ? 2.0
                          : 0.0;

                      Widget dayBackground;
                      if (today) {
                        dayBackground = ColoredBox(
                          color: Colors.white.withValues(alpha: 0.42),
                        );
                      } else if (hasWork && accent != null) {
                        dayBackground = ColoredBox(color: _tint(accent));
                      } else {
                        dayBackground = const ColoredBox(
                          color: Colors.transparent,
                        );
                      }

                      return GestureDetector(
                        onTap: () async {
                          if (!inMonth) return;
                          if (_dayTapInFlight) return;
                          _dayTapInFlight = true;
                          setState(() => _selectedDay = date);
                          try {
                            await CalendarDayFlow.open(context, date, dayList);
                          } finally {
                            _dayTapInFlight = false;
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: borderColor,
                              width: borderWidth,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              dayBackground,
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      color: today
                                          ? Colors.black87
                                          : inMonth
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                      fontWeight: today || selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 16,
                                      shadows: [
                                        if (today)
                                          const Shadow(
                                            blurRadius: 3,
                                            color: Color(0x99000000),
                                          )
                                        else
                                          const Shadow(
                                            blurRadius: 3,
                                            color: Color(0x88000000),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (hasWork && accent != null)
                                    Icon(
                                      Icons.fitness_center,
                                      size: 12,
                                      color: today
                                          ? accent.withValues(alpha: 0.92)
                                          : accent.withValues(alpha: 0.82),
                                      shadows: [
                                        if (today)
                                          Shadow(
                                            blurRadius: 2,
                                            color: accent.withValues(
                                              alpha: 0.35,
                                            ),
                                          )
                                        else
                                          const Shadow(
                                            blurRadius: 2,
                                            color: Color(0x88000000),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
