import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/exercise_session_comparison.dart';
import '../../domain/scoring.dart' as scoring;

String _formatDurationPt(Duration d) {
  if (d <= Duration.zero) return '—';
  final sec = d.inSeconds;
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m <= 0) return '${s}s';
  return '${m}m${s.toString().padLeft(2, '0')}s';
}

String _formatScore(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatLoadKg(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return '${v.toInt()}';
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatSetLine({
  required int reps,
  required double? loadKg,
  required double score,
}) {
  return '${_formatLoadKg(loadKg)}kg×$reps · ${_formatScore(score)}';
}

String _formatRestShort(int? ms) {
  if (ms == null) return '';
  final s = (ms / 1000).round();
  return ' · ${s}s desc';
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101828), Color(0xFF0A0E14), Color(0xFF050508)],
            ),
            border: Border.all(
              color: AppColors.cadastroCardBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: accent, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.exerciseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _CompactSummary(data: data),
              ),
              if (data.sets.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                    itemCount: data.sets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (_, i) => _CompactSetRow(
                      row: data.sets[i],
                      isLastSet: i == data.sets.length - 1,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({required this.data});

  final ExerciseSessionComparison data;

  @override
  Widget build(BuildContext context) {
    final scoreColor = _comparisonColor(
      current: data.currentTotalScore,
      previous: data.previousTotalScore,
    );
    final execPct = scoring.formatExecutionPercentLabel(
      current: data.currentTotalScore,
      previous: data.previousTotalScore,
    );
    final prevDur = data.previousWallDuration;
    final prevScore = data.previousTotalScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: 'Tempo',
              value: _formatDurationPt(data.currentWallDuration),
              hint: prevDur != null ? 'ant. ${_formatDurationPt(prevDur)}' : null,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _SummaryCell(
              label: 'Score',
              value: _formatScore(data.currentTotalScore),
              valueColor: scoreColor,
              hint: prevScore != null ? 'ant. ${_formatScore(prevScore)}' : null,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _SummaryCell(
              label: 'Exec.',
              value: execPct,
              valueColor: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.white.withValues(alpha: 0.08),
  );
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
      ],
    );
  }
}

class _CompactSetRow extends StatelessWidget {
  const _CompactSetRow({required this.row, required this.isLastSet});

  final ExerciseSetComparisonRow row;
  final bool isLastSet;

  @override
  Widget build(BuildContext context) {
    final scoreColor = _comparisonColor(
      current: row.currentSetScore,
      previous: row.previousSetScore,
    );
    final execPct = row.previousSetScore == null
        ? scoring.formatExecutionPercentLabel(
            current: row.currentSetScore,
            previous: null,
          )
        : scoring.formatExecutionPercentLabel(
            current: row.currentSetScore,
            previous: row.previousSetScore,
          );
    final rest = !isLastSet ? _formatRestShort(row.restAfterCurrentCountdownMs) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121A26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              'S${row.setNumber}',
              style: TextStyle(
                color: AppColors.splashMint.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatSetLine(
                reps: row.currentReps,
                loadKg: row.currentLoadKg,
                score: row.currentSetScore,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            execPct,
            style: TextStyle(
              color: scoreColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (rest.isNotEmpty)
            Text(
              rest,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
