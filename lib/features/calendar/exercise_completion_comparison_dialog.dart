import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/exercise_session_comparison.dart';

String _formatDurationPt(Duration d) {
  if (d <= Duration.zero) return '—';
  final sec = d.inSeconds;
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m <= 0) return '${s}s';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

String _formatPct(double v, {int decimals = 1}) {
  final sign = v > 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(decimals).replaceAll('.', ',')}%';
}

String _formatScore(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatLoadKg(double? v) {
  if (v == null) return 'sem carga';
  if (v == v.roundToDouble()) return '${v.toInt()} kg';
  return '${v.toStringAsFixed(1).replaceAll('.', ',')} kg';
}

String _formatSetMetrics({
  required int reps,
  required double? loadKg,
  required double score,
}) {
  return '$reps reps · ${_formatLoadKg(loadKg)} · score ${_formatScore(score)}';
}

String _formatRestMs(int? ms, int? prescribedSec) {
  if (ms == null) return '—';
  final s = (ms / 1000).round();
  final pres = prescribedSec != null && prescribedSec > 0
      ? ' (meta ${prescribedSec}s)'
      : '';
  return '${s}s$pres';
}

Color _comparisonColor({required double current, required double? previous}) {
  if (previous == null) return const Color(0xFF64B5F6);
  const eps = 0.0001;
  final diff = current - previous;
  if (diff.abs() <= eps) return Colors.amberAccent.shade200;
  if (diff > 0) return const Color(0xFF4CAF50);
  return const Color(0xFFEF5350);
}

Future<void> showExerciseCompletionComparisonDialog({
  required BuildContext context,
  required ExerciseSessionComparison data,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    useRootNavigator: true,
    builder: (ctx) => _ExerciseCompletionComparisonBody(data: data),
  );
}

class _ExerciseCompletionComparisonBody extends StatelessWidget {
  const _ExerciseCompletionComparisonBody({required this.data});

  final ExerciseSessionComparison data;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.splashMint;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101828), Color(0xFF0A0E14), Color(0xFF050508)],
            ),
            border: Border.all(
              color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 26,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, color: accent, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exercício concluído',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            data.exerciseName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _SummaryStrip(data: data, accent: accent),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    children: [
                      Text(
                        'Por série',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final row in data.sets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SetComparisonTile(
                            row: row,
                            accent: accent,
                            isLastSet: row.setNumber == data.sets.length,
                          ),
                        ),
                      if (!data.hasWorkoutWatchKcal)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Para ver calorias por exercício, registe as calorias '
                            'do relógio ao concluir o treino (treino concluído).',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.data, required this.accent});

  final ExerciseSessionComparison data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ev = data.totalScoreEvolutionPctVsPrevious;
    final totalScoreColor = _comparisonColor(
      current: data.currentTotalScore,
      previous: data.previousTotalScore,
    );
    final evLabel = ev == null
        ? 'Sem treino anterior comparável'
        : 'Total vs anterior: ${_formatPct(ev)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(
            'Tempo (1ª → última série)',
            _formatDurationPt(data.currentWallDuration),
            right: () {
              final p = data.previousWallDuration;
              if (p == null) return null;
              return 'antes: ${_formatDurationPt(p)}';
            }(),
          ),
          const SizedBox(height: 8),
          _kv(
            'Score total do exercício',
            _formatScore(data.currentTotalScore),
            valueColor: totalScoreColor,
            right: () {
              final p = data.previousTotalScore;
              if (p == null) return null;
              return 'antes: ${_formatScore(p)}';
            }(),
          ),
          if (data.currentEstimatedKcal != null) ...[
            const SizedBox(height: 8),
            _kv(
              'Calorias (estim.)',
              '${data.currentEstimatedKcal!.toStringAsFixed(0)} kcal',
              right: () {
                final p = data.previousEstimatedKcal;
                if (p == null) return null;
                return 'antes: ${p.toStringAsFixed(0)} kcal';
              }(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            evLabel,
            style: TextStyle(
              color: totalScoreColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {String? right, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                v,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (right != null)
              Flexible(
                child: Text(
                  right,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SetComparisonTile extends StatelessWidget {
  const _SetComparisonTile({
    required this.row,
    required this.accent,
    required this.isLastSet,
  });

  final ExerciseSetComparisonRow row;
  final Color accent;
  final bool isLastSet;

  @override
  Widget build(BuildContext context) {
    final ev = row.scoreEvolutionPctVsPrevious;
    final evText = ev == null ? '—' : _formatPct(ev);
    final scoreColor = _comparisonColor(
      current: row.currentSetScore,
      previous: row.previousSetScore,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Série ${row.setNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atual: ${_formatSetMetrics(reps: row.currentReps, loadKg: row.currentLoadKg, score: row.currentSetScore)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatPct(row.currentPctOfPrescribed, decimals: 0)} do prescrito',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scoreColor.withValues(alpha: 0.92),
                        fontSize: 11.2,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (row.previousSetScore != null) ...[
            const SizedBox(height: 6),
            Text(
              'Último treino: ${_formatSetMetrics(reps: row.previousReps ?? 0, loadKg: row.previousLoadKg, score: row.previousSetScore!)} · ${row.previousPctOfPrescribed != null ? _formatPct(row.previousPctOfPrescribed!, decimals: 0) : '—'} do prescrito de então',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11.2,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Evolução da série (score): $evText',
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          if (!isLastSet) ...[
            const SizedBox(height: 8),
            Text(
              'Descanso após esta série (timer)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Agora: ${_formatRestMs(row.restAfterCurrentCountdownMs, row.restPrescribedSec)}'
              '${row.restAfterPreviousCountdownMs != null ? ' · Último treino: ${_formatRestMs(row.restAfterPreviousCountdownMs, row.restPrescribedSec)}' : ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
