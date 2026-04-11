import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/combo_line_grouping_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/widgets/exercise_prescription_edit_dialog.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../data/exercise_name_similarity.dart';
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
      initialChildSize: 0.85,
      maxChildSize: 0.85,
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
      initialChildSize: 0.85,
      maxChildSize: 0.85,
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
      subtitle:
          'Alterações valem só para este dia no calendário. '
          'Deslize o card do exercício para a esquerda para excluir.',
      futuristicChrome: true,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => _ProgramSnapshotEditor(
        scrollController: scroll,
        repo: repo,
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

    final canProgramAnother =
        !repo.session.isStudent && !isCalendarDateBeforeToday(day);
    final othersProgrammable = canProgramAnother
        ? (await repo.getStudentsWithProgrammableWeek(day))
              .where((s) => !byStudent.containsKey(s.id))
              .toList()
        : <StudentEntity>[];

    if (!context.mounted) return;

    Future<void> openStudentWorkout(String studentKey) async {
      final list = byStudent[studentKey]!;
      final w = _pickPrimaryWorkoutForDay(list);
      await _onWorkoutSelected(context, repo, day, w);
    }

    final isAdmin = repo.session.isAdminPersonal;

    await showAppModalSheet<void>(
      context: context,
      title: label,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => FuturisticBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alunos com treino neste dia',
                    style: TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Admin: deslize o card para a esquerda para excluir todos os treinos deste aluno neste dia.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SlidableAutoCloseBehavior(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    for (var i = 0; i < sids.length; i++) ...[
                      Builder(
                        builder: (_) {
                          final sid = sids[i];
                          final name = nameMap[sid] ?? sid;
                          final n = byStudent[sid]!.length;
                          final card = _DayModalStudentCard(
                            name: name,
                            subtitle: n == 1
                                ? 'Toque para abrir o treino'
                                : '$n treinos no dia — abre o prioritário (em andamento → programado → concluído)',
                            onTap: () async {
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              await openStudentWorkout(sid);
                            },
                          );
                          if (!isAdmin) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: card,
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Slidable(
                              key: ValueKey('day_modal_student_$sid'),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.36,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final ok =
                                          await _confirmAdminDeleteDayWorkouts(
                                        ctx,
                                        studentName: name,
                                        workoutCount: n,
                                      );
                                      if (ok != true || !ctx.mounted) return;
                                      try {
                                        final removed = await repo
                                            .adminHardDeleteAllDayWorkoutsForStudent(
                                          studentId: sid,
                                          day: day,
                                        );
                                        if (!ctx.mounted) return;
                                        Navigator.of(ctx).pop();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                removed == 0
                                                    ? 'Nenhum treino removido.'
                                                    : '$removed treino(s) de $name removido(s). '
                                                          'A exclusão será enviada à nuvem em seguida.',
                                              ),
                                            ),
                                          );
                                        }
                                      } on ArgumentError catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.message ??
                                                    'Não foi possível excluir.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Erro ao excluir: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    backgroundColor: AppColors.danger
                                        .withValues(alpha: 0.92),
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_forever_rounded,
                                    label: 'Excluir\ndia',
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                    ),
                                  ),
                                ],
                              ),
                              child: card,
                            ),
                          );
                        },
                      ),
                    ],
                    if (othersProgrammable.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                        child: Text(
                          'Programar outro aluno neste dia',
                          style: TextStyle(
                            color: AppColors.accentGreen.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                        child: Text(
                          'Com planejamento na semana, mas sem treino neste dia:',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                      for (final s in othersProgrammable)
                        Padding(
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
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> _confirmAdminDeleteDayWorkouts(
    BuildContext context, {
    required String studentName,
    required int workoutCount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: Text(
          'Excluir treino(s) do dia?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Esta ação é só para administradores.\n\n'
          'Serão apagados permanentemente $workoutCount treino(s) de '
          '$studentName nesta data — incluindo concluídos — com todas as séries, '
          'tempos e scores. Os dados serão removidos do aparelho e da nuvem '
          '(Supabase) após sincronizar.\n\n'
          'Não é possível desfazer.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger.withValues(alpha: 0.9),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
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
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;
    return FuturisticCard(
      onTap: onTap,
      borderColor: blue.withValues(alpha: 0.88),
      borderWidth: 1.15,
      backgroundGradient: [
        blueSoft.withValues(alpha: 0.22),
        blue.withValues(alpha: 0.12),
        Colors.black.withValues(alpha: 0.26),
      ],
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  blueSoft.withValues(alpha: 0.28),
                  blue.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(
                color: blue.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: blueSoft.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.person_rounded,
                color: blueSoft.withValues(alpha: 0.95),
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
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;
    return FuturisticCard(
      onTap: onTap,
      borderColor: blue.withValues(alpha: 0.88),
      borderWidth: 1.15,
      backgroundGradient: [
        blueSoft.withValues(alpha: 0.22),
        blue.withValues(alpha: 0.12),
        Colors.black.withValues(alpha: 0.26),
      ],
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  blueSoft.withValues(alpha: 0.28),
                  blue.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(
                color: blue.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.layers_rounded,
                color: blueSoft.withValues(alpha: 0.95),
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
    required this.repo,
    required this.bundle,
    required this.onConfirm,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final ProgrammableBundle bundle;
  final Future<void> Function(List<WeekScheduleRow> rows) onConfirm;

  @override
  State<_ProgramSnapshotEditor> createState() => _ProgramSnapshotEditorState();
}

class _ProgramSnapshotEditorState extends State<_ProgramSnapshotEditor> {
  static const _uuid = Uuid();
  late List<WeekScheduleRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List<WeekScheduleRow>.from(widget.bundle.rows);
    _renumberSortOrders();
  }

  void _renumberSortOrders() {
    _rows.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
    for (var i = 0; i < _rows.length; i++) {
      final it = _rows[i].item;
      _rows[i] = WeekScheduleRow(
        item: it.copyWith(sortOrder: i),
        exerciseName: _rows[i].exerciseName,
      );
    }
  }

  void _removeBlockAt(int blockIndex) {
    final blocks = weekScheduleRowsAsComboBlocks(_rows);
    if (blockIndex < 0 || blockIndex >= blocks.length) return;
    final toRemove = blocks[blockIndex];
    if (_rows.length - toRemove.length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mantenha pelo menos um exercício para programar o dia, ou feche o painel.',
          ),
        ),
      );
      return;
    }
    final ids = {for (final r in toRemove) r.item.id};
    _rows.removeWhere((r) => ids.contains(r.item.id));
    _renumberSortOrders();
    setState(() {});
  }

  Future<void> _editRowAt(int index) async {
    final r = _rows[index];
    final i = r.item;
    final repsDisp = weekScheduleRepsDisplay(i);
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: r.exerciseName,
      badgeLabel: 'AJUSTES (SÓ NESTE DIA)',
      descriptionLine:
          'Métricas só para programar este dia; o planejamento semanal não é alterado.',
      headerIcon: Icons.today_rounded,
      initialSets: i.sets > 0 ? i.sets : 3,
      initialRepsText: repsDisp.isEmpty ? '10' : repsDisp,
      initialRestBetweenSetsSec: i.restBetweenSetsSec > 0 ? i.restBetweenSetsSec : 60,
      initialLoadKg: i.loadKg,
      initialTrainingMethodId: i.trainingMethodId,
    );
    if (!mounted || res == null) return;
    final newItem = i.copyWith(
      sets: res.sets,
      reps: res.repsHintInt,
      repsText: Value(res.repsText),
      loadKg: Value(res.loadKg),
      restBetweenSetsSec: res.restBetweenSetsSec,
      needsDetail: false,
      trainingMethodId: Value(res.trainingMethodId),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _rows[index] = WeekScheduleRow(item: newItem, exerciseName: r.exerciseName);
    });
  }

  Future<void> _openAddExercisePicker() async {
    final picked = await showAppModalSheet<ExerciseEntity>(
      context: context,
      title: 'Adicionar exercício',
      subtitle:
          'Entra só neste treino deste dia. O planejamento semanal não é alterado.',
      futuristicChrome: true,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _DaySnapshotAddExercisePicker(
        scrollController: scroll,
        repo: widget.repo,
      ),
    );
    if (!mounted || picked == null) return;

    final template = _rows.first.item;
    final now = DateTime.now();
    final rest = template.restBetweenSetsSec > 0 ? template.restBetweenSetsSec : 60;
    final item = WeekScheduleItemEntity(
      id: _uuid.v4(),
      blockId: template.blockId,
      exerciseId: picked.id,
      sourceWorkoutGroupId: widget.bundle.workoutGroupId,
      sortOrder: _rows.length,
      sets: 3,
      reps: 10,
      repsText: '10',
      loadKg: null,
      needsDetail: false,
      restBetweenSetsSec: rest,
      trainingMethodId: null,
      updatedAt: now,
      comboId: null,
    );
    setState(() {
      _rows.add(WeekScheduleRow(item: item, exerciseName: picked.name));
    });
    _renumberSortOrders();
  }

  Future<void> _combineFromBlock(List<WeekScheduleRow> block) async {
    final anchor = block.last;
    final exclude = {for (final r in _rows) r.item.exerciseId};
    final picked = await showAppModalSheet<ExerciseEntity>(
      context: context,
      title: 'Combinar com exercício',
      subtitle: 'Bloco sem intervalo entre os movimentos neste dia.',
      futuristicChrome: true,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _DaySnapshotAddExercisePicker(
        scrollController: scroll,
        repo: widget.repo,
        excludeExerciseIds: exclude,
      ),
    );
    if (!mounted || picked == null) return;
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: picked.name,
      badgeLabel: 'AJUSTES · COMBINAR',
      descriptionLine:
          'Prescrição no bloco; descanso vale após o último exercício do bloco.',
      headerIcon: Icons.merge_type_rounded,
      initialSets: 3,
      initialRepsText: '12-15',
      initialRestBetweenSetsSec:
          anchor.item.restBetweenSetsSec > 0 ? anchor.item.restBetweenSetsSec : 60,
      initialLoadKg: null,
      initialTrainingMethodId: null,
    );
    if (!mounted || res == null) return;
    final comboId = (anchor.item.comboId != null &&
            anchor.item.comboId!.trim().isNotEmpty)
        ? anchor.item.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();
    final idx = _rows.indexWhere((r) => r.item.id == anchor.item.id);
    if (idx < 0) return;
    if (anchor.item.comboId == null || anchor.item.comboId!.trim().isEmpty) {
      final it = _rows[idx].item;
      _rows[idx] = WeekScheduleRow(
        item: it.copyWith(
          comboId: Value(comboId),
          updatedAt: now,
        ),
        exerciseName: _rows[idx].exerciseName,
      );
    }
    final newItem = WeekScheduleItemEntity(
      id: _uuid.v4(),
      blockId: anchor.item.blockId,
      exerciseId: picked.id,
      sourceWorkoutGroupId: anchor.item.sourceWorkoutGroupId,
      sortOrder: anchor.item.sortOrder + 1,
      sets: res.sets,
      reps: res.repsHintInt,
      repsText: res.repsText,
      loadKg: res.loadKg,
      needsDetail: false,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
      updatedAt: now,
      comboId: comboId,
    );
    _rows.insert(
      idx + 1,
      WeekScheduleRow(item: newItem, exerciseName: picked.name),
    );
    _renumberSortOrders();
    setState(() {});
  }

  Future<void> _editRowWithId(String itemId) async {
    final index = _rows.indexWhere((r) => r.item.id == itemId);
    if (index >= 0) await _editRowAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = weekScheduleRowsAsComboBlocks(_rows);
    return Column(
      children: [
        Expanded(
          child: FuturisticBackground(
            child: SlidableAutoCloseBehavior(
              child: ListView.builder(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: blocks.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openAddExercisePicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.splashMint.withValues(alpha: 0.22),
                                  AppColors.cadastroCardBorder.withValues(
                                    alpha: 0.2,
                                  ),
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.accentGreen.withValues(
                                  alpha: 0.55,
                                ),
                                width: 1.15,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.splashMint.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 14,
                            ),
                            child: Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.splashMint.withValues(
                                          alpha: 0.45,
                                        ),
                                        AppColors.cadastroCardBorder.withValues(
                                          alpha: 0.35,
                                        ),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppColors.accentGreen.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: AppColors.textPrimary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Adicionar exercício',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Só neste dia · abre lista para escolher',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.52,
                                          ),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: AppColors.accentGreen.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final blockIndex = i - 1;
                  final block = blocks[blockIndex];
                  if (block.length == 1) {
                    final r = block.single;
                    final wi = r.item;
                    final repsD = weekScheduleRepsDisplay(wi);
                    final detail = StringBuffer()
                      ..write('Séries: ${wi.sets}  Reps: $repsD  ')
                      ..write('Carga: ${wi.loadKg?.toString() ?? '—'} kg  ·  ')
                      ..write('Descanso: ${wi.restBetweenSetsSec}s')
                      ..write('\nToque para editar métricas e método.');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        key: ValueKey('snap_${r.item.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.56,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _combineFromBlock(block),
                              backgroundColor: const Color(0xFF7E57C2),
                              foregroundColor: Colors.white,
                              icon: Icons.merge_type_rounded,
                              label: 'Combinar',
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                              ),
                            ),
                            SlidableAction(
                              onPressed: (_) => _removeBlockAt(blockIndex),
                              backgroundColor:
                                  AppColors.danger.withValues(alpha: 0.92),
                              foregroundColor: Colors.white,
                              icon: Icons.delete_outline_rounded,
                              label: 'Excluir',
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _editRowWithId(r.item.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.calendarFutureProgrammed
                                        .withValues(alpha: 0.2),
                                    AppColors.cadastroCardBorder
                                        .withValues(alpha: 0.11),
                                    Colors.black.withValues(alpha: 0.26),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.cadastroCardBorder.withValues(
                                    alpha: 0.82,
                                  ),
                                  width: 1.15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.calendarFutureProgrammed
                                        .withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.exerciseName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    detail.toString(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final names = block.map((r) => r.exerciseName).join(' · ');
                  final detailCombo = StringBuffer();
                  for (var k = 0; k < block.length; k++) {
                    final r = block[k];
                    final wi = r.item;
                    final repsD = weekScheduleRepsDisplay(wi);
                    if (k > 0) detailCombo.write('\n');
                    detailCombo.write(
                      '${r.exerciseName}: ${wi.sets}×$repsD  ·  '
                      '${wi.loadKg?.toString() ?? '—'} kg  ·  '
                      '${wi.restBetweenSetsSec}s',
                    );
                  }
                  detailCombo.write(
                    '\nToque para escolher qual exercício editar.',
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Slidable(
                      key: ValueKey('snap_combo_${block.first.item.comboId}_$blockIndex'),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.56,
                        children: [
                          SlidableAction(
                            onPressed: (_) => _combineFromBlock(block),
                            backgroundColor: const Color(0xFF7E57C2),
                            foregroundColor: Colors.white,
                            icon: Icons.merge_type_rounded,
                            label: 'Combinar',
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                          ),
                          SlidableAction(
                            onPressed: (_) => _removeBlockAt(blockIndex),
                            backgroundColor:
                                AppColors.danger.withValues(alpha: 0.92),
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline_rounded,
                            label: 'Excluir',
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final choice = await showModalBottomSheet<
                                WeekScheduleRow>(
                              context: context,
                              backgroundColor: AppColors.barBackground,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Editar exercício do bloco',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    for (final r in block)
                                      ListTile(
                                        title: Text(
                                          r.exerciseName,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () => Navigator.pop(ctx, r),
                                      ),
                                  ],
                                ),
                              ),
                            );
                            if (!context.mounted || choice == null) return;
                            await _editRowWithId(choice.item.id);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.calendarFutureProgrammed
                                      .withValues(alpha: 0.2),
                                  AppColors.cadastroCardBorder
                                      .withValues(alpha: 0.11),
                                  Colors.black.withValues(alpha: 0.26),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.cadastroCardBorder.withValues(
                                  alpha: 0.82,
                                ),
                                width: 1.15,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.calendarFutureProgrammed
                                      .withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Combinação: $names',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  detailCombo.toString(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.52),
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: AppPrimaryButton(
            label: 'Programar no calendário',
            icon: Icons.check_rounded,
            onPressed: _rows.isEmpty
                ? null
                : () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    for (final r in _rows) {
                      if (!weekScheduleItemHasValidPrescription(r.item)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Toque em «${r.exerciseName}» e preencha séries e repetições.',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    await widget.onConfirm(List<WeekScheduleRow>.from(_rows));
                  },
          ),
        ),
      ],
    );
  }
}

/// Lista pesquisável de exercícios para incluir no snapshot do dia (modal aninhada).
class _DaySnapshotAddExercisePicker extends StatefulWidget {
  const _DaySnapshotAddExercisePicker({
    required this.scrollController,
    required this.repo,
    this.excludeExerciseIds,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final Set<String>? excludeExerciseIds;

  @override
  State<_DaySnapshotAddExercisePicker> createState() =>
      _DaySnapshotAddExercisePickerState();
}

class _DaySnapshotAddExercisePickerState
    extends State<_DaySnapshotAddExercisePicker> {
  final _queryC = TextEditingController();

  @override
  void dispose() {
    _queryC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;

    return FuturisticBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: AppCadastroSearchField(
              controller: _queryC,
              label: 'Buscar por nome',
              hint: 'Digite para filtrar',
              onChanged: (_) => setState(() {}),
              autofocus: true,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ExerciseEntity>>(
              stream: widget.repo.watchExercisesAlphabetical(),
              builder: (context, snap) {
                final all = snap.data ?? [];
                final excl = widget.excludeExerciseIds;
                final pool = excl == null || excl.isEmpty
                    ? all
                    : all.where((e) => !excl.contains(e.id)).toList();
                if (pool.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'Nenhum exercício cadastrado.'
                          : 'Nenhum exercício disponível (todos já estão neste dia).',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                final filtered = filterExercisesByNameQuery(
                  _queryC.text.trim(),
                  pool,
                );
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Nenhum exercício encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FuturisticCard(
                        onTap: () => Navigator.pop(context, e),
                        borderColor: blue.withValues(alpha: 0.82),
                        borderWidth: 1.1,
                        backgroundGradient: [
                          blueSoft.withValues(alpha: 0.2),
                          blue.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.touch_app_rounded,
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.85,
                              ),
                              size: 22,
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
      ),
    );
  }
}
