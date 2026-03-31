import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../data/local/app_database.dart';
import '../../data/models/programmable_bundle.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';
import 'calendar_active_workout_sheet.dart';
import 'calendar_day_exercises_sheet.dart';

/// Fluxo do dia: programar a partir da semana, iniciar treino, timer, trocar programado.
class CalendarDayFlow {
  static Future<void> open(
    BuildContext context,
    DateTime date,
    List<DayWorkoutEntity> dayWorkouts,
  ) async {
    final repo = context.read<AppDataRepository>();
    final day = DateTime(date.year, date.month, date.day);
    final label = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';

    if (dayWorkouts.isEmpty && isCalendarDateBeforeToday(day)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não é possível agendar treinos em datas passadas.'),
          ),
        );
      }
      return;
    }

    if (dayWorkouts.isEmpty) {
      await _openEmptyDay(context, repo, day, label);
    } else {
      await _openDayWithWorkouts(context, repo, day, label, dayWorkouts);
    }
  }

  static Future<void> _openEmptyDay(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    String label,
  ) async {
    if (isCalendarDateBeforeToday(day)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não é possível agendar treinos em datas passadas.'),
          ),
        );
      }
      return;
    }
    final students = await repo.getStudentsWithProgrammableWeek(day);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.barBackground,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sem treino neste dia. Escolha um aluno com itens agendados na semana para programar.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (students.isEmpty)
                  const Text(
                    'Nenhum aluno tem treinos agendados válidos (séries/reps) nesta semana.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else
                  SizedBox(
                    height: MediaQuery.sizeOf(ctx).height * 0.4,
                    child: ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = students[i];
                        return ListTile(
                          title: Text(
                            s.name,
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.accentGreen),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final bundles = await repo.getProgrammableBundles(s.id, day);
                            if (!context.mounted) return;
                            await _pickBundleAndProgram(context, repo, s.id, day, bundles);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _pickBundleAndProgram(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime day,
    List<ProgrammableBundle> bundles,
  ) async {
    if (bundles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há treinos prontos para programar nesta semana.')),
      );
      return;
    }
    if (isCalendarDateBeforeToday(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível agendar treinos em datas passadas.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'O que programar para este dia?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.45,
                child: ListView.separated(
                  itemCount: bundles.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final b = bundles[i];
                    return ListTile(
                      title: Text(
                        b.title,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        '${b.rows.length} exercício(s)',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _reviewSnapshotModal(context, repo, studentId, day, b);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _reviewSnapshotModal(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime day,
    ProgrammableBundle bundle,
  ) async {
    await showAppModalSheet<void>(
      context: context,
      title: 'Ajustes (só neste dia)',
      builder: (ctx, scroll) => _ProgramSnapshotEditor(
        scrollController: scroll,
        bundle: bundle,
        onConfirm: (rows) async {
          try {
            await repo.createProgrammedDayWorkout(
              studentId: studentId,
              day: day,
              rows: rows,
              sourceWorkoutGroupId: bundle.workoutGroupId,
            );
          } on ArgumentError catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message ?? 'Não foi possível programar.')),
              );
            }
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Treino programado no calendário.')),
            );
          }
        },
      ),
    );
  }

  static Future<void> _openDayWithWorkouts(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    String label,
    List<DayWorkoutEntity> dayWorkouts,
  ) async {
    final students = await repo.watchStudentsAlphabetical().first;
    final nameMap = {for (final s in students) s.id: s.name};
    final byStudent = <String, List<DayWorkoutEntity>>{};
    for (final w in dayWorkouts) {
      byStudent.putIfAbsent(w.studentId, () => []).add(w);
    }
    final sids = byStudent.keys.toList()..sort((a, b) => (nameMap[a] ?? a).compareTo(nameMap[b] ?? b));

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.barBackground,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alunos com treino neste dia',
                  style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * 0.42,
                  child: ListView.separated(
                    itemCount: sids.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final sid = sids[i];
                      final name = nameMap[sid] ?? sid;
                      final n = byStudent[sid]!.length;
                      return ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          '$n treino(s)',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _sheetStudentWorkouts(
                            context,
                            repo,
                            day,
                            name,
                            byStudent[sid]!,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _sheetStudentWorkouts(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    String studentName,
    List<DayWorkoutEntity> workouts,
  ) async {
    int order(String s) => switch (s) {
          'programmed' => 0,
          'started' => 1,
          'completed' => 2,
          _ => 3,
        };
    workouts.sort((a, b) {
      final c = order(a.status).compareTo(order(b.status));
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  studentName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.4,
                child: ListView.separated(
                  itemCount: workouts.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final w = workouts[i];
                    return ListTile(
                      leading: Icon(
                        _statusIcon(w.status),
                        color: _statusColor(w.status),
                      ),
                      title: Text(
                        _statusLabel(w.status),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: w.workoutScore != null
                          ? Text(
                              'Score: ${w.workoutScore!.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            )
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _onWorkoutSelected(context, repo, day, w);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static IconData _statusIcon(String s) => switch (s) {
        'completed' => Icons.check_circle_outline,
        'started' => Icons.play_circle_outline,
        'programmed' => Icons.event_note,
        _ => Icons.circle_outlined,
      };

  static Color _statusColor(String s) => switch (s) {
        'completed' => AppColors.accentGreen,
        'started' => AppColors.accentPink,
        'programmed' => AppColors.calendarIncomplete,
        _ => AppColors.textMuted,
      };

  static String _statusLabel(String s) => switch (s) {
        'completed' => 'Concluído',
        'started' => 'Em andamento',
        'programmed' => 'Programado',
        _ => s,
      };

  static Future<void> _onWorkoutSelected(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    DayWorkoutEntity w,
  ) async {
    if (w.status == 'completed') {
      showActiveWorkoutSheet(context, w.id);
      return;
    }
    if (w.status == 'started') {
      showActiveWorkoutSheet(context, w.id);
      return;
    }
    if (w.status == 'programmed') {
      final students = await repo.watchStudentsAlphabetical().first;
      var studentName = 'Aluno';
      for (final s in students) {
        if (s.id == w.studentId) {
          studentName = s.name;
          break;
        }
      }
      if (!context.mounted) return;
      final badge = await repo.getDayWorkoutGroupBadgeLabel(w);
      if (!context.mounted) return;
      await showProgrammedDayExercisesSheet(
        context: context,
        repo: repo,
        workout: w,
        studentName: studentName,
        day: day,
        workoutBadgeLabel: badge,
        programmedStartWorkout: (sheetCtx) => _runProgrammedStartOrSwapDialog(
          sheetContext: sheetCtx,
          parentContext: context,
          repo: repo,
          day: day,
          workout: w,
        ),
      );
    }
  }

  static Future<void> _runProgrammedStartOrSwapDialog({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required AppDataRepository repo,
    required DateTime day,
    required DayWorkoutEntity workout,
  }) async {
    final pastDay = isCalendarDateBeforeToday(day);
    final action = await showDialog<String>(
      context: sheetContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Iniciar treino',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          pastDay
              ? 'Deseja iniciar o treino agora? O cronômetro será ativado.'
              : 'Deseja iniciar o treino agora ou substituí-lo por outro treino da semana?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          if (!pastDay)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'swap'),
              child: const Text('Substituir'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'start'),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == 'start') {
      await repo.startDayWorkout(workout.id);
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (parentContext.mounted) {
        showActiveWorkoutSheet(parentContext, workout.id);
      }
      return;
    }
    if (action == 'swap') {
      if (isCalendarDateBeforeToday(day)) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
              content: Text('Não é possível substituir treino em data passada.'),
            ),
          );
        }
        return;
      }
      final ok = await repo.deleteProgrammedDayWorkout(workout.id);
      if (!parentContext.mounted) return;
      if (!ok) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      final bundles = await repo.getProgrammableBundles(workout.studentId, day);
      if (!parentContext.mounted) return;
      await _pickBundleAndProgram(parentContext, repo, workout.studentId, day, bundles);
    }
  }

}

class _ProgramSnapshotEditor extends StatefulWidget {
  const _ProgramSnapshotEditor({
    required this.scrollController,
    required this.bundle,
    required this.onConfirm,
  });

  final ScrollController scrollController;
  final ProgrammableBundle bundle;
  final Future<void> Function(List<WeekScheduleRow> rows) onConfirm;

  @override
  State<_ProgramSnapshotEditor> createState() => _ProgramSnapshotEditorState();
}

class _ProgramSnapshotEditorState extends State<_ProgramSnapshotEditor> {
  late final List<TextEditingController> _sets;
  late final List<TextEditingController> _reps;
  late final List<TextEditingController> _loads;

  @override
  void initState() {
    super.initState();
    _sets = widget.bundle.rows
        .map((r) => TextEditingController(text: '${r.item.sets}'))
        .toList();
    _reps = widget.bundle.rows
        .map((r) => TextEditingController(text: '${r.item.reps}'))
        .toList();
    _loads = widget.bundle.rows
        .map((r) => TextEditingController(
              text: r.item.loadKg?.toString() ?? '',
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _sets) {
      c.dispose();
    }
    for (final c in _reps) {
      c.dispose();
    }
    for (final c in _loads) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.bundle.rows.length,
            itemBuilder: (_, i) {
              final r = widget.bundle.rows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.accentPink.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.exerciseName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sets[i],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(labelText: 'Séries *'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _reps[i],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(labelText: 'Reps *'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _loads[i],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(labelText: 'kg'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: AppPrimaryButton(
            label: 'Programar no calendário',
            icon: Icons.check_rounded,
            onPressed: () async {
              final out = <WeekScheduleRow>[];
              for (var i = 0; i < widget.bundle.rows.length; i++) {
                final orig = widget.bundle.rows[i];
                final s = int.tryParse(_sets[i].text.trim());
                final re = int.tryParse(_reps[i].text.trim());
                if (s == null || re == null || s <= 0 || re <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preencha séries e repetições (> 0) em todos os exercícios.'),
                    ),
                  );
                  return;
                }
                final lText = _loads[i].text.trim().replaceAll(',', '.');
                final l = lText.isEmpty ? null : double.tryParse(lText);
                final newItem = orig.item.copyWith(
                  sets: s,
                  reps: re,
                  loadKg: Value(l),
                  needsDetail: false,
                );
                out.add(WeekScheduleRow(item: newItem, exerciseName: orig.exerciseName));
              }
              await widget.onConfirm(out);
            },
          ),
        ),
      ],
    );
  }
}
