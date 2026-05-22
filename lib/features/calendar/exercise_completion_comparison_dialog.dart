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
                        'Séries',
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
          Row(
            children: [
              Expanded(
                child: _kv('Score', _formatScore(data.currentTotalScore)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kv(
                  'Evolução',
                  ev == null ? '—' : _formatPct(ev),
                ),
              ),
            ],
          ),
          if (data.currentPredictedKcal != null || data.currentEstimatedKcal != null) ...[
            const SizedBox(height: 8),
            _kv(
              'Kcal (prev/exe)',
              '${(data.currentPredictedKcal ?? 0).toStringAsFixed(0)} / ${(data.currentEstimatedKcal ?? 0).toStringAsFixed(0)}',
            ),
          ],
          const SizedBox(height: 8),
          _kv('Tempo', _formatDurationPt(data.currentWallDuration)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {String? right}) {
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
                style: const TextStyle(
                  color: Colors.white,
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
  const _SetComparisonTile({required this.row, required this.accent});

  final ExerciseSetComparisonRow row;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ev = row.scoreEvolutionPctVsPrevious;
    final evText = ev == null
        ? '—'
        : _formatPct(ev);
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
                child: Text(
                  'Score ${_formatScore(row.currentSetScore)} · ${_formatPct(row.currentPctOfPrescribed, decimals: 0)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Evolução: $evText',
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
