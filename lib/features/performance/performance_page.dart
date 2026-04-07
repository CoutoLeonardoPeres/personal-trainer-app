import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ai/free_ai_training_report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';
import '../planning/planning_student_selector.dart';

/// Gráficos em carrossel horizontal por aluno.
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final PageController _chartPage = PageController();
  String? _studentId;

  @override
  void dispose() {
    _chartPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<StudentEntity>>(
            stream: repo.watchStudentsAlphabetical(),
            builder: (context, snap) {
              final students = snap.data ?? [];
              final waitingFirstStudents =
                  snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData;

              if (_studentId != null &&
                  students.isNotEmpty &&
                  !students.any((s) => s.id == _studentId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _studentId = null);
                });
              }
              if (_studentId != null && students.isEmpty && snap.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _studentId = null);
                });
              }
              if (_studentId != null &&
                  students.isEmpty &&
                  waitingFirstStudents) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final dropdownValue =
                  _studentId != null && students.any((s) => s.id == _studentId)
                      ? _studentId
                      : null;

              return PlanningFuturisticStudentSelector(
                key: ValueKey('aluno_${dropdownValue ?? 'none'}'),
                students: students,
                selectedId: dropdownValue,
                enabled: students.isNotEmpty,
                onChanged: (v) => setState(() => _studentId = v),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _chartPage,
            children: [
              _chartCard(
                'Rendimento (últimos 7 treinos)',
                _subtitleRendimento,
                _studentId == null
                    ? _selectStudentPlaceholder(hint: 'o rendimento')
                    : _RendimentoChart(studentId: _studentId!, repo: repo),
              ),
              _chartCard(
                'Três subidas seguidas (até 10 treinos)',
                _subtitleStreakIncreases,
                _studentId == null
                    ? _selectStudentPlaceholder(hint: 'as sequências de subida')
                    : _StreakIncreasesChart(studentId: _studentId!, repo: repo),
              ),
              _chartCard(
                'Melhor score por grupo (4 semanas)',
                _subtitleGroups4Weeks,
                _studentId == null
                    ? _selectStudentPlaceholder(hint: 'o ranking por grupo')
                    : _WorkoutGroupsBest4WeeksChart(studentId: _studentId!, repo: repo),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Deslize para os lados para mais gráficos',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _FuturisticReportButton(
                  enabled: _studentId != null,
                  onPressed: _studentId == null
                      ? null
                      : () => _openReportSheet(
                            context: context,
                            repo: repo,
                            studentId: _studentId!,
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FuturisticAnamneseButton(
                  enabled: _studentId != null,
                  onPressed: _studentId == null
                      ? null
                      : () => _openAnamneseSheet(
                            context: context,
                            repo: repo,
                            studentId: _studentId!,
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _subtitleRendimento =
      'Score por minuto ativo = soma dos scores dos exercícios ÷ tempo de treino em minutos.';

  static const _subtitleStreakIncreases =
      'Treinos em que o score por minuto foi maior que nos 3 anteriores, em sequência (4 treinos com valores estritamente crescentes). Até as 10 ocorrências mais recentes.';

  static const _subtitleGroups4Weeks =
      'Para cada grupo de treino usado no calendário, o melhor score por minuto entre as sessões concluídas nos últimos 28 dias. Barras ordenadas do maior para o menor (até 15 grupos).';

  Widget _selectStudentPlaceholder({String hint = 'os gráficos'}) {
    return Center(
      child: Text(
        'Selecione um aluno para ver $hint.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
      ),
    );
  }

  Widget _chartCard(String title, String? subtitle, Widget chart) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.45)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportSheet({
    required BuildContext context,
    required AppDataRepository repo,
    required String studentId,
  }) async {
    final student = await repo.getStudentById(studentId);
    if (!context.mounted) return;
    final studentName = student?.name ?? 'Aluno';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PerformanceReportSheet(
        repo: repo,
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }

  Future<void> _openAnamneseSheet({
    required BuildContext context,
    required AppDataRepository repo,
    required String studentId,
  }) async {
    final student = await repo.getStudentById(studentId);
    if (!context.mounted) return;
    final studentName = student?.name ?? 'Aluno';
    final history = await repo.studentAnamneseHistory(
      studentId: studentId,
      limit: 1,
    );
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AnamneseQuizDialog(
        repo: repo,
        studentId: studentId,
        studentName: studentName,
        initialAnswers: history.isNotEmpty ? history.first.answers : const {},
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questionário de anamnese salvo.')),
      );
    }
  }

}

class _RendimentoChart extends StatelessWidget {
  const _RendimentoChart({
    required this.studentId,
    required this.repo,
  });

  final String studentId;
  final AppDataRepository repo;

  static String _fmtY(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<({DateTime completedAt, double scorePerMinute})>>(
      key: ValueKey(studentId),
      future: repo.lastCompletedWorkoutRendimentoSeries(studentId: studentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentGreen),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Não foi possível carregar: ${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade200, fontSize: 13),
              ),
            ),
          );
        }
        final points = snap.data ?? [];
        if (points.isEmpty) {
          return Center(
            child: Text(
              'Ainda não há treinos concluídos para este aluno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
            ),
          );
        }

        final spots = <FlSpot>[
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].scorePerMinute),
        ];
        final maxY = points
            .map((p) => p.scorePerMinute)
            .reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxY * 1.15).clamp(1.0, double.infinity);
        final dateFmt = DateFormat('d/M');

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
            minY: 0,
            maxY: chartMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: chartMaxY > 5 ? chartMaxY / 4 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: chartMaxY > 5 ? chartMaxY / 4 : null,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value > chartMaxY * 1.01) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      _fmtY(value),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFmt.format(points[i].completedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: AppColors.accentGreen,
                barWidth: 3,
                isCurved: points.length > 2,
                curveSmoothness: 0.22,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, i) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.accentGreen,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((t) {
                    final i = t.x.round();
                    if (i < 0 || i >= points.length) return null;
                    final p = points[i];
                    return LineTooltipItem(
                      '${dateFmt.format(p.completedAt)}\n'
                      '${_fmtY(p.scorePerMinute)} / min',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreakIncreasesChart extends StatelessWidget {
  const _StreakIncreasesChart({
    required this.studentId,
    required this.repo,
  });

  final String studentId;
  final AppDataRepository repo;

  static String _fmtY(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<({DateTime completedAt, double scorePerMinute})>>(
      key: ValueKey('streak_$studentId'),
      future: repo.lastWorkoutsWithThreeConsecutiveScoreIncreases(studentId: studentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentPink),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Não foi possível carregar: ${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade200, fontSize: 13),
              ),
            ),
          );
        }
        final points = snap.data ?? [];
        if (points.isEmpty) {
          return Center(
            child: Text(
              'Ainda não há treinos que encerrem uma sequência de 3 subidas seguidas do score por minuto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
            ),
          );
        }

        final maxY = points
            .map((p) => p.scorePerMinute)
            .reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxY * 1.15).clamp(1.0, double.infinity);
        final dateFmt = DateFormat('d/M');
        final n = points.length;
        final barWidth = n <= 4 ? 22.0 : (n <= 7 ? 16.0 : 12.0);

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: chartMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: chartMaxY > 5 ? chartMaxY / 4 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: chartMaxY > 5 ? chartMaxY / 4 : null,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value > chartMaxY * 1.01) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      _fmtY(value),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFmt.format(points[i].completedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].scorePerMinute,
                      color: AppColors.accentPink.withValues(alpha: 0.85),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x;
                  if (i < 0 || i >= points.length) return null;
                  final p = points[i];
                  return BarTooltipItem(
                    '${dateFmt.format(p.completedAt)}\n'
                    '${_fmtY(p.scorePerMinute)} / min',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkoutGroupsBest4WeeksChart extends StatelessWidget {
  const _WorkoutGroupsBest4WeeksChart({
    required this.studentId,
    required this.repo,
  });

  final String studentId;
  final AppDataRepository repo;

  static String _fmtY(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  static String _shortGroupLabel(String name, int maxChars) {
    final t = name.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        List<({String groupId, String groupName, double bestScorePerMinute})>>(
      key: ValueKey('groups4w_$studentId'),
      future: repo.workoutGroupsBestRendimentoLast4Weeks(studentId: studentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.splashMint,
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Não foi possível carregar: ${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade200, fontSize: 13),
              ),
            ),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'Não há treinos concluídos vinculados a um grupo de treino nos últimos 28 dias.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
            ),
          );
        }

        final maxY = rows
            .map((r) => r.bestScorePerMinute)
            .reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxY * 1.15).clamp(1.0, double.infinity);
        final n = rows.length;
        final barWidth = n <= 5 ? 20.0 : (n <= 10 ? 14.0 : 10.0);
        final labelMaxChars = n > 10 ? 5 : (n > 6 ? 6 : 8);
        final bottomReserved = n > 10 ? 34.0 : 30.0;

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: chartMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: chartMaxY > 5 ? chartMaxY / 4 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: chartMaxY > 5 ? chartMaxY / 4 : null,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value > chartMaxY * 1.01) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      _fmtY(value),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomReserved,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _shortGroupLabel(rows[i].groupName, labelMaxChars),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: n > 10 ? 8 : 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < rows.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: rows[i].bestScorePerMinute,
                      color: AppColors.splashMint.withValues(alpha: 0.88),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x;
                  if (i < 0 || i >= rows.length) return null;
                  final r = rows[i];
                  return BarTooltipItem(
                    '${r.groupName}\n'
                    'Melhor: ${_fmtY(r.bestScorePerMinute)} / min',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FuturisticReportButton extends StatelessWidget {
  const _FuturisticReportButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFF26C6DA), AppColors.accentPink]
                  : [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.accentPink.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
            border: Border.all(
              color: enabled
                  ? AppColors.splashMint.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: enabled
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Text(
                'Relatório',
                style: TextStyle(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuturisticAnamneseButton extends StatelessWidget {
  const _FuturisticAnamneseButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFF7E57C2), Color(0xFF26C6DA)]
                  : [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF7E57C2).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
            border: Border.all(
              color: enabled
                  ? AppColors.splashMint.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fact_check_rounded,
                color: enabled
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Text(
                'Anamnese',
                style: TextStyle(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AnamneseAnswerKind {
  single,
  multi,
  text,
  number,
  date,
}

class _AnamneseQuestion {
  const _AnamneseQuestion({
    required this.section,
    required this.prompt,
    required this.kind,
    this.options = const [],
    this.required = true,
    this.showWhenPromptEquals,
    this.showWhenValueEquals,
  });

  final String section;
  final String prompt;
  final _AnamneseAnswerKind kind;
  final List<String> options;
  final bool required;
  final String? showWhenPromptEquals;
  final String? showWhenValueEquals;
}

const List<_AnamneseQuestion> _kAnamneseQuestions = [
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Data de nascimento', kind: _AnamneseAnswerKind.date),
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Gênero', kind: _AnamneseAnswerKind.single, options: ['Masculino', 'Feminino', 'Prefiro não informar', 'Outro']),
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Altura (m)', kind: _AnamneseAnswerKind.number),
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Peso atual (kg)', kind: _AnamneseAnswerKind.number),
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Profissão', kind: _AnamneseAnswerKind.text),
  _AnamneseQuestion(section: 'SEÇÃO 1 — DADOS BÁSICOS E ROTINA', prompt: 'Como é sua rotina diária?', kind: _AnamneseAnswerKind.single, options: ['Sedentária', 'Moderadamente ativa', 'Ativa', 'Muito ativa']),

  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Possui ou já teve alguma lesão muscular, articular ou óssea?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Não']),
  _AnamneseQuestion(
    section: 'SEÇÃO 2 — SAÚDE E LESÕES',
    prompt: 'Se sim, qual lesão?',
    kind: _AnamneseAnswerKind.text,
    required: false,
    showWhenPromptEquals:
        'Possui ou já teve alguma lesão muscular, articular ou óssea?',
    showWhenValueEquals: 'Sim',
  ),
  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Possui limitação física ou condição médica diagnosticada?', kind: _AnamneseAnswerKind.multi, options: ['Nenhuma', 'Coluna', 'Joelhos', 'Coração', 'Hipertensão', 'Diabetes', 'Outras']),
  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Usa medicação contínua?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Não']),
  _AnamneseQuestion(
    section: 'SEÇÃO 2 — SAÚDE E LESÕES',
    prompt: 'Se sim, qual medicação?',
    kind: _AnamneseAnswerKind.text,
    required: false,
    showWhenPromptEquals: 'Usa medicação contínua?',
    showWhenValueEquals: 'Sim',
  ),
  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Como avalia o nível atual de saúde geral?', kind: _AnamneseAnswerKind.single, options: ['Muito bom', 'Bom', 'Regular', 'Ruim']),
  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Dorme bem?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Às vezes', 'Raramente', 'Tenho insônia']),
  _AnamneseQuestion(section: 'SEÇÃO 2 — SAÚDE E LESÕES', prompt: 'Pratica outra atividade física além da musculação?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Não']),
  _AnamneseQuestion(
    section: 'SEÇÃO 2 — SAÚDE E LESÕES',
    prompt: 'Se sim, qual outra atividade?',
    kind: _AnamneseAnswerKind.text,
    required: false,
    showWhenPromptEquals: 'Pratica outra atividade física além da musculação?',
    showWhenValueEquals: 'Sim',
  ),

  _AnamneseQuestion(section: 'SEÇÃO 3 — EXPERIÊNCIA E NÍVEL ATUAL', prompt: 'Já praticou musculação ou treinos físicos antes?', kind: _AnamneseAnswerKind.single, options: ['Nunca', 'Já treinei, mas faz tempo', '< 6 meses', '> 6 meses', '> 2 anos']),
  _AnamneseQuestion(section: 'SEÇÃO 3 — EXPERIÊNCIA E NÍVEL ATUAL', prompt: 'Como avalia o condicionamento físico atual?', kind: _AnamneseAnswerKind.single, options: ['Iniciante', 'Intermediário', 'Avançado']),
  _AnamneseQuestion(section: 'SEÇÃO 3 — EXPERIÊNCIA E NÍVEL ATUAL', prompt: 'Quantos dias por semana consegue treinar?', kind: _AnamneseAnswerKind.single, options: ['1', '2', '3', '4', '5', '6+']),
  _AnamneseQuestion(section: 'SEÇÃO 3 — EXPERIÊNCIA E NÍVEL ATUAL', prompt: 'Qual horário prefere treinar?', kind: _AnamneseAnswerKind.single, options: ['Manhã', 'Tarde', 'Noite', 'Varia conforme o dia']),

  _AnamneseQuestion(section: 'SEÇÃO 4 — OBJETIVOS E MOTIVAÇÃO', prompt: 'Principal objetivo', kind: _AnamneseAnswerKind.single, options: ['Emagrecimento', 'Ganho de massa', 'Definição', 'Condicionamento', 'Reabilitação', 'Postura', 'Redução de estresse', 'Outro']),
  _AnamneseQuestion(section: 'SEÇÃO 4 — OBJETIVOS E MOTIVAÇÃO', prompt: 'Parte do corpo que mais gostaria de desenvolver', kind: _AnamneseAnswerKind.multi, options: ['Braços', 'Peito', 'Costas', 'Abdômen', 'Pernas', 'Glúteos', 'Ombros', 'Corpo inteiro']),
  _AnamneseQuestion(section: 'SEÇÃO 4 — OBJETIVOS E MOTIVAÇÃO', prompt: 'O que mais motiva a treinar?', kind: _AnamneseAnswerKind.multi, options: ['Estética', 'Saúde', 'Desempenho', 'Superação', 'Acompanhamento', 'Estilo de vida']),
  _AnamneseQuestion(section: 'SEÇÃO 4 — OBJETIVOS E MOTIVAÇÃO', prompt: 'O que desmotiva?', kind: _AnamneseAnswerKind.multi, options: ['Falta de resultados', 'Falta de tempo', 'Treinos repetitivos', 'Dores', 'Falta de acompanhamento', 'Treinar sozinho']),
  _AnamneseQuestion(section: 'SEÇÃO 4 — OBJETIVOS E MOTIVAÇÃO', prompt: 'Deseja acompanhamento nutricional?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Não', 'Talvez futuramente']),

  _AnamneseQuestion(section: 'SEÇÃO 5 — HÁBITOS E ESTILO DE VIDA', prompt: 'Como é sua alimentação?', kind: _AnamneseAnswerKind.single, options: ['Equilibrada', 'Mediana', 'Irregular', 'Tentando melhorar']),
  _AnamneseQuestion(section: 'SEÇÃO 5 — HÁBITOS E ESTILO DE VIDA', prompt: 'Consome bebidas alcoólicas?', kind: _AnamneseAnswerKind.single, options: ['Não', 'Raramente', 'Socialmente', 'Frequentemente']),
  _AnamneseQuestion(section: 'SEÇÃO 5 — HÁBITOS E ESTILO DE VIDA', prompt: 'Fuma ou já fumou?', kind: _AnamneseAnswerKind.single, options: ['Nunca', 'Já fumei, parei', 'Fumo atualmente']),
  _AnamneseQuestion(section: 'SEÇÃO 5 — HÁBITOS E ESTILO DE VIDA', prompt: 'Nível de estresse atual', kind: _AnamneseAnswerKind.single, options: ['Baixo', 'Moderado', 'Alto']),
  _AnamneseQuestion(section: 'SEÇÃO 5 — HÁBITOS E ESTILO DE VIDA', prompt: 'Como descreve o sono?', kind: _AnamneseAnswerKind.single, options: ['Durmo bem', 'Acordo cansado', 'Dificuldade para dormir', 'Acordo várias vezes']),

  _AnamneseQuestion(section: 'SEÇÃO 6 — PERFIL DE TREINO E PREFERÊNCIAS', prompt: 'Onde pretende treinar?', kind: _AnamneseAnswerKind.single, options: ['Academia', 'Casa', 'Ao ar livre', 'Outro']),
  _AnamneseQuestion(section: 'SEÇÃO 6 — PERFIL DE TREINO E PREFERÊNCIAS', prompt: 'Tem acesso a equipamentos?', kind: _AnamneseAnswerKind.single, options: ['Sim, academia completa', 'Alguns em casa', 'Não, só peso corporal']),
  _AnamneseQuestion(section: 'SEÇÃO 6 — PERFIL DE TREINO E PREFERÊNCIAS', prompt: 'Que tipo de treino prefere?', kind: _AnamneseAnswerKind.single, options: ['Musculação', 'Funcional', 'HIIT', 'Alongamento', 'Misto', 'Outro']),
  _AnamneseQuestion(section: 'SEÇÃO 6 — PERFIL DE TREINO E PREFERÊNCIAS', prompt: 'Gosta de acompanhar métricas e resultados?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Às vezes', 'Não']),
  _AnamneseQuestion(section: 'SEÇÃO 6 — PERFIL DE TREINO E PREFERÊNCIAS', prompt: 'Gostaria de plano alimentar ou desafios motivacionais?', kind: _AnamneseAnswerKind.single, options: ['Sim', 'Dicas básicas', 'Só o treino']),

  _AnamneseQuestion(section: 'SEÇÃO 7 — PERSONALIZAÇÃO FINAL', prompt: 'Descreva o corpo/resultado que gostaria de atingir', kind: _AnamneseAnswerKind.text),
  _AnamneseQuestion(section: 'SEÇÃO 7 — PERSONALIZAÇÃO FINAL', prompt: 'Existe algo que gostaria que o treinador soubesse?', kind: _AnamneseAnswerKind.text, required: false),
  _AnamneseQuestion(section: 'SEÇÃO 7 — PERSONALIZAÇÃO FINAL', prompt: 'Deseja treinos mais', kind: _AnamneseAnswerKind.single, options: ['Intensos', 'Moderados', 'Leves / progressivos']),
  _AnamneseQuestion(section: 'SEÇÃO 7 — PERSONALIZAÇÃO FINAL', prompt: 'Quanto tempo pretende manter o acompanhamento?', kind: _AnamneseAnswerKind.single, options: ['1 mês', '3 meses', '6 meses', 'Indefinido / longo prazo']),
];

class _AnamneseQuizDialog extends StatefulWidget {
  const _AnamneseQuizDialog({
    required this.repo,
    required this.studentId,
    required this.studentName,
    required this.initialAnswers,
  });

  final AppDataRepository repo;
  final String studentId;
  final String studentName;
  final Map<String, String> initialAnswers;

  @override
  State<_AnamneseQuizDialog> createState() => _AnamneseQuizDialogState();
}

class _AnamneseQuizDialogState extends State<_AnamneseQuizDialog> {
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  var _index = 0;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _answers.addAll(widget.initialAnswers);
    for (final q in _kAnamneseQuestions) {
      if (q.kind == _AnamneseAnswerKind.text ||
          q.kind == _AnamneseAnswerKind.number ||
          q.kind == _AnamneseAnswerKind.date) {
        _textControllers[q.prompt] = TextEditingController(
          text: _answers[q.prompt] ?? '',
        );
      }
    }
    _syncCalculatedAge();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Set<String> _multiSelected(String prompt) {
    final raw = (_answers[prompt] ?? '').trim();
    if (raw.isEmpty) return <String>{};
    return raw
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  bool _shouldShow(_AnamneseQuestion q) {
    final parent = q.showWhenPromptEquals;
    final expected = q.showWhenValueEquals;
    if (parent == null || expected == null) return true;
    return (_answers[parent] ?? '').trim() == expected;
  }

  List<_AnamneseQuestion> get _visibleQuestions =>
      _kAnamneseQuestions.where(_shouldShow).toList();

  DateTime? _parseBirthDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(t);
    } catch (_) {
      return null;
    }
  }

  int _calculateAge(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final hadBirthdayThisYear =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) age--;
    return age < 0 ? 0 : age;
  }

  void _syncCalculatedAge() {
    final birth = _parseBirthDate(_answers['Data de nascimento'] ?? '');
    if (birth == null) {
      _answers.remove('Idade (calculada)');
      return;
    }
    final age = _calculateAge(birth, DateTime.now());
    _answers['Idade (calculada)'] = '$age';
  }

  bool _isAnswered(_AnamneseQuestion q) {
    final value = (_answers[q.prompt] ?? '').trim();
    if (!q.required) return true;
    return value.isNotEmpty;
  }

  Future<void> _next() async {
    final visible = _visibleQuestions;
    final q = visible[_index];
    if (!_isAnswered(q)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Responda a pergunta para continuar.')),
      );
      return;
    }
    if (_index < visible.length - 1) {
      setState(() => _index++);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    _syncCalculatedAge();
    setState(() => _saving = true);
    try {
      await widget.repo.saveStudentAnamnese(
        studentId: widget.studentId,
        answers: _answers,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar questionário: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleQuestions;
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_index >= visible.length) {
      _index = visible.length - 1;
    }
    final q = visible[_index];
    final total = visible.length;
    final progress = (_index + 1) / total;
    final selected = _multiSelected(q.prompt);

    Widget answerWidget() {
      if (q.kind == _AnamneseAnswerKind.single) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in q.options)
              ChoiceChip(
                label: Text(option),
                selected: (_answers[q.prompt] ?? '') == option,
                onSelected: (v) {
                  setState(() {
                    _answers[q.prompt] = v ? option : '';
                    for (final dep in _kAnamneseQuestions.where(
                      (x) => x.showWhenPromptEquals == q.prompt,
                    )) {
                      if (!_shouldShow(dep)) {
                        _answers.remove(dep.prompt);
                        _textControllers[dep.prompt]?.text = '';
                      }
                    }
                  });
                },
              ),
          ],
        );
      }
      if (q.kind == _AnamneseAnswerKind.multi) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in q.options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (v) {
                  final next = {...selected};
                  if (v) {
                    next.add(option);
                  } else {
                    next.remove(option);
                  }
                  setState(() {
                    _answers[q.prompt] = next.join('; ');
                  });
                },
              ),
          ],
        );
      }
      if (q.kind == _AnamneseAnswerKind.date) {
        final controller = _textControllers[q.prompt]!;
        final selectedDate = _parseBirthDate(controller.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final initial =
                    selectedDate ?? DateTime(now.year - 25, now.month, now.day);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1900, 1, 1),
                  lastDate: DateTime.now(),
                  helpText: 'Data de nascimento',
                );
                if (picked == null) return;
                final formatted = DateFormat('dd/MM/yyyy').format(picked);
                setState(() {
                  controller.text = formatted;
                  _answers[q.prompt] = formatted;
                  _syncCalculatedAge();
                });
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                selectedDate == null
                    ? 'Selecionar data de nascimento'
                    : DateFormat('dd/MM/yyyy').format(selectedDate),
              ),
            ),
            const SizedBox(height: 8),
            if ((_answers['Idade (calculada)'] ?? '').isNotEmpty)
              Text(
                'Idade calculada automaticamente: ${_answers['Idade (calculada)']} anos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
          ],
        );
      }
      final controller = _textControllers[q.prompt]!;
      return TextField(
        controller: controller,
        onChanged: (v) => _answers[q.prompt] = v.trim(),
        keyboardType: q.kind == _AnamneseAnswerKind.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        minLines: q.kind == _AnamneseAnswerKind.text ? 2 : 1,
        maxLines: q.kind == _AnamneseAnswerKind.text ? 4 : 1,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: q.kind == _AnamneseAnswerKind.number
              ? 'Digite um valor numérico'
              : 'Digite sua resposta',
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1328), Color(0xFF1A1030), Color(0xFF0B1C2E)],
              ),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.42),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fact_check_rounded, color: AppColors.splashMint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anamnese · ${widget.studentName}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.section,
                    style: TextStyle(
                      color: AppColors.splashMint.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pergunta ${_index + 1} de $total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    q.prompt,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(child: answerWidget()),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar quiz'),
                      ),
                      const Spacer(),
                      if (_index > 0)
                        OutlinedButton(
                          onPressed: _saving ? null : () => setState(() => _index--),
                          child: const Text('Voltar'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _next,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _index == total - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(
                          _index == total - 1 ? 'Finalizar' : 'Próxima',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReportPeriod {
  last4Weeks,
  last8Weeks,
  last12Weeks,
  allTime,
}

extension on _ReportPeriod {
  String get label => switch (this) {
        _ReportPeriod.last4Weeks => '4 semanas',
        _ReportPeriod.last8Weeks => '8 semanas',
        _ReportPeriod.last12Weeks => '12 semanas',
        _ReportPeriod.allTime => 'Todo período',
      };

  Duration? get duration => switch (this) {
        _ReportPeriod.last4Weeks => const Duration(days: 28),
        _ReportPeriod.last8Weeks => const Duration(days: 56),
        _ReportPeriod.last12Weeks => const Duration(days: 84),
        _ReportPeriod.allTime => null,
      };
}

class _PerformanceReportSheet extends StatefulWidget {
  const _PerformanceReportSheet({
    required this.repo,
    required this.studentId,
    required this.studentName,
  });

  final AppDataRepository repo;
  final String studentId;
  final String studentName;

  @override
  State<_PerformanceReportSheet> createState() => _PerformanceReportSheetState();
}

class _PerformanceReportSheetState extends State<_PerformanceReportSheet> {
  _ReportPeriod _period = _ReportPeriod.last8Weeks;
  var _loading = false;
  String? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final generated = await _buildStudentReport();
      if (!mounted) return;
      setState(() => _report = generated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao gerar relatório: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _buildStudentReport() async {
    final now = DateTime.now();
    final window = _period.duration;
    final from = window == null ? null : now.subtract(window);
    final toExclusive = DateTime(now.year, now.month, now.day + 1);

    final snapshots = await widget.repo.completedWorkoutSnapshots(
      studentId: widget.studentId,
      fromInclusive: from,
      toExclusive: toExclusive,
    );
    final anamneseHistory = await widget.repo.studentAnamneseHistory(
      studentId: widget.studentId,
      limit: 20,
    );
    if (snapshots.isEmpty) {
      return 'Sem treinos concluídos no período selecionado.';
    }

    final exercises = await widget.repo.watchExercisesAlphabetical().first;
    final muscles = await widget.repo.watchMuscleGroupsAlphabetical().first;
    final groups = await widget.repo.watchWorkoutGroupsAlphabetical().first;
    final exerciseById = {for (final e in exercises) e.id: e};
    final muscleById = {for (final m in muscles) m.id: m};
    final groupById = {for (final g in groups) g.id: g.name};

    var totalActiveSec = 0;
    var totalWorkoutScore = 0.0;
    var totalWorkoutCalories = 0.0;
    final exerciseScores = <String, List<double>>{};
    final exerciseCalories = <String, double>{};
    final exerciseSessions = <String, int>{};
    final groupScoreSum = <String, double>{};
    final groupCount = <String, int>{};

    for (final snapshot in snapshots) {
      final w = snapshot.workout;
      final lines = snapshot.exercises;
      totalActiveSec += w.activeDurationSeconds;
      final activeMin = (w.activeDurationSeconds <= 0 ? 1 : w.activeDurationSeconds) / 60.0;

      var workoutScore = 0.0;
      final lineScores = <String, double>{};
      for (final line in lines) {
        final performed = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
        final performedScore = DayWorkoutPerformedSetCodec.totalVolumeScore(performed);
        final score = line.exerciseScore ??
            (performedScore > 0 ? performedScore : (line.sets * line.reps * (line.loadKg ?? 0)));
        workoutScore += score;
        lineScores[line.id] = score;
      }
      if (workoutScore <= 0) workoutScore = lines.length.toDouble();
      totalWorkoutScore += workoutScore;

      final totalVolume = lines.fold<double>(0, (sum, line) {
        final performed = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
        final v = DayWorkoutPerformedSetCodec.totalVolumeScore(performed);
        return sum + (v > 0 ? v : (line.sets * line.reps * (line.loadKg ?? 0)));
      });
      final workoutCalories = (activeMin * 6.0) + (totalVolume * 0.01);
      totalWorkoutCalories += workoutCalories;

      for (final line in lines) {
        final exId = line.exerciseId;
        final s = lineScores[line.id] ?? 0;
        exerciseScores.putIfAbsent(exId, () => []).add(s);
        exerciseSessions[exId] = (exerciseSessions[exId] ?? 0) + 1;
        final kcal = workoutScore > 0 ? workoutCalories * (s / workoutScore) : 0.0;
        exerciseCalories[exId] = (exerciseCalories[exId] ?? 0) + kcal;

        final mgId = exerciseById[exId]?.muscleGroupId;
        if (mgId != null && mgId.isNotEmpty) {
          groupScoreSum[mgId] = (groupScoreSum[mgId] ?? 0) + s;
          groupCount[mgId] = (groupCount[mgId] ?? 0) + 1;
        }
      }
    }

    final avgScore = totalWorkoutScore / snapshots.length;
    final avgMinutes = (totalActiveSec / 60) / snapshots.length;
    final avgCalories = totalWorkoutCalories / snapshots.length;

    final trends = <({String exId, double trend, int sessions})>[];
    for (final entry in exerciseScores.entries) {
      final values = entry.value;
      if (values.length < 2) continue;
      final first = values.first;
      final last = values.last;
      final trend =
          first.abs() < 0.0001 ? 0.0 : (last - first) / first.abs();
      trends.add((exId: entry.key, trend: trend, sessions: values.length));
    }
    trends.sort((a, b) => b.trend.compareTo(a.trend));
    final evolved = trends.where((t) => t.trend >= 0.12).take(6).toList();
    final attention = trends.where((t) => t.trend <= -0.08).take(6).toList();

    final groupAvg = <({String mgId, double avgScore})>[];
    for (final mgId in groupScoreSum.keys) {
      final count = groupCount[mgId] ?? 1;
      groupAvg.add((mgId: mgId, avgScore: (groupScoreSum[mgId] ?? 0) / count));
    }
    groupAvg.sort((a, b) => b.avgScore.compareTo(a.avgScore));
    final bestGroups = groupAvg.take(3).toList();
    final weakGroups = groupAvg.reversed.take(3).toList();

    final caloriesByExercise = exerciseCalories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCaloriesExercises = caloriesByExercise.take(5).toList();

    final anamneseChrono = anamneseHistory.reversed.toList();
    final latestAnamnese =
        anamneseChrono.isNotEmpty ? anamneseChrono.last : null;
    final firstAnamnese =
        anamneseChrono.isNotEmpty ? anamneseChrono.first : null;
    final periodLabel = _period.label;
    final startDate = snapshots.first.workout.dayDate;
    final endDate = snapshots.last.workout.dayDate;
    final fmt = DateFormat('dd/MM/yyyy');

    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    String kgScore(double s) => s.toStringAsFixed(1);
    String kcal(double c) => c.toStringAsFixed(0);

    final buffer = StringBuffer()
      ..writeln('Relatório de Performance — ${widget.studentName}')
      ..writeln('Período: $periodLabel (${fmt.format(startDate)} a ${fmt.format(endDate)})')
      ..writeln('')
      ..writeln('1. Resumo geral')
      ..writeln('- Treinos concluídos: ${snapshots.length}')
      ..writeln('- Score médio por treino: ${avgScore.toStringAsFixed(2)}')
      ..writeln('- Tempo ativo médio por treino: ${avgMinutes.toStringAsFixed(1)} min')
      ..writeln('- Gasto calórico estimado médio: ${kcal(avgCalories)} kcal/treino')
      ..writeln('')
      ..writeln('2. Exercícios com melhor evolução')
      ..writeln(
        evolved.isEmpty
            ? '- Sem evolução robusta detectada (mín. 2 sessões por exercício).'
            : evolved
                .map((e) {
                  final name = exerciseById[e.exId]?.name ?? 'Exercício';
                  return '- $name: ${pct(e.trend)} em ${e.sessions} sessões';
                })
                .join('\n'),
      )
      ..writeln('')
      ..writeln('3. Exercícios que precisam de atenção')
      ..writeln(
        attention.isEmpty
            ? '- Sem quedas relevantes no período.'
            : attention
                .map((e) {
                  final name = exerciseById[e.exId]?.name ?? 'Exercício';
                  return '- $name: ${pct(e.trend)} em ${e.sessions} sessões';
                })
                .join('\n'),
      )
      ..writeln('')
      ..writeln('4. Calorias estimadas')
      ..writeln('- Total estimado no período: ${kcal(totalWorkoutCalories)} kcal')
      ..writeln('- Top exercícios (estimativa de contribuição):')
      ..writeln(
        topCaloriesExercises.isEmpty
            ? '- Sem dados.'
            : topCaloriesExercises
                .map((e) => '- ${exerciseById[e.key]?.name ?? 'Exercício'}: ${kcal(e.value)} kcal')
                .join('\n'),
      )
      ..writeln('')
      ..writeln('5. Grupos musculares')
      ..writeln('- Melhores resultados:')
      ..writeln(
        bestGroups.isEmpty
            ? '- Sem dados suficientes.'
            : bestGroups
                .map((g) => '- ${muscleById[g.mgId]?.name ?? 'Grupo'}: score médio ${kgScore(g.avgScore)}')
                .join('\n'),
      )
      ..writeln('- Pontos de atenção:')
      ..writeln(
        weakGroups.isEmpty
            ? '- Sem dados suficientes.'
            : weakGroups
                .map((g) => '- ${muscleById[g.mgId]?.name ?? 'Grupo'}: score médio ${kgScore(g.avgScore)}')
                .join('\n'),
      );

    if (latestAnamnese != null) {
      final fmtAnam = DateFormat('dd/MM/yyyy HH:mm');
      final keys = <String>{};
      final changeCountByKey = <String, int>{};
      final answerFrequencyByKey = <String, Map<String, int>>{};

      for (final session in anamneseChrono) {
        for (final entry in session.answers.entries) {
          final key = entry.key.trim();
          final value = entry.value.trim();
          if (key.isEmpty || value.isEmpty) continue;
          keys.add(key);
          final freq = answerFrequencyByKey.putIfAbsent(key, () => <String, int>{});
          freq[value] = (freq[value] ?? 0) + 1;
        }
      }
      for (var i = 1; i < anamneseChrono.length; i++) {
        final prev = anamneseChrono[i - 1].answers;
        final curr = anamneseChrono[i].answers;
        for (final key in keys) {
          final a = (prev[key] ?? '').trim();
          final b = (curr[key] ?? '').trim();
          if (a.isEmpty || b.isEmpty) continue;
          if (a != b) {
            changeCountByKey[key] = (changeCountByKey[key] ?? 0) + 1;
          }
        }
      }

      final changedKeys = changeCountByKey.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      buffer
        ..writeln('')
        ..writeln('6. Anamnese e comparação')
        ..writeln('- Registros de anamnese: ${anamneseChrono.length}')
        ..writeln('- Primeira resposta: ${fmtAnam.format(firstAnamnese!.at)}')
        ..writeln('- Última resposta: ${fmtAnam.format(latestAnamnese.at)}');

      if (changedKeys.isEmpty) {
        buffer.writeln('- Sem mudanças relevantes entre respostas de anamnese.');
      } else {
        buffer.writeln('- Principais mudanças observadas no histórico:');
        for (final e in changedKeys.take(8)) {
          final key = e.key;
          final first = (firstAnamnese.answers[key] ?? '').trim();
          final last = (latestAnamnese.answers[key] ?? '').trim();
          if (first.isEmpty && last.isEmpty) continue;
          buffer.writeln(
            '- $key: $first -> $last (${e.value} mudança(s) entre quizzes)',
          );
        }
      }

      final stable = keys.where((k) => (changeCountByKey[k] ?? 0) == 0).toList();
      if (stable.isNotEmpty) {
        buffer.writeln(
          '- Itens estáveis: ${stable.take(5).join(', ')}'
          '${stable.length > 5 ? '...' : ''}',
        );
      }

      final topBehavior = <String>[];
      for (final entry in answerFrequencyByKey.entries) {
        final freq = entry.value.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (freq.isNotEmpty && freq.first.value >= 2) {
          topBehavior.add('${entry.key}: ${freq.first.key} (${freq.first.value}x)');
        }
      }
      if (topBehavior.isNotEmpty) {
        buffer
          ..writeln('- Padrões mais frequentes de resposta:')
          ..writeln(topBehavior.take(5).map((e) => '- $e').join('\n'));
      }
    } else {
      buffer
        ..writeln('')
        ..writeln('6. Anamnese e comparação')
        ..writeln('- Sem anamnese preenchida para este aluno.');
    }

    final byWorkoutGroup = <String, int>{};
    for (final s in snapshots) {
      final gid = s.workout.sourceWorkoutGroupId;
      if (gid == null || gid.trim().isEmpty) continue;
      byWorkoutGroup[gid] = (byWorkoutGroup[gid] ?? 0) + 1;
    }
    if (byWorkoutGroup.isNotEmpty) {
      final sorted = byWorkoutGroup.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer
        ..writeln('')
        ..writeln('7. Grupos de treino mais usados')
        ..writeln(
          sorted
              .take(5)
              .map((e) => '- ${groupById[e.key] ?? 'Grupo'}: ${e.value} treino(s)')
              .join('\n'),
        );
    }

    final baseReport = buffer.toString().trim();
    final aiPrompt = '''
Com base no relatório abaixo, escreva uma seção "Plano de ação recomendado (próximas 2-4 semanas)" com:
- 5 recomendações objetivas para o personal.
- ajustes de progressão de carga/repetição.
- foco nos exercícios e grupos de atenção.
- linguagem profissional e direta.

Relatório:
$baseReport
''';
    final aiSection = await FreeAiTrainingReportService.enrichReport(
      prompt: aiPrompt,
    );
    if (aiSection == null || aiSection.trim().isEmpty) {
      return '$baseReport\n\nPlano de ação recomendado (fallback local):\n'
          '- Priorizar os exercícios com tendência negativa em 2 sessões da semana.\n'
          '- Aplicar progressão de 2% a 5% de carga quando houver execução técnica estável.\n'
          '- Inserir 1 bloco extra para grupos musculares com menor score médio.\n'
          '- Reavaliar amplitude, cadência e intervalos para os exercícios com queda de score.\n'
          '- Revisar semanalmente o score/min e o gasto calórico estimado para ajuste fino.';
    }
    return '$baseReport\n\n$aiSection';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1328),
            const Color(0xFF171230),
            AppColors.backgroundDeep,
          ],
        ),
        border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.4)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_rounded,
                    color: AppColors.splashMint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Relatório Inteligente · ${widget.studentName}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final p in _ReportPeriod.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _period == p,
                        label: Text(p.label),
                        onSelected: (v) {
                          if (!v) return;
                          setState(() => _period = p);
                          _generate();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.splashMint,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    AppColors.splashMint.withValues(alpha: 0.25),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(14),
                              child: SelectableText(
                                _report ?? '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_report == null || _report!.isEmpty)
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _report!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Relatório copiado.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_report == null || _report!.isEmpty)
                          ? null
                          : () => SharePlus.instance.share(
                                ShareParams(text: _report!),
                              ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
