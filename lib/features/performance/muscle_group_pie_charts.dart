import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../data/repositories/app_data_repository.dart';
import 'muscle_group_pie_stats.dart';

/// Janela fixa alinhada ao subtítulo (8 semanas).
const kMusclePieWindowDays = 56;

const _palette = <Color>[
  Color(0xFF42A5F5),
  Color(0xFF69F0AE),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFF4DD0E1),
  Color(0xFFFF8A65),
  Color(0xFFAED581),
  Color(0xFF90CAF9),
];

Future<List<MuscleGroupPieSlice>> _loadMusclePieSlices(
  AppDataRepository repo,
  String studentId,
) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: kMusclePieWindowDays));
  final toExclusive = DateTime(now.year, now.month, now.day + 1);
  final snapshots = await repo.completedWorkoutSnapshots(
    studentId: studentId,
    fromInclusive: from,
    toExclusive: toExclusive,
  );
  if (snapshots.isEmpty) return [];
  final exercises = await repo.watchExercisesAlphabetical().first;
  final muscles = await repo.watchMuscleGroupsAlphabetical().first;
  final ex = {for (final e in exercises) e.id: e};
  final mg = {for (final m in muscles) m.id: m};
  return aggregateMuscleGroupPieSlices(snapshots, ex, mg);
}

/// Pizza: volume por grupo muscular (últimas 8 semanas).
class MuscleGroupVolumePieChart extends StatelessWidget {
  const MuscleGroupVolumePieChart({
    super.key,
    required this.studentId,
    required this.repo,
  });

  final String studentId;
  final AppDataRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MuscleGroupPieSlice>>(
      key: ValueKey('mg_vol_$studentId'),
      future: _loadMusclePieSlices(repo, studentId),
      builder: (context, snap) => _pieChartBody(
        snap: snap,
        emptyMessage:
            'Sem treinos concluídos nas últimas 8 semanas, ou sem exercícios '
            'com grupo muscular no cadastro.',
        buildChart: (slices, constraints) {
          final merged = mergeSmallestPieSlices(
            slices,
            8,
            (s) => s.lineCount,
          );
          final pieSize =
              (constraints.maxWidth * 0.48).clamp(132.0, 200.0);
          return _pieBlock(
            title: 'Onde mais treinou (volume)',
            subtitle: 'Participação por nº de exercícios no dia',
            slices: merged,
            value: (s) => s.lineCount.toDouble(),
            pieSize: pieSize,
          );
        },
      ),
    );
  }
}

/// Pizza: rendimento (score) por grupo muscular (últimas 8 semanas).
class MuscleGroupScorePieChart extends StatelessWidget {
  const MuscleGroupScorePieChart({
    super.key,
    required this.studentId,
    required this.repo,
  });

  final String studentId;
  final AppDataRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MuscleGroupPieSlice>>(
      key: ValueKey('mg_score_$studentId'),
      future: _loadMusclePieSlices(repo, studentId),
      builder: (context, snap) => _pieChartBody(
        snap: snap,
        emptyMessage:
            'Sem treinos concluídos nas últimas 8 semanas, ou sem exercícios '
            'com grupo muscular no cadastro.',
        buildChart: (slices, constraints) {
          final merged = mergeSmallestPieSlices(
            List<MuscleGroupPieSlice>.from(slices)
              ..sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal)),
            8,
            (s) => s.scoreTotal.round(),
          );
          final pieSize =
              (constraints.maxWidth * 0.48).clamp(132.0, 200.0);
          return _pieBlock(
            title: 'Rendimento por grupo',
            subtitle: 'Participação na soma dos scores das linhas',
            slices: merged,
            value: (s) => s.scoreTotal <= 0 ? 0.001 : s.scoreTotal,
            pieSize: pieSize,
          );
        },
      ),
    );
  }
}

Widget _pieChartBody({
  required AsyncSnapshot<List<MuscleGroupPieSlice>> snap,
  required String emptyMessage,
  required Widget Function(
    List<MuscleGroupPieSlice> slices,
    BoxConstraints constraints,
  ) buildChart,
}) {
  if (snap.connectionState == ConnectionState.waiting) {
    return const Center(
      child: ModernLoadingIndicator(size: 36),
    );
  }
  if (snap.hasError) {
    return Center(
      child: Text(
        'Não foi possível carregar: ${snap.error}',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red.shade200, fontSize: 13),
      ),
    );
  }
  final slices = snap.data ?? [];
  if (slices.isEmpty) {
    return Center(
      child: Text(
        emptyMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 14,
        ),
      ),
    );
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: buildChart(slices, constraints),
        ),
      );
    },
  );
}

Widget _pieBlock({
  required String title,
  required String subtitle,
  required List<MuscleGroupPieSlice> slices,
  required double Function(MuscleGroupPieSlice) value,
  required double pieSize,
}) {
  final total = slices.fold<double>(0, (a, s) => a + value(s));
  if (total <= 0) {
    return Center(
      child: Text(
        'Sem dados para exibir nesta métrica.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 14,
        ),
      ),
    );
  }
  final sections = <PieChartSectionData>[];
  for (var i = 0; i < slices.length; i++) {
    final s = slices[i];
    final v = value(s);
    sections.add(
      PieChartSectionData(
        color: _palette[i % _palette.length],
        value: v,
        title: '',
        radius: pieSize * 0.48,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.92),
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      ),
    );
  }
  final legendItems = <Widget>[
    Text(
      'Legenda',
      style: TextStyle(
        color: AppColors.accentGreen.withValues(alpha: 0.88),
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    ),
    const SizedBox(height: 10),
    for (var i = 0; i < slices.length; i++) ...[
      if (i > 0) const SizedBox(height: 10),
      _LegendRow(
        color: _palette[i % _palette.length],
        name: slices[i].name,
        percentLabel:
            '${((value(slices[i]) / total) * 100).clamp(0, 100).toStringAsFixed(1)}%',
      ),
    ],
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: AppColors.splashMint.withValues(alpha: 0.95),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 11.5,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: pieSize,
            height: pieSize,
            child: PieChart(
              PieChartData(
                sectionsSpace: 1.2,
                centerSpaceRadius: pieSize * 0.22,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: pieSize * 0.5,
                  maxHeight: pieSize * 1.15,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: AppColors.cadastroCardBorder.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: legendItems,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Uma linha da legenda à direita do gráfico: cor + nome + %.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.percentLabel,
  });

  final Color color;
  final String name;
  final String percentLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                percentLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
