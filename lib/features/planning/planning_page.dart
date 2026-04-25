import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../data/local/app_database.dart';
import '../../data/sync/supabase_auto_pull_scheduler.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/utils/combo_line_grouping_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../core/widgets/exercise_prescription_edit_dialog.dart';
import '../../core/widgets/exercise_registry_list_row.dart';
import '../../core/widgets/swipeable_registry_card.dart';
import '../../data/exercise_name_similarity.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';
import 'planning_schedule_workout_flow.dart';
import 'planning_student_selector.dart';

/// Semana em carrossel + aluno + persistência em [week_schedule_blocks] / [week_schedule_items].
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  late PageController _weekController;
  late int _weekIndex;
  String? _studentId;
  final Set<String> _expandedGroupKeys = <String>{};

  static final _epochMonday = _mondayOf(DateTime(2020, 1, 6));

  static DateTime _mondayOf(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final thisMonday = _mondayOf(now);
    _weekIndex = thisMonday.difference(_epochMonday).inDays ~/ 7;
    _weekController = PageController(initialPage: _weekIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      final sync = context.read<SupabaseSyncController>();
      final session = context.read<AppSession>();
      // Primeira abertura do separador: alinha SQLite com a nuvem (igual tablet).
      SupabaseAutoPullScheduler.scheduleAfterResume(
        db: db,
        sync: sync,
        session: session,
        delay: const Duration(milliseconds: 400),
        bypassMinInterval: true,
      );
    });
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  DateTime _mondayForPage(int page) =>
      _epochMonday.add(Duration(days: page * 7));

  String _weekLabel(DateTime monday) {
    final sun = monday.add(const Duration(days: 6));
    return '${monday.day}/${monday.month} — ${sun.day}/${sun.month}/${sun.year}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final weekMonday = _mondayForPage(_weekIndex);
    final studentId = _studentId;

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

              if (studentId == null && students.length == 1) {
                final only = students.single.id;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _studentId = only);
                });
              }

              if (studentId != null &&
                  students.isNotEmpty &&
                  !students.any((s) => s.id == studentId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _studentId = null);
                });
              }
              if (studentId != null && students.isEmpty && snap.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _studentId = null);
                });
              }
              if (studentId != null &&
                  students.isEmpty &&
                  waitingFirstStudents) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ModernLoadingIndicator(size: 28),
                  ),
                );
              }
              final dropdownValue =
                  studentId != null && students.any((s) => s.id == studentId)
                  ? studentId
                  : null;
              return PlanningFuturisticStudentSelector(
                key: ValueKey('aluno_${dropdownValue ?? 'none'}'),
                students: students,
                selectedId: dropdownValue,
                enabled: students.isNotEmpty,
                onChanged: (v) {
                  setState(() => _studentId = v);
                  final sid = v;
                  if (sid == null) return;
                  final mon = _mondayForPage(_weekIndex);
                  // Garantia: ao trocar o aluno, forçar pull da semana (calendário pode
                  // já ter `day_workouts`, mas o planejamento depende de `week_schedule_*`).
                  unawaited(
                    repo
                        .refreshStudentWeekScheduleFromCloud(
                          sid,
                          weekMonday: mon,
                        )
                        .timeout(const Duration(seconds: 25), onTimeout: () {}),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: studentId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Selecione um aluno para ver e editar o planejamento.\n'
                      'Depois, deslize para os lados para mudar a semana.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _weekController,
                  onPageChanged: (p) {
                    setState(() => _weekIndex = p);
                    final sid = _studentId;
                    if (sid == null) return;
                    final mon = _mondayForPage(p);
                    // Garantia: ao trocar a semana, forçar pull do planejamento daquela semana.
                    unawaited(
                      repo
                          .refreshStudentWeekScheduleFromCloud(
                            sid,
                            weekMonday: mon,
                          )
                          .timeout(const Duration(seconds: 25), onTimeout: () {}),
                    );
                  },
                  itemBuilder: (context, pageIndex) {
                    final pageMonday = _mondayForPage(pageIndex);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chevron_left,
                                size: 22,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Semana: ${_weekLabel(pageMonday)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right,
                                size: 22,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            primary: false,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _sectionTitle('Grupos de treino na semana'),
                              StreamBuilder<List<WeekScheduleRow>>(
                                key: ValueKey(
                                  '$studentId-${pageMonday.toIso8601String()}',
                                ),
                                stream: repo.watchWeekScheduleRows(
                                  studentId: studentId,
                                  weekMonday: pageMonday,
                                ),
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _emptyHint(
                                      'Não foi possível carregar o planejamento deste aluno.\n'
                                      '${snap.error}',
                                    );
                                  }
                                  final rows = snap.data ?? [];
                                  if (rows.isEmpty) {
                                    // Fallback: é possível ter treinos programados no calendário
                                    // (day_workouts) sem existir bloco/itens de planejamento
                                    // (week_schedule_*). Nesse caso, ainda assim mostrar os
                                    // grupos agendados da semana para não “sumir” na UI.
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _emptyHint(
                                          'Nenhum exercício agendado nesta semana.\n'
                                          'Use Agendar treino para montar a grade, ou Copiar treino para trazer a mesma semana de outro aluno.',
                                        ),
                                        const SizedBox(height: 10),
                                        StreamBuilder<List<DayWorkoutEntity>>(
                                          stream: repo.watchStudentWeekDayWorkouts(
                                            studentId: studentId,
                                            weekMonday: pageMonday,
                                          ),
                                          builder: (context, wSnap) {
                                            final all = wSnap.data ?? const [];
                                            final byGroup =
                                                <String, List<DayWorkoutEntity>>{};
                                            for (final w in all) {
                                              final gid =
                                                  (w.sourceWorkoutGroupId ?? '')
                                                      .trim();
                                              if (gid.isEmpty) continue;
                                              byGroup
                                                  .putIfAbsent(gid, () => [])
                                                  .add(w);
                                            }
                                            if (byGroup.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return StreamBuilder<
                                              List<WorkoutGroupEntity>
                                            >(
                                              stream: repo
                                                  .watchWorkoutGroupsAlphabetical(),
                                              builder: (context, gSnap) {
                                                final groupById = <String,
                                                  WorkoutGroupEntity>{
                                                  for (final g
                                                      in gSnap.data ??
                                                          <WorkoutGroupEntity>[])
                                                    g.id: g,
                                                };
                                                final keys = byGroup.keys.toList()
                                                  ..sort((a, b) {
                                                    final na =
                                                        groupById[a]?.name ??
                                                        a;
                                                    final nb =
                                                        groupById[b]?.name ??
                                                        b;
                                                    return na
                                                        .toLowerCase()
                                                        .compareTo(
                                                          nb.toLowerCase(),
                                                        );
                                                  });
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.stretch,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 6,
                                                        bottom: 8,
                                                      ),
                                                      child: Text(
                                                        'Grupos programados no calendário',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .accentGreen
                                                              .withValues(
                                                            alpha: 0.85,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 13,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ),
                                                    for (final gid in keys)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                          bottom: 10,
                                                        ),
                                                        child:
                                                            SwipeableRegistryCard(
                                                          slidableKey:
                                                              'week_calendar_group_${studentId}_${pageMonday.toIso8601String()}_$gid',
                                                          translucentBlueExerciseStyle:
                                                              true,
                                                          showEditOnSwipe: false,
                                                          title: groupById[gid]
                                                                  ?.name ??
                                                              'Grupo',
                                                          subtitle:
                                                              '${byGroup[gid]!.length} treino(s) na semana (calendário)',
                                                          onCardTap: () {},
                                                          onEdit: () {},
                                                          onDelete: () {},
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                  return StreamBuilder<
                                    List<WorkoutGroupEntity>
                                  >(
                                    stream: repo
                                        .watchWorkoutGroupsAlphabetical(),
                                    builder: (context, gSnap) {
                                      final groupById =
                                          <String, WorkoutGroupEntity>{
                                            for (final g
                                                in gSnap.data ??
                                                    <WorkoutGroupEntity>[])
                                              g.id: g,
                                          };
                                      return StreamBuilder<
                                        List<ExerciseEntity>
                                      >(
                                        stream: repo
                                            .watchExercisesAlphabetical(),
                                        builder: (context, exSnap) {
                                          final idToExercise =
                                              <String, ExerciseEntity>{
                                                for (final e
                                                    in exSnap.data ??
                                                        <ExerciseEntity>[])
                                                  e.id: e,
                                              };
                                          final grouped =
                                              _partitionWeekRowsByGroup(
                                            rows,
                                          );
                                          final keys = grouped.keys.toList()
                                            ..sort(
                                              (a, b) => _compareGroupKeys(
                                                a,
                                                b,
                                                groupById,
                                              ),
                                            );
                                          return Column(
                                            children: [
                                              for (final key in keys)
                                                _weekGroupCard(
                                                  context,
                                                  repo,
                                                  pageMonday,
                                                  allWeekRows: rows,
                                                  groupId: key,
                                                  group: key == null
                                                      ? null
                                                      : groupById[key],
                                                  rows: grouped[key]!,
                                                  idToExercise: idToExercise,
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              StreamBuilder<List<DayWorkoutEntity>>(
                                key: ValueKey(
                                  'week-workouts-$studentId-${pageMonday.toIso8601String()}',
                                ),
                                stream: repo.watchStudentWeekDayWorkouts(
                                  studentId: studentId,
                                  weekMonday: pageMonday,
                                ),
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _emptyHint(
                                      'Não foi possível carregar os treinos da semana.\n'
                                      '${snap.error}',
                                    );
                                  }
                                  final all = snap.data ?? [];
                                  final programmed = all
                                      .where(
                                        (w) =>
                                            w.status == 'programmed' ||
                                            w.status == 'started',
                                      )
                                      .toList();
                                  final completed = all
                                      .where((w) => w.status == 'completed')
                                      .toList();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _sectionTitle(
                                        'Treinos programados / em andamento',
                                      ),
                                      if (programmed.isEmpty)
                                        _emptyHint(
                                          'Nada programado no calendário para esta semana.',
                                        )
                                      else
                                        Column(
                                          children: [
                                            for (final w in programmed)
                                              _dayWorkoutTile(w),
                                          ],
                                        ),
                                      const SizedBox(height: 20),
                                      _sectionTitle(
                                        'Treinos concluídos',
                                        completedSection: true,
                                      ),
                                      if (completed.isEmpty)
                                        _emptyHint(
                                          'Nenhum treino concluído nesta semana.',
                                        )
                                      else
                                        Column(
                                          children: [
                                            for (final w in completed)
                                              _dayWorkoutTile(
                                                w,
                                                showScore: true,
                                                completed: true,
                                              ),
                                          ],
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: studentId == null
                      ? null
                      : () {
                          showPlanningScheduleWorkoutSheet(
                            context: context,
                            repo: repo,
                            studentId: studentId,
                            weekMonday: weekMonday,
                            weekLabel: _weekLabel(weekMonday),
                          );
                        },
                  icon: const Icon(Icons.event_note),
                  label: const Text('Agendar treino'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: studentId == null
                      ? null
                      : () {
                          showPlanningCopyWorkoutSheet(
                            context: context,
                            repo: repo,
                            targetStudentId: studentId,
                            weekMonday: weekMonday,
                            weekLabel: _weekLabel(weekMonday),
                          );
                        },
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copiar treino'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmFuturisticDelete(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Remover',
    String cancelLabel = 'Cancelar',
  }) async {
    final res = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'confirm',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, _) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                color: AppColors.barBackground.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white.withValues(
                                alpha: 0.82,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger.withValues(
                                alpha: 0.22,
                              ),
                              foregroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.55,
                                  ),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              confirmLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    return res ?? false;
  }

  Map<String?, List<WeekScheduleRow>> _partitionWeekRowsByGroup(
    List<WeekScheduleRow> rows,
  ) {
    final map = <String?, List<WeekScheduleRow>>{};
    for (final r in rows) {
      final k = r.item.sourceWorkoutGroupId;
      map.putIfAbsent(k, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
    }
    return map;
  }

  int _compareGroupKeys(
    String? a,
    String? b,
    Map<String, WorkoutGroupEntity> groupById,
  ) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final na = groupById[a]?.name ?? '';
    final nb = groupById[b]?.name ?? '';
    return na.toLowerCase().compareTo(nb.toLowerCase());
  }

  Future<void> _deleteGroupWeekItems(
    BuildContext context,
    AppDataRepository repo,
    List<WeekScheduleRow> groupRows, {
    required String keepExpandedKey,
  }) async {
    if (groupRows.isEmpty) return;
    final n = groupRows.length;
    final itemName = n == 1
        ? groupRows.first.exerciseName
        : '$n itens deste bloco';
    final ok = await _confirmFuturisticDelete(
      context,
      title: 'Remover da semana?',
      message:
          'Isso removerá $itemName do planejamento desta semana.\n\n'
          'Esta ação não apaga seu histórico de treinos concluídos.',
      confirmLabel: 'Remover',
    );
    if (ok != true || !context.mounted) return;

    // Mantém o bloco expandido após a atualização do stream.
    setState(() => _expandedGroupKeys.add(keepExpandedKey));
    for (final r in groupRows) {
      await repo.deleteWeekScheduleItem(r.item.id);
    }
  }

  Future<void> _reorderGroupWeekItems(
    AppDataRepository repo,
    List<WeekScheduleRow> groupRows,
    int oldIndex,
    int newIndex,
  ) async {
    final blocks = weekScheduleRowsAsComboBlocks(groupRows);
    if (blocks.length < 2) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= blocks.length) return;

    final reordered = List<List<WeekScheduleRow>>.from(blocks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);
    final ids = <String>[];
    for (final b in reordered) {
      for (final r in b) {
        ids.add(r.item.id);
      }
    }

    await repo.reorderWeekScheduleItemsInGroup(
      blockId: groupRows.first.item.blockId,
      sourceWorkoutGroupId: groupRows.first.item.sourceWorkoutGroupId,
      orderedItemIds: ids,
    );
  }

  Future<void> _combineWeekScheduleItem(
    BuildContext context,
    AppDataRepository repo, {
    required WeekScheduleRow anchor,
    required List<WeekScheduleRow> allWeekRows,
  }) async {
    final exercises = await repo.watchExercisesAlphabetical().first;
    final candidates = exercises;
    final groups = await repo.watchMuscleGroupsAlphabetical().first;
    if (!context.mounted) return;
    final searchC = TextEditingController();
    ExerciseEntity? picked;
    try {
      picked = await showAppModalSheet<ExerciseEntity>(
        context: context,
        title: 'Combinar com exercício',
        subtitle: 'Bloco sem intervalo entre os movimentos no treino.',
        builder: (ctx, scroll) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              final filtered = filterExercisesByNameQuery(
                searchC.text,
                candidates,
              );
              String sub(ExerciseEntity e) {
                for (final g in groups) {
                  if (g.id == e.muscleGroupId) return g.name;
                }
                return '';
              }

              return ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  AppCadastroSearchField(
                    controller: searchC,
                    label: 'Pesquisar por nome',
                    hint: 'Digite para filtrar',
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
                  for (final e in filtered)
                    ListTile(
                      title: Text(
                        e.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        sub(e),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, e),
                    ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchC.dispose();
    }
    if (!context.mounted || picked == null) return;
    final repsInit = weekScheduleRepsDisplay(anchor.item);
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: repo,
      exerciseName: picked.name,
      badgeLabel: 'PLANEJAMENTO · COMBINAR',
      descriptionLine:
          'Prescrição no bloco combinado. O descanso entre séries aplica-se após o último movimento do bloco.',
      headerIcon: Icons.merge_type_rounded,
      initialSets: anchor.item.sets > 0 ? anchor.item.sets : 3,
      initialRepsText: repsInit.isEmpty ? '12-15' : repsInit,
      initialRestBetweenSetsSec: anchor.item.restBetweenSetsSec,
      initialLoadKg: anchor.item.loadKg,
      initialTrainingMethodId: anchor.item.trainingMethodId,
    );
    if (!context.mounted || res == null) return;
    final ok = await repo.combineWeekScheduleItemWithExercise(
      anchorItemId: anchor.item.id,
      secondExerciseId: picked.id,
      sets: res.sets,
      repsText: res.repsText,
      repsHintInt: res.repsHintInt,
      loadKg: res.loadKg,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível combinar.')),
      );
    }
  }

  Widget _weekGroupCard(
    BuildContext context,
    AppDataRepository repo,
    DateTime pageMonday, {
    required List<WeekScheduleRow> allWeekRows,
    required String? groupId,
    required WorkoutGroupEntity? group,
    required List<WeekScheduleRow> rows,
    required Map<String, ExerciseEntity> idToExercise,
  }) {
    final expKey = groupId ?? 'avulsos';
    final expKeyFull = '${pageMonday.toIso8601String()}::$expKey';
    final rowBlocks = weekScheduleRowsAsComboBlocks(rows);
    final title = group?.name ?? 'Exercícios avulsos';
    final needs = rows.where((r) => r.needsAttention).length;
    final borderBlue = AppColors.cadastroCardBorder;
    final lightBlue = AppColors.registrySectionBlueLight;
    final expanded = _expandedGroupKeys.contains(expKeyFull);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cadastroCardBorder.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.45),
              AppColors.accentGreen.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: AppColors.cadastroCardBorder.withValues(alpha: 0.65),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGreen.withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: AppColors.accentGreen.withValues(alpha: 0.12),
              highlightColor: AppColors.accentGreen.withValues(alpha: 0.08),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                key: ValueKey('plan_group_$expKeyFull'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _expandedGroupKeys.remove(expKeyFull);
                        } else {
                          _expandedGroupKeys.add(expKeyFull);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(17),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            groupId == null
                                ? Icons.sports_gymnastics_rounded
                                : Icons.layers_rounded,
                            color: lightBlue.withValues(alpha: 0.95),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: lightBlue.withValues(alpha: 0.98),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (group != null &&
                                          group.description.isNotEmpty)
                                        Text(
                                          group.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.45,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      Text(
                                        '${rows.length} exercício${rows.length == 1 ? '' : 's'}'
                                        '${needs > 0 ? ' · $needs pendente${needs == 1 ? '' : 's'}' : ''}',
                                        style: TextStyle(
                                          color: needs > 0
                                              ? AppColors.danger
                                              : AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: borderBlue.withValues(alpha: 0.95),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    0,
                                    4,
                                    10,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.danger
                                            .withValues(alpha: 0.18),
                                        foregroundColor: AppColors.danger,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          side: BorderSide(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.55,
                                            ),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _deleteGroupWeekItems(
                                        context,
                                        repo,
                                        rows,
                                        keepExpandedKey: expKeyFull,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Remover da semana',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (rowBlocks.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      0,
                                      8,
                                      8,
                                    ),
                                    child: Text(
                                      'Arraste pelo ícone para alterar a ordem de execução.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                PrimaryScrollController.none(
                                  child: ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: rowBlocks.length,
                                    onReorder: (oldIndex, newIndex) =>
                                        _reorderGroupWeekItems(
                                          repo,
                                          rows,
                                          oldIndex,
                                          newIndex,
                                        ),
                                    itemBuilder: (context, index) {
                                      final br = rowBlocks[index];
                                      return KeyedSubtree(
                                        key: ValueKey(
                                          'week_block_${br.first.item.id}_${br.length}',
                                        ),
                                        child: _scheduledExerciseBlockCard(
                                          context,
                                          repo,
                                          pageMonday,
                                          br,
                                          allWeekRows: allWeekRows,
                                          dragIndex: index,
                                          allowReorder: rowBlocks.length > 1,
                                          idToExercise: idToExercise,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduledExerciseBlockCard(
    BuildContext context,
    AppDataRepository repo,
    DateTime weekMonday,
    List<WeekScheduleRow> block, {
    required List<WeekScheduleRow> allWeekRows,
    int? dragIndex,
    bool allowReorder = false,
    required Map<String, ExerciseEntity> idToExercise,
  }) {
    if (block.length == 1) {
      return _scheduledExerciseCard(
        context,
        repo,
        weekMonday,
        block.single,
        allWeekRows: allWeekRows,
        dragIndex: dragIndex,
        allowReorder: allowReorder,
        idToExercise: idToExercise,
      );
    }
    final names = block.map((r) => r.exerciseName).join(' · ');
    final i0 = block.first.item;
    final cid = i0.comboId ?? '';
    final sub = StringBuffer();
    for (var k = 0; k < block.length; k++) {
      final r = block[k];
      final i = r.item;
      final rd = weekScheduleRepsDisplay(i);
      if (k > 0) sub.write('  |  ');
      sub.write('${r.exerciseName}: ${i.sets}×$rd');
    }
    final needs = block.any((r) => r.needsAttention);

    return SwipeableRegistryCard(
      slidableKey: 'combo_week_$cid',
      translucentBlueExerciseStyle: true,
      title: 'Combinação: $names',
      subtitle: sub.toString(),
      onEdit: () {},
      showEditOnSwipe: false,
      onCardTap: () async {
        final choice = await showModalBottomSheet<WeekScheduleRow>(
          context: context,
          backgroundColor: AppColors.barBackground,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ),
        );
        if (!context.mounted || choice == null) return;
        await _editScheduleItemDialog(context, repo, choice);
      },
      onDelete: () async {
        final ok = await _confirmFuturisticDelete(
          context,
          title: 'Remover da semana?',
          message:
              'Isso removerá este bloco do planejamento desta semana.\n\n'
              'Exercícios: $names',
          confirmLabel: 'Remover',
        );
        if (ok == true && context.mounted && cid.isNotEmpty) {
          await repo.removeWeekScheduleComboBlock(
            blockId: i0.blockId,
            comboId: cid,
          );
        }
      },
      onSlidableCombine: () => _combineWeekScheduleItem(
        context,
        repo,
        anchor: block.last,
        allWeekRows: allWeekRows,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (block.any(
            (r) => exerciseEntityHasAnyVideoUrl(
              idToExercise[r.item.exerciseId],
            ),
          ))
            IconButton(
              tooltip: 'Vídeos do bloco',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.ondemand_video_rounded,
                color: kExerciseRegistryRowIconTint,
                size: 22,
              ),
              onPressed: () => showExerciseBlockVideoLinksBottomSheet(
                context,
                title: 'Vídeos do bloco',
                lines: [
                  for (final r in block)
                    (
                      name: r.exerciseName,
                      exercise: idToExercise[r.item.exerciseId],
                    ),
                ],
              ),
            ),
          needs
              ? Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 22,
                )
              : Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accentGreen,
                  size: 22,
                ),
          if (allowReorder && dragIndex != null) ...[
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: dragIndex,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white.withValues(alpha: 0.58),
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduledExerciseCard(
    BuildContext context,
    AppDataRepository repo,
    DateTime weekMonday,
    WeekScheduleRow row, {
    required List<WeekScheduleRow> allWeekRows,
    int? dragIndex,
    bool allowReorder = false,
    required Map<String, ExerciseEntity> idToExercise,
  }) {
    final i = row.item;
    final repsDisp = weekScheduleRepsDisplay(i);
    final subtitle = StringBuffer()
      ..write('Séries: ${i.sets}  Reps: $repsDisp  ')
      ..write('Carga: ${i.loadKg?.toString() ?? '—'} kg');

    return SwipeableRegistryCard(
      slidableKey: i.id,
      translucentBlueExerciseStyle: true,
      title: row.exerciseName,
      subtitle: subtitle.toString(),
      onEdit: () {},
      showEditOnSwipe: false,
      onCardTap: () => _editScheduleItemDialog(context, repo, row),
      onDelete: () async {
        final ok = await _confirmFuturisticDelete(
          context,
          title: 'Remover da semana?',
          message:
              'Isso removerá este exercício do planejamento desta semana.\n\n'
              'Exercício: ${row.exerciseName}',
          confirmLabel: 'Remover',
        );
        if (ok == true && context.mounted) {
          final parentKey = row.item.sourceWorkoutGroupId ?? 'avulsos';
          final keepKey = '${weekMonday.toIso8601String()}::$parentKey';
          setState(() => _expandedGroupKeys.add(keepKey));
          await repo.deleteWeekScheduleItem(i.id);
        }
      },
      onSlidableCombine: () => _combineWeekScheduleItem(
        context,
        repo,
        anchor: row,
        allWeekRows: allWeekRows,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...exerciseRegistryVideoTrailingButtons(
            context,
            idToExercise[row.item.exerciseId],
            row.exerciseName,
          ),
          row.needsAttention
              ? Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 22,
                )
              : Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accentGreen,
                  size: 22,
                ),
          if (allowReorder && dragIndex != null) ...[
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: dragIndex,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white.withValues(alpha: 0.58),
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayWorkoutTile(
    DayWorkoutEntity w, {
    bool showScore = false,
    bool completed = false,
  }) {
    final d = w.dayDate;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    var sub = 'Status: ${w.status}';
    if (showScore && w.workoutScore != null) {
      sub += '  ·  score: ${w.workoutScore!.toStringAsFixed(2)}';
    }
    final border = completed
        ? AppColors.accentGreen
        : AppColors.cadastroCardBorder;
    final light = completed ? AppColors.splashMint : AppColors.accentGreen;
    final subColor = completed
        ? AppColors.accentGreen.withValues(alpha: 0.82)
        : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cadastroCardBorder.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.45),
              AppColors.accentGreen.withValues(alpha: completed ? 0.1 : 0.06),
            ],
          ),
          border: Border.all(
            color: border.withValues(alpha: 0.65),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGreen.withValues(
                alpha: completed ? 0.16 : 0.12,
              ),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              dateStr,
              style: TextStyle(
                color: light.withValues(alpha: 0.96),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(sub, style: TextStyle(color: subColor, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, {bool completedSection = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      t,
      style: TextStyle(
        color:
            (completedSection
                    ? AppColors.accentGreen
                    : AppColors.registrySectionBlueLight)
                .withValues(alpha: 0.92),
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );

  Widget _emptyHint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 13,
      ),
    ),
  );

  Future<void> _editScheduleItemDialog(
    BuildContext context,
    AppDataRepository repo,
    WeekScheduleRow row,
  ) async {
    final i = row.item;
    final repsInit = weekScheduleRepsDisplay(i);
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: repo,
      exerciseName: row.exerciseName,
      badgeLabel: 'PLANEJAMENTO SEMANAL',
      descriptionLine:
          'Séries, repetições, intervalo entre séries, carga e método de treino para esta semana.',
      headerIcon: Icons.view_week_rounded,
      initialSets: i.sets > 0 ? i.sets : 3,
      initialRepsText: repsInit.isEmpty ? '12-15' : repsInit,
      initialRestBetweenSetsSec: i.restBetweenSetsSec,
      initialLoadKg: i.loadKg,
      initialTrainingMethodId: i.trainingMethodId,
    );
    if (!context.mounted || res == null) return;
    await repo.updateWeekScheduleItem(
      itemId: i.id,
      sets: res.sets,
      repsText: res.repsText,
      repsHintInt: res.repsHintInt,
      loadKg: res.loadKg,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
    );
  }
}
