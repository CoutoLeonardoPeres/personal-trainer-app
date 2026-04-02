import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/swipeable_registry_card.dart';
import '../../data/local/app_database.dart';
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
                  snap.connectionState == ConnectionState.waiting && !snap.hasData;

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
              if (studentId != null && students.isEmpty && waitingFirstStudents) {
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
                  studentId != null && students.any((s) => s.id == studentId)
                      ? studentId
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
          child: studentId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Selecione um aluno para ver e editar o planejamento.\n'
                      'Depois, deslize para os lados para mudar a semana.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _weekController,
                  onPageChanged: (p) => setState(() => _weekIndex = p),
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
                                  final rows = _uniqueWeekRowsByExercise(snap.data ?? []);
                                  return StreamBuilder<List<WorkoutGroupEntity>>(
                                    stream: repo.watchWorkoutGroupsAlphabetical(),
                                    builder: (context, gSnap) {
                                      final Map<String, WorkoutGroupEntity> groupById = {
                                        for (final g in gSnap.data ?? <WorkoutGroupEntity>[])
                                          g.id: g,
                                      };
                                      if (rows.isEmpty) {
                                        return _emptyHint(
                                          'Nenhum exercício agendado nesta semana.\n'
                                          'Use o botão Agendar treino para incluir grupos de treinos cadastrados.',
                                        );
                                      }
                                      final grouped = _partitionWeekRowsByGroup(rows);
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
                                              groupId: key,
                                              group: key == null
                                                  ? null
                                                  : groupById[key],
                                              rows: grouped[key]!,
                                            ),
                                        ],
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
                                  final all = snap.data ?? [];
                                  final programmed = all
                                      .where((w) =>
                                          w.status == 'programmed' ||
                                          w.status == 'started')
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
                                      _sectionTitle('Treinos concluídos'),
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
          child: SizedBox(
            width: double.infinity,
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
        ),
      ],
    );
  }

  /// Uma entrada por exercício na semana (primeira ocorrência vence).
  List<WeekScheduleRow> _uniqueWeekRowsByExercise(List<WeekScheduleRow> rows) {
    final seen = <String>{};
    return [
      for (final r in rows)
        if (seen.add(r.item.exerciseId)) r,
    ];
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
    List<WeekScheduleRow> groupRows,
  ) async {
    if (groupRows.isEmpty) return;
    final n = groupRows.length;
    final ok = await confirmDeleteDialog(
      context,
      itemName: n == 1 ? groupRows.first.exerciseName : '$n itens deste bloco',
    );
    if (ok != true || !context.mounted) return;
    for (final r in groupRows) {
      await repo.deleteWeekScheduleItem(r.item.id);
    }
  }

  Widget _weekGroupCard(
    BuildContext context,
    AppDataRepository repo,
    DateTime pageMonday, {
    required String? groupId,
    required WorkoutGroupEntity? group,
    required List<WeekScheduleRow> rows,
  }) {
    final title = group?.name ?? 'Exercícios avulsos';
    final needs = rows.where((r) => r.needsAttention).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentGreen.withValues(alpha: 0.28),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            leading: Icon(
              groupId == null ? Icons.sports_gymnastics_rounded : Icons.layers_rounded,
              color: AppColors.accentGreen,
              size: 26,
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group != null && group.description.isNotEmpty)
                    Text(
                      group.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    '${rows.length} exercício${rows.length == 1 ? '' : 's'}'
                    '${needs > 0 ? ' · $needs pendente${needs == 1 ? '' : 's'}' : ''}',
                    style: TextStyle(
                      color: needs > 0 ? AppColors.danger : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            iconColor: AppColors.accentGreen,
            collapsedIconColor: AppColors.accentGreen,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteGroupWeekItems(context, repo, rows),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  label: const Text(
                    'Remover da semana',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scheduledExerciseCard(
                    context,
                    repo,
                    pageMonday,
                    r,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduledExerciseCard(
    BuildContext context,
    AppDataRepository repo,
    DateTime weekMonday,
    WeekScheduleRow row,
  ) {
    final i = row.item;
    final subtitle = StringBuffer()
      ..write('Séries: ${i.sets}  Reps: ${i.reps}  ')
      ..write('Carga: ${i.loadKg?.toString() ?? '—'} kg');

    return SwipeableRegistryCard(
      slidableKey: i.id,
      title: row.exerciseName,
      subtitle: subtitle.toString(),
      onEdit: () => _editScheduleItemDialog(context, repo, row),
      onDelete: () async {
        final ok = await confirmDeleteDialog(context, itemName: row.exerciseName);
        if (ok == true && context.mounted) {
          await repo.deleteWeekScheduleItem(i.id);
        }
      },
      trailing: row.needsAttention
          ? Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22)
          : Icon(Icons.check_circle_outline, color: AppColors.accentGreen, size: 22),
    );
  }

  Widget _dayWorkoutTile(DayWorkoutEntity w, {bool showScore = false}) {
    final d = w.dayDate;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    var sub = 'Status: ${w.status}';
    if (showScore && w.workoutScore != null) {
      sub += '  ·  score: ${w.workoutScore!.toStringAsFixed(2)}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                color: AppColors.accentGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sub,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          t,
          style: const TextStyle(
            color: AppColors.accentGreen,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
        ),
      );

  Future<void> _editScheduleItemDialog(
    BuildContext context,
    AppDataRepository repo,
    WeekScheduleRow row,
  ) async {
    final i = row.item;
    final setsC = TextEditingController(text: i.sets > 0 ? '${i.sets}' : '');
    final repsC = TextEditingController(text: i.reps > 0 ? '${i.reps}' : '');
    final loadC = TextEditingController(
      text: i.loadKg != null ? i.loadKg!.toString() : '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: Text(
          row.exerciseName,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsC,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Séries *'),
            ),
            TextField(
              controller: repsC,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Repetições *'),
            ),
            TextField(
              controller: loadC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Carga (kg) opcional'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final s = int.tryParse(setsC.text.trim());
              final r = int.tryParse(repsC.text.trim());
              final lRaw = loadC.text.trim().replaceAll(',', '.');
              final l = lRaw.isEmpty ? null : double.tryParse(lRaw);
              if (s == null || r == null) return;
              await repo.updateWeekScheduleItem(
                itemId: i.id,
                sets: s,
                reps: r,
                loadKg: l,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

}
