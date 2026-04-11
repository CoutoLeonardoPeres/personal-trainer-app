import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/auth/app_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/keyboard_bottom_inset.dart';
import '../../core/utils/combo_line_grouping_utils.dart';
import '../../core/utils/day_workout_line_order_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import 'calendar_day_exercises_sheet.dart';

/// Painel de treino em andamento: timer (ativo sem contar pausa), pausar, retomar, concluir.
void showActiveWorkoutSheet(BuildContext context, String dayWorkoutId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => ActiveWorkoutSheet(dayWorkoutId: dayWorkoutId),
  );
}

class ActiveWorkoutSheet extends StatefulWidget {
  const ActiveWorkoutSheet({super.key, required this.dayWorkoutId});

  final String dayWorkoutId;

  @override
  State<ActiveWorkoutSheet> createState() => _ActiveWorkoutSheetState();
}

class _ActiveWorkoutSheetState extends State<ActiveWorkoutSheet> {
  Timer? _tick;
  final Map<String, bool> _useAlternativeByLineId = {};

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return KeyboardBottomInsetPadding(
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scroll) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.barBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(
                color: AppColors.accentGreen.withValues(alpha: 0.35),
              ),
            ),
            child: StreamBuilder<DayWorkoutEntity?>(
              stream: repo.watchDayWorkout(widget.dayWorkoutId),
              builder: (context, snap) {
                final w = snap.data;
                if (w == null) {
                  return const Center(
                    child: Text(
                      'Treino não encontrado',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                if (w.status == 'completed') {
                  return _completedBody(context, w, scroll);
                }

                final now = DateTime.now();
                final secs = repo.effectiveActiveSeconds(w, now);
                final running = w.timerResumeAt != null;

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      _fmt(secs),
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 52,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      running ? 'Em andamento' : 'Pausado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (running)
                            FilledButton.icon(
                              onPressed: () => repo.pauseDayWorkout(w.id),
                              icon: const Icon(Icons.pause_rounded),
                              label: const Text('Pausar'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => repo.resumeDayWorkout(w.id),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Retomar'),
                            ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final session = context.read<AppSession>();
                              final ok =
                                  await tryCompleteDayWorkoutWithIncompletePrompt(
                                    context: context,
                                    repo: repo,
                                    session: session,
                                    dayWorkoutId: w.id,
                                  );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Treino concluído. Score atualizado.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.flag_rounded),
                            label: const Text('Concluir'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.accentGreen, height: 24),
                    Expanded(
                      child: StreamBuilder<List<ExerciseEntity>>(
                        stream: repo.watchExercisesAlphabetical(),
                        builder: (context, exSnap) {
                          final nameMap = {
                            for (final e in exSnap.data ?? []) e.id: e.name,
                          };
                          return StreamBuilder<List<DayWorkoutExerciseEntity>>(
                            stream: repo.watchDayWorkoutExercises(
                              widget.dayWorkoutId,
                            ),
                            builder: (context, lineSnap) {
                              final raw = lineSnap.data ?? [];
                              final plannedOrder =
                                  List<DayWorkoutExerciseEntity>.from(raw)
                                    ..sort(
                                      (a, b) =>
                                          a.sortOrder.compareTo(b.sortOrder),
                                    );
                              final ordered =
                                  orderDayWorkoutLinesByPerformedHistory(raw);
                              final blocks =
                                  dayWorkoutLinesAsComboBlocks(ordered);
                              return SlidableAutoCloseBehavior(
                                child: ListView.builder(
                                  controller: scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    32,
                                  ),
                                  itemCount: blocks.length,
                                  itemBuilder: (_, bi) {
                                    final block = blocks[bi];
                                    Widget lineCard(DayWorkoutExerciseEntity line) {
                                      ExerciseEntity? meta;
                                      for (final e in exSnap.data ?? []) {
                                        if (e.id == line.exerciseId) {
                                          meta = e;
                                          break;
                                        }
                                      }
                                      final baseName =
                                          nameMap[line.exerciseId] ??
                                              'Exercício';
                                      final useAlt =
                                          _useAlternativeByLineId[line.id] ??
                                          false;
                                      return CalendarExerciseLineCard(
                                        line: line,
                                        exerciseName: baseName,
                                        exercise: meta,
                                        expandable: true,
                                        workoutStatus: w.status,
                                        workoutPaused:
                                            w.timerResumeAt == null,
                                        useAlternative: useAlt,
                                        executedOutOfPlannedOrder:
                                            dayWorkoutLineExecutedOutOfPlannedOrder(
                                          plannedOrder,
                                          line,
                                        ),
                                        onToggleAlternative:
                                            calendarExerciseHasAlternative(
                                                  meta,
                                                )
                                                ? () => setState(() {
                                                      _useAlternativeByLineId[
                                                              line.id] =
                                                          !(_useAlternativeByLineId[
                                                                  line.id] ??
                                                              false);
                                                    })
                                                : null,
                                        performedSetsRepo: repo,
                                      );
                                    }

                                    if (block.length == 1) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: lineCard(block.single),
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              bottom: 8,
                                            ),
                                            child: Text(
                                              'Combinação (sem intervalo entre estes)',
                                              style: TextStyle(
                                                color: AppColors.splashMint
                                                    .withValues(alpha: 0.88),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          for (var j = 0;
                                              j < block.length;
                                              j++) ...[
                                            if (j > 0) const SizedBox(height: 8),
                                            lineCard(block[j]),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
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
            ),
          );
        },
      ),
    );
  }

  Widget _completedBody(
    BuildContext context,
    DayWorkoutEntity w,
    ScrollController scroll,
  ) {
    final repo = context.read<AppDataRepository>();
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 48),
        const SizedBox(height: 8),
        const Text(
          'Treino concluído',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Tempo ativo: ${_fmt(w.activeDurationSeconds)}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        if (w.workoutScore != null)
          Text(
            'Score do treino: ${w.workoutScore!.toStringAsFixed(4)}',
            style: const TextStyle(color: AppColors.accentGreen, fontSize: 16),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<ExerciseEntity>>(
            stream: repo.watchExercisesAlphabetical(),
            builder: (context, exSnap) {
              final nameMap = {for (final e in exSnap.data ?? []) e.id: e.name};
              return StreamBuilder<List<DayWorkoutExerciseEntity>>(
                stream: repo.watchDayWorkoutExercises(widget.dayWorkoutId),
                builder: (context, lineSnap) {
                  final raw = lineSnap.data ?? [];
                  final plannedOrder =
                      List<DayWorkoutExerciseEntity>.from(raw)
                        ..sort(
                          (a, b) => a.sortOrder.compareTo(b.sortOrder),
                        );
                  final ordered =
                      orderDayWorkoutLinesByPerformedHistory(raw);
                  final blocks = dayWorkoutLinesAsComboBlocks(ordered);
                  return SlidableAutoCloseBehavior(
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: blocks.length,
                      itemBuilder: (_, bi) {
                        final block = blocks[bi];
                        Widget lineCard(DayWorkoutExerciseEntity line) {
                          ExerciseEntity? meta;
                          for (final e in exSnap.data ?? []) {
                            if (e.id == line.exerciseId) {
                              meta = e;
                              break;
                            }
                          }
                          final baseName =
                              nameMap[line.exerciseId] ?? 'Exercício';
                          final useAlt =
                              _useAlternativeByLineId[line.id] ?? false;
                          return CalendarExerciseLineCard(
                            line: line,
                            exerciseName: baseName,
                            exercise: meta,
                            expandable: true,
                            workoutStatus: w.status,
                            useAlternative: useAlt,
                            executedOutOfPlannedOrder:
                                dayWorkoutLineExecutedOutOfPlannedOrder(
                              plannedOrder,
                              line,
                            ),
                            onToggleAlternative: null,
                            performedSetsRepo: repo,
                          );
                        }

                        if (block.length == 1) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: lineCard(block.single),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Combinação (sem intervalo entre estes)',
                                  style: TextStyle(
                                    color: AppColors.splashMint
                                        .withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              for (var j = 0; j < block.length; j++) ...[
                                if (j > 0) const SizedBox(height: 8),
                                lineCard(block[j]),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ),
        ),
      ],
    );
  }
}
