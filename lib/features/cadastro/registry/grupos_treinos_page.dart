import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/combo_line_grouping_utils.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/exercise_prescription_edit_dialog.dart';
import '../../../core/widgets/exercise_registry_list_row.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/exercise_name_similarity.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

String _wgRepsDisplay(WorkoutGroupExerciseEntity line) {
  final t = line.lastRepsText?.trim();
  if (t != null && t.isNotEmpty) return t;
  if (line.lastReps != null) return '${line.lastReps}';
  return '';
}

bool _wgLineIncomplete(WorkoutGroupExerciseEntity line) {
  final sets = line.lastSets;
  if (sets == null || sets <= 0) return true;
  if (_wgRepsDisplay(line).isEmpty) return true;
  return false;
}

Future<bool?> _showFuturisticPropagateGroupDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _FuturisticPropagateGroupDialog(
      title: title,
      body: body,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

Future<void> _offerPropagateWorkoutGroup(
  BuildContext context,
  AppDataRepository repo,
  String workoutGroupId,
) async {
  final go = await _showFuturisticPropagateGroupDialog(
    context,
    title: 'Atualizar treinos planejados?',
    body:
        'Deseja alinhar séries, repetições, ordem e carga a partir de hoje?\n\n'
        '• Planejamento semanal: semanas a partir desta.\n'
        '• Calendário: treinos não concluídos e não cancelados (inclui em andamento).\n\n'
        'Não altera semanas passadas nem treinos concluídos ou cancelados.',
    cancelLabel: 'Agora não',
    confirmLabel: 'Atualizar',
  );
  if (go != true || !context.mounted) return;
  final r = await repo.propagateWorkoutGroupTemplateFromNow(workoutGroupId);
  if (!context.mounted) return;
  final w = r.weekItemsUpdated;
  final d = r.dayExercisesUpdated;
  final msg = (w == 0 && d == 0)
      ? 'Nenhum treino elegível para atualizar (sem vínculos futuros com este grupo).'
      : 'Planejamento: $w item(ns). Calendário: $d exercício(s) atualizados.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Confirma e aplica o modelo do grupo a treinos planejados/agendados (tela de exercícios do grupo).
Future<void> _confirmSaveAndApplyGroupTemplate(
  BuildContext context,
  AppDataRepository repo,
  String workoutGroupId,
) async {
  final go = await _showFuturisticPropagateGroupDialog(
    context,
    title: 'Aplicar este grupo aos treinos?',
    body:
        'Esta alteração no grupo de treino impactará todos os treinos não concluídos '
        'de todos os alunos que tenham este treino agendado ou planejado a partir de hoje, '
        'incluindo a tela de planejamento semanal e o calendário.\n\n'
        'Treinos concluídos ou cancelados não serão alterados.',
    cancelLabel: 'Cancelar',
    confirmLabel: 'Confirmar e aplicar',
  );
  if (go != true || !context.mounted) return;
  final r = await repo.propagateWorkoutGroupTemplateFromNow(workoutGroupId);
  if (!context.mounted) return;
  final w = r.weekItemsUpdated;
  final d = r.dayExercisesUpdated;
  final msg = (w == 0 && d == 0)
      ? 'Nenhum treino elegível para atualizar (sem vínculos futuros com este grupo).'
      : 'Planejamento: $w item(ns). Calendário: $d exercício(s) atualizados.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  Navigator.of(context).pop();
}

class GruposTreinosPage extends StatelessWidget {
  const GruposTreinosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Grupos de treinos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _groupForm(context, repo, null),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: FuturisticBackground(
        child: StreamBuilder<List<WorkoutGroupEntity>>(
          stream: repo.watchWorkoutGroupsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum grupo de treinos.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: e.description,
                  onEdit: () => _groupForm(context, repo, e),
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(
                      context,
                      itemName: e.name,
                    );
                    if (ok == true && context.mounted) {
                      await repo.deleteWorkoutGroup(e.id);
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.playlist_add,
                      color: AppColors.accentGreen,
                    ),
                    onPressed: () => _exercisesEditor(context, repo, e),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _groupForm(
    BuildContext context,
    AppDataRepository repo,
    WorkoutGroupEntity? x,
  ) {
    final name = TextEditingController(text: x?.name ?? '');
    final desc = TextEditingController(text: x?.description ?? '');
    showAppModalSheet<void>(
      context: context,
      title: x == null
          ? 'Cadastrar novo grupo de treinos'
          : 'Editar grupo de treinos',
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppTextField(
            controller: name,
            label: 'Nome do grupo',
            required: true,
          ),
          const SizedBox(height: kCadastroFieldGap),
          AppTextField(
            controller: desc,
            label: 'Descrição',
            required: true,
            maxLines: 3,
          ),
          const SizedBox(height: kCadastroFieldGap),
          AppPrimaryButton(
            label: x == null
                ? 'Salvar grupo de treinos'
                : 'Atualizar grupo de treinos',
            icon: Icons.check_rounded,
            onPressed: () async {
              if (name.text.trim().isEmpty || desc.text.trim().isEmpty) return;
              final gid = await repo.upsertWorkoutGroup(
                id: x?.id,
                name: name.text.trim(),
                description: desc.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                await _offerPropagateWorkoutGroup(context, repo, gid);
              }
            },
          ),
        ],
      ),
    );
  }

  void _exercisesEditor(
    BuildContext context,
    AppDataRepository repo,
    WorkoutGroupEntity group,
  ) {
    showAppModalSheet<void>(
      context: context,
      title: 'Exercícios — ${group.name}',
      builder: (ctx, _) => _GroupExercisesBody(repo: repo, group: group),
    );
  }
}

class _GroupExercisesBody extends StatefulWidget {
  const _GroupExercisesBody({required this.repo, required this.group});

  final AppDataRepository repo;
  final WorkoutGroupEntity group;

  @override
  State<_GroupExercisesBody> createState() => _GroupExercisesBodyState();
}

class _GroupExercisesBodyState extends State<_GroupExercisesBody> {
  static const double _iconScale = 0.7;

  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _tryAddExercise(BuildContext context, String exerciseId) async {
    final ok = await widget.repo.addExerciseToWorkoutGroup(
      workoutGroupId: widget.group.id,
      exerciseId: exerciseId,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este exercício já está neste grupo.')),
      );
    }
  }

  Future<void> _reorderComboBlocks(
    List<WorkoutGroupExerciseEntity> lines,
    int oldIndex,
    int newIndex,
  ) async {
    final blocks = workoutGroupLinesAsComboBlocks(lines);
    if (blocks.length < 2) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= blocks.length) return;

    final reordered = List<List<WorkoutGroupExerciseEntity>>.from(blocks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);
    final ids = <String>[];
    for (final b in reordered) {
      for (final line in b) {
        ids.add(line.id);
      }
    }
    await widget.repo.reorderWorkoutGroupExerciseLines(
      workoutGroupId: widget.group.id,
      orderedLineIds: ids,
    );
  }

  Future<ExerciseEntity?> _pickExerciseToCombine(
    BuildContext context, {
    required List<MuscleGroupEntity> groups,
    required List<ExerciseEntity> candidates,
  }) async {
    final searchC = TextEditingController();
    try {
      return await showAppModalSheet<ExerciseEntity>(
        context: context,
        title: 'Combinar com exercício',
        subtitle:
            'Mesmo bloco: sem intervalo entre estes movimentos durante o treino.',
        builder: (ctx, scroll) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              final filtered =
                  filterExercisesByNameQuery(searchC.text, candidates);
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
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        searchC.text.trim().isEmpty
                            ? 'Nenhum exercício disponível para combinar.'
                            : 'Nenhum resultado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (final e in filtered)
                      ListTile(
                        title: Text(
                          e.name,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          _addExerciseRowSubtitle(groups, e),
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
  }

  Future<void> _combineAfterAnchor(
    BuildContext context,
    WorkoutGroupExerciseEntity anchor,
    List<ExerciseEntity> flatAvailable,
    List<MuscleGroupEntity> groups,
  ) async {
    final picked = await _pickExerciseToCombine(
      context,
      groups: groups,
      candidates: flatAvailable,
    );
    if (!context.mounted || picked == null) return;
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: picked.name,
      badgeLabel: 'COMBINAR NO GRUPO',
      descriptionLine:
          'Prescrição deste exercício no bloco combinado (séries, reps, descanso após o bloco, carga, método).',
      headerIcon: Icons.merge_type_rounded,
      initialSets: 3,
      initialRepsText: '12-15',
      initialRestBetweenSetsSec: 60,
      initialLoadKg: null,
      initialTrainingMethodId: null,
    );
    if (!context.mounted || res == null) return;
    final ok = await widget.repo.combineWorkoutGroupExerciseLine(
      anchorLineId: anchor.id,
      secondExerciseId: picked.id,
      lastSets: res.sets,
      lastRepsText: res.repsText,
      lastLoadKg: res.loadKg,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível combinar (exercício já está no grupo ou é o mesmo).',
          ),
        ),
      );
    }
  }

  String _addExerciseRowSubtitle(
    List<MuscleGroupEntity> groups,
    ExerciseEntity e,
  ) {
    for (final g in groups) {
      if (g.id == e.muscleGroupId) {
        return '${g.name} · ${exerciseVideoSubtitle(e)}';
      }
    }
    return exerciseVideoSubtitle(e);
  }

  List<ExerciseEntity> _flatAvailableExercises(
    Map<String, List<ExerciseEntity>> byGroupAvailable,
  ) {
    final flat = <ExerciseEntity>[];
    for (final list in byGroupAvailable.values) {
      flat.addAll(list);
    }
    flat.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return flat;
  }

  List<Widget> _buildAddExerciseRows(
    List<MuscleGroupEntity> groups,
    List<ExerciseEntity> flatAvailable,
  ) {
    final filtered = filterExercisesByNameQuery(_searchC.text, flatAvailable);
    return [
      for (final e in filtered)
        ExerciseRegistryListRow(
          title: e.name,
          subtitle: _addExerciseRowSubtitle(groups, e),
          onTap: () => _tryAddExercise(context, e.id),
          trailing: [
            IconButton(
              tooltip: 'Adicionar ao grupo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.add_circle_rounded,
                color: kExerciseRegistryRowIconTint,
                size: 22 * _iconScale,
              ),
              onPressed: () => _tryAddExercise(context, e.id),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutGroupExerciseEntity>>(
      stream: widget.repo.watchGroupExercises(widget.group.id),
      builder: (context, snapLines) {
        final lines = snapLines.data ?? [];
        final inGroup = {for (final l in lines) l.exerciseId};
        return StreamBuilder<List<MuscleGroupEntity>>(
          stream: widget.repo.watchMuscleGroupsAlphabetical(),
          builder: (context, snapG) {
            final groups = snapG.data ?? [];
            return StreamBuilder<List<ExerciseEntity>>(
              stream: widget.repo.watchExercisesAlphabetical(),
              builder: (context, snapE) {
                final all = snapE.data ?? [];
                final idToExercise = {for (final e in all) e.id: e};

                final byGroupAvailable = <String, List<ExerciseEntity>>{};
                for (final e in all) {
                  if (inGroup.contains(e.id)) continue;
                  byGroupAvailable
                      .putIfAbsent(e.muscleGroupId, () => [])
                      .add(e);
                }
                for (final entry in byGroupAvailable.entries) {
                  entry.value.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                }
                final totalAvailable = byGroupAvailable.values.fold<int>(
                  0,
                  (a, list) => a + list.length,
                );
                final flatAvailable = _flatAvailableExercises(byGroupAvailable);
                final totalFiltered = filterExercisesByNameQuery(
                  _searchC.text,
                  flatAvailable,
                ).length;
                final blocks = workoutGroupLinesAsComboBlocks(lines);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: AppCadastroSearchField(
                        controller: _searchC,
                        label: 'Pesquisar exercício por nome',
                        hint: 'Digite parte do nome',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text(
                        'Neste grupo',
                        style: TextStyle(
                          color: AppColors.splashMint,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: lines.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum exercício ainda.\nAdicione na área abaixo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              buildDefaultDragHandles: false,
                              itemCount: blocks.length,
                              onReorder: (oldIndex, newIndex) =>
                                  _reorderComboBlocks(lines, oldIndex, newIndex),
                              itemBuilder: (context, bi) {
                                final block = blocks[bi];
                                final needs = block.any(_wgLineIncomplete);
                                if (block.length == 1) {
                                  final line = block.single;
                                  final ex = idToExercise[line.exerciseId];
                                  final name = ex?.name ?? 'Exercício';
                                  final reps = _wgRepsDisplay(line);
                                  return KeyedSubtree(
                                    key: ValueKey('wg_line_${line.id}'),
                                    child: ExerciseRegistryListRow(
                                      title: name,
                                      urgent: needs,
                                      slidableKey: line.id,
                                      subtitle:
                                          'Séries: ${line.lastSets ?? '—'}  Reps: ${reps.isEmpty ? '—' : reps}  '
                                          'Descanso: ${line.restBetweenSetsSec}s  '
                                          'Carga: ${line.lastLoadKg != null ? '${line.lastLoadKg} kg' : '—'}',
                                      onTap: () =>
                                          _lineDialog(context, line, name),
                                      onSlidableCombine: () => _combineAfterAnchor(
                                        context,
                                        line,
                                        flatAvailable,
                                        groups,
                                      ),
                                      onSlidableDelete: () async {
                                        await widget.repo
                                            .removeWorkoutGroupExerciseLine(
                                              line.id,
                                            );
                                      },
                                      trailing: [
                                        if (blocks.length > 1)
                                          ReorderableDragStartListener(
                                            index: bi,
                                            child: SizedBox(
                                              width: kMinInteractiveDimension,
                                              height: kMinInteractiveDimension,
                                              child: Center(
                                                child: Icon(
                                                  Icons.drag_indicator_rounded,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.58),
                                                  size: 26 * _iconScale,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }
                                final names = block
                                    .map(
                                      (l) =>
                                          idToExercise[l.exerciseId]?.name ??
                                          'Exercício',
                                    )
                                    .join(' · ');
                                final cid = block.first.comboId ?? '';
                                final sub = block
                                    .map((l) {
                                      final r = _wgRepsDisplay(l);
                                      final nm =
                                          idToExercise[l.exerciseId]?.name ??
                                          '…';
                                      return '$nm: ${l.lastSets ?? '—'}×${r.isEmpty ? '—' : r}';
                                    })
                                    .join('  |  ');
                                return KeyedSubtree(
                                  key: ValueKey('wg_combo_${cid}_$bi'),
                                  child: ExerciseRegistryListRow(
                                    title: 'Combinação: $names',
                                    urgent: needs,
                                    slidableKey: 'combo_$cid',
                                    subtitle: sub,
                                    onTap: () async {
                                      final choice = await showModalBottomSheet<
                                          WorkoutGroupExerciseEntity>(
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
                                              for (final line in block)
                                                ListTile(
                                                  title: Text(
                                                    idToExercise[line
                                                                .exerciseId]
                                                            ?.name ??
                                                        'Exercício',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  onTap: () =>
                                                      Navigator.pop(ctx, line),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                      if (!context.mounted || choice == null) {
                                        return;
                                      }
                                      final nm =
                                          idToExercise[choice.exerciseId]
                                              ?.name ??
                                          'Exercício';
                                      await _lineDialog(context, choice, nm);
                                    },
                                    onSlidableCombine: () =>
                                        _combineAfterAnchor(
                                          context,
                                          block.last,
                                          flatAvailable,
                                          groups,
                                        ),
                                    onSlidableDelete: () async {
                                      final cid0 = block.first.comboId;
                                      if (cid0 == null || cid0.isEmpty) {
                                        return;
                                      }
                                      final ok = await confirmDeleteDialog(
                                        context,
                                        itemName: names,
                                      );
                                      if (ok == true && context.mounted) {
                                        await widget.repo
                                            .removeWorkoutGroupComboBlock(
                                              workoutGroupId: widget.group.id,
                                              comboId: cid0,
                                            );
                                      }
                                    },
                                    trailing: [
                                      if (blocks.length > 1)
                                        ReorderableDragStartListener(
                                          index: bi,
                                          child: SizedBox(
                                            width: kMinInteractiveDimension,
                                            height: kMinInteractiveDimension,
                                            child: Center(
                                              child: Icon(
                                                Icons.drag_indicator_rounded,
                                                color: Colors.white
                                                    .withValues(alpha: 0.58),
                                                size: 26 * _iconScale,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.splashMint.withValues(alpha: 0.28),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text(
                        'Adicionar ao grupo',
                        style: TextStyle(
                          color: AppColors.splashMint,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: groups.isEmpty
                          ? Center(
                              child: Text(
                                'Cadastre grupos musculares e exercícios antes.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : totalAvailable == 0
                          ? const Center(
                              child: Text(
                                'Todos os exercícios já estão neste grupo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : totalFiltered == 0
                          ? Center(
                              child: Text(
                                'Nenhum exercício contém "${_searchC.text.trim()}" no nome.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(bottom: 12),
                              children: _buildAddExerciseRows(
                                groups,
                                flatAvailable,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPrimaryButton(
                            label: 'Salvar e aplicar',
                            icon: Icons.cloud_done_rounded,
                            onPressed: () => _confirmSaveAndApplyGroupTemplate(
                              context,
                              widget.repo,
                              widget.group.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _lineDialog(
    BuildContext context,
    WorkoutGroupExerciseEntity line,
    String exerciseName,
  ) async {
    final repsRaw = _wgRepsDisplay(line);
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: exerciseName,
      badgeLabel: 'EXERCÍCIO NO GRUPO',
      descriptionLine:
          'Séries, repetições, intervalo entre séries, carga e método de treino neste grupo.',
      headerIcon: Icons.tune_rounded,
      initialSets: line.lastSets ?? 3,
      initialRepsText: repsRaw.isEmpty ? '12-15' : repsRaw,
      initialRestBetweenSetsSec: line.restBetweenSetsSec,
      initialLoadKg: line.lastLoadKg,
      initialTrainingMethodId: line.trainingMethodId,
    );
    if (!context.mounted || res == null) return;
    await widget.repo.updateWorkoutGroupExerciseLine(
      lineId: line.id,
      lastSets: res.sets,
      lastRepsText: res.repsText,
      lastLoadKg: res.loadKg,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
    );
  }
}

/// Confirmação futurista para propagar modelo do grupo ao planejamento/calendário.
class _FuturisticPropagateGroupDialog extends StatelessWidget {
  const _FuturisticPropagateGroupDialog({
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.barBackground,
                  AppColors.backgroundDeep,
                  const Color(0xFF050508),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.52),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.14),
                  blurRadius: 26,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.headerGradientPink.withValues(alpha: 0.95),
                        AppColors.cadastroCardBorder.withValues(alpha: 0.9),
                        AppColors.headerGradientMint.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cadastroCardBorder.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentGreen.withValues(alpha: 0.2),
                              AppColors.cadastroCardBorder.withValues(
                                alpha: 0.08,
                              ),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.hub_rounded,
                            color: AppColors.accentGreen,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PROPAGAR MODELO',
                              style: TextStyle(
                                color: AppColors.accentGreen.withValues(
                                  alpha: 0.82,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.sizeOf(context).height * 0.42).clamp(
                      140.0,
                      320.0,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PropagateDialogSecondaryCta(
                        label: cancelLabel,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(height: 12),
                      _PropagateDialogPrimaryCta(
                        label: confirmLabel,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PropagateDialogSecondaryCta extends StatelessWidget {
  const _PropagateDialogSecondaryCta({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF12121A).withValues(alpha: 0.95),
            border: Border.all(
              color: AppColors.cadastroCardBorder.withValues(alpha: 0.5),
              width: 1.35,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.close_rounded,
                color: AppColors.splashMint.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.splashMint.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropagateDialogPrimaryCta extends StatelessWidget {
  const _PropagateDialogPrimaryCta({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.headerGradientMint,
                AppColors.accentGreen.withValues(alpha: 0.9),
                AppColors.headerGradientPink.withValues(alpha: 0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.headerGradientMint.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_done_rounded,
                color: const Color(0xFF0A0A12),
                size: 24,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0A0A12),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.15,
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
