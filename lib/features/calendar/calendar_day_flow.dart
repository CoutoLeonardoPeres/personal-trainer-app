import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../data/local/app_database.dart';
import '../../data/models/programmable_bundle.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';
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
    final label =
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';

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

    await showAppModalSheet<void>(
      context: context,
      title: label,
      builder: (ctx, scroll) => FuturisticBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Text(
                'Sem treino neste dia. Escolha um aluno com planejamento válido na semana (séries e repetições preenchidas) para programar.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Nenhum aluno tem treinos agendados válidos nesta semana.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayModalStudentCard(
                            name: s.name,
                            subtitle: 'Toque para escolher o que programar',
                            onTap: () async {
                              Navigator.pop(ctx);
                              final bundles = await repo.getProgrammableBundles(
                                s.id,
                                day,
                              );
                              if (!context.mounted) return;
                              await _pickBundleAndProgram(
                                context,
                                repo,
                                s.id,
                                day,
                                bundles,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
        const SnackBar(
          content: Text('Não há treinos prontos para programar nesta semana.'),
        ),
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

    await showAppModalSheet<void>(
      context: context,
      title: 'O que programar?',
      builder: (ctx, scroll) => FuturisticBackground(
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: bundles.length,
          itemBuilder: (_, i) {
            final b = bundles[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DayModalBundleCard(
                title: b.title,
                exerciseCount: b.rows.length,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _reviewSnapshotModal(context, repo, studentId, day, b);
                },
              ),
            );
          },
        ),
      ),
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
                SnackBar(
                  content: Text(e.message ?? 'Não foi possível programar.'),
                ),
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
    final sids = byStudent.keys.toList()
      ..sort((a, b) => (nameMap[a] ?? a).compareTo(nameMap[b] ?? b));

    if (!context.mounted) return;

    Future<void> openStudentWorkout(String studentKey) async {
      final list = byStudent[studentKey]!;
      final w = _pickPrimaryWorkoutForDay(list);
      await _onWorkoutSelected(context, repo, day, w);
    }

    await showAppModalSheet<void>(
      context: context,
      title: label,
      builder: (ctx, scroll) => FuturisticBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Text(
                'Alunos com treino neste dia',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                itemCount: sids.length,
                itemBuilder: (_, i) {
                  final sid = sids[i];
                  final name = nameMap[sid] ?? sid;
                  final n = byStudent[sid]!.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayModalStudentCard(
                      name: name,
                      subtitle: n == 1
                          ? 'Toque para abrir o treino'
                          : '$n treinos no dia — abre o prioritário (em andamento → programado → concluído)',
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        await openStudentWorkout(sid);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Qual treino abrir quando há vários no mesmo dia: andamento → programado → concluído.
  static DayWorkoutEntity _pickPrimaryWorkoutForDay(
    List<DayWorkoutEntity> workouts,
  ) {
    if (workouts.length == 1) return workouts.first;
    int priority(String s) => switch (s) {
      'started' => 0,
      'programmed' => 1,
      'completed' => 2,
      _ => 3,
    };
    final sorted = List<DayWorkoutEntity>.from(workouts)
      ..sort((a, b) {
        final c = priority(a.status).compareTo(priority(b.status));
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    return sorted.first;
  }

  static Future<void> _onWorkoutSelected(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    DayWorkoutEntity w,
  ) async {
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

    Future<void> Function(BuildContext sheetContext)? onSwap;
    if (w.status == 'programmed') {
      onSwap = (sheetCtx) => _runSwapWorkoutFromSheet(
        sheetContext: sheetCtx,
        parentContext: context,
        repo: repo,
        day: day,
        workout: w,
      );
    }

    await showProgrammedDayExercisesSheet(
      context: context,
      repo: repo,
      workout: w,
      studentName: studentName,
      day: day,
      workoutBadgeLabel: badge,
      onSwapWorkout: onSwap,
    );
  }

  /// Substitui o treino programado: fecha a sheet, apaga o dia e abre escolha de bundle.
  static Future<void> _runSwapWorkoutFromSheet({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required AppDataRepository repo,
    required DateTime day,
    required DayWorkoutEntity workout,
  }) async {
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
    await _pickBundleAndProgram(
      parentContext,
      repo,
      workout.studentId,
      day,
      bundles,
    );
  }
}

/// Card de aluno nas modais do dia (calendário).
class _DayModalStudentCard extends StatelessWidget {
  const _DayModalStudentCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FuturisticCard(
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.splashMint.withValues(alpha: 0.22),
                  const Color(0xFF26C6DA).withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: AppColors.splashMint.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.splashMint.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.splashMint,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.accentGreen.withValues(alpha: 0.9),
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Card de bloco (grupo / avulsos) ao programar o dia.
class _DayModalBundleCard extends StatelessWidget {
  const _DayModalBundleCard({
    required this.title,
    required this.exerciseCount,
    required this.onTap,
  });

  final String title;
  final int exerciseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FuturisticCard(
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accentPink.withValues(alpha: 0.2),
                  AppColors.accentGreen.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.layers_rounded,
                color: AppColors.accentPink.withValues(alpha: 0.95),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$exerciseCount exercício${exerciseCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.accentGreen.withValues(alpha: 0.9),
            size: 28,
          ),
        ],
      ),
    );
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
        .map(
          (r) => TextEditingController(text: r.item.loadKg?.toString() ?? ''),
        )
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
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Séries *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _reps[i],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Reps *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _loads[i],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'kg',
                              ),
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
                      content: Text(
                        'Preencha séries e repetições (> 0) em todos os exercícios.',
                      ),
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
                out.add(
                  WeekScheduleRow(
                    item: newItem,
                    exerciseName: orig.exerciseName,
                  ),
                );
              }
              await widget.onConfirm(out);
            },
          ),
        ),
      ],
    );
  }
}
