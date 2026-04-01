import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../core/widgets/swipeable_registry_card.dart';
import '../../data/local/app_database.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';

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
              return DropdownButtonFormField<String?>(
                key: ValueKey(studentId ?? '__none__'),
                initialValue: studentId,
                dropdownColor: AppColors.barBackground,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Aluno',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.accentGreen),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Selecione o aluno'),
                  ),
                  ...students.map(
                    (s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
                  ),
                ],
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
                                  final rows = snap.data ?? [];
                                  return StreamBuilder<List<WorkoutGroupEntity>>(
                                    stream: repo.watchWorkoutGroupsAlphabetical(),
                                    builder: (context, gSnap) {
                                      final Map<String, WorkoutGroupEntity> groupById = {
                                        for (final g in gSnap.data ?? <WorkoutGroupEntity>[])
                                          g.id: g,
                                      };
                                      if (rows.isEmpty) {
                                        return _emptyHint(
                                          'Nenhum grupo ou exercício nesta semana.\n'
                                          'Use «Grupo de treinos» ou «Agendar treino» (avulsos).',
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
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: studentId == null
                      ? null
                      : () => _openScheduleExercises(context, repo, studentId, weekMonday),
                  icon: const Icon(Icons.event_note),
                  label: const Text('Agendar treino'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: studentId == null
                      ? null
                      : () => _openScheduleGroup(context, repo, studentId, weekMonday),
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Grupo de treinos'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
            initiallyExpanded: true,
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

  Future<void> _openScheduleExercises(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime weekMonday,
  ) async {
    final exercises = await repo.watchExercisesAlphabetical().first;
    if (!context.mounted) return;
    final selected = <String>{};

    await showAppModalSheet<void>(
      context: context,
      title: 'Agendar exercícios na semana',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: exercises.length,
                  itemBuilder: (_, i) {
                    final e = exercises[i];
                    return CheckboxListTile(
                      value: selected.contains(e.id),
                      onChanged: (v) => setSt(() {
                        if (v == true) {
                          selected.add(e.id);
                        } else {
                          selected.remove(e.id);
                        }
                      }),
                      title: Text(
                        e.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      activeColor: AppColors.accentGreen,
                      checkColor: Colors.black,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: AppPrimaryButton(
                  label: 'Confirmar agendamento',
                  icon: Icons.check_rounded,
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          await repo.addExercisesToWeekSchedule(
                            studentId: studentId,
                            weekMonday: weekMonday,
                            exerciseIds: selected.toList(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openScheduleGroup(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime weekMonday,
  ) async {
    final groups = await repo.watchWorkoutGroupsAlphabetical().first;
    if (!context.mounted) return;

    await showAppModalSheet<void>(
      context: context,
      title: 'Grupo de treinos',
      builder: (ctx, scroll) {
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'Cadastre grupos de treinos em Cadastro.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: groups.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final g = groups[i];
            return Material(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                title: Text(
                  g.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  g.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.add_circle_outline, color: AppColors.accentGreen),
                onTap: () async {
                  await repo.copyWorkoutGroupToWeekSchedule(
                    studentId: studentId,
                    weekMonday: weekMonday,
                    workoutGroupId: g.id,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            );
          },
        );
      },
    );
  }
}
