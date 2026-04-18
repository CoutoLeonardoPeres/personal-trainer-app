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
                final r = await repo.propagateWorkoutGroupTemplateFromNow(gid);
                if (!context.mounted) return;
                final w = r.weekItemsUpdated;
                final d = r.dayExercisesUpdated;
                final msg = (w == 0 && d == 0)
                    ? 'Grupo guardado. Nenhum treino elegível para alinhar com este modelo.'
                    : 'Grupo guardado. Planejamento: $w item(ns). Calendário: $d exercício(s) atualizado(s).';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _propagateAfterGroupMutation() async {
    try {
      await widget.repo.propagateWorkoutGroupTemplateFromNow(widget.group.id);
    } catch (_) {}
  }

  Future<void> _showGroupSavedFinishDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Grupo guardado',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'O grupo de treino foi salvo.\n\n'
          'As alterações são aplicadas ao planejamento semanal e aos treinos '
          'programados ou agendados no calendário (a partir de hoje), desde que '
          'ainda possam seguir automaticamente este modelo.\n\n'
          'No calendário, treinos já iniciados, já concluídos ou cancelados '
          'não são alterados.\n\n'
          'Se tiver ajustado manualmente prescrições no planejamento ou no '
          'calendário para treinos que continuam elegíveis para sincronização, '
          'o modelo do grupo pode voltar a alinhar esses valores.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExerciseInsertedDialog(
    BuildContext context, {
    required String exerciseName,
    required int totalOccurrencesInGroup,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: Text(
          totalOccurrencesInGroup <= 1
              ? 'Exercício adicionado'
              : 'Exercício adicionado novamente',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          totalOccurrencesInGroup <= 1
              ? '«$exerciseName» foi incluído neste grupo de treino.'
              : '«$exerciseName» foi incluído de novo. '
                    'Agora há $totalOccurrencesInGroup ocorrências deste exercício no grupo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Devolve `true` se o utilizador confirmar repetir o exercício.
  Future<bool> _confirmRepeatExerciseDialog(
    BuildContext context, {
    required String exerciseName,
    required int alreadyCount,
  }) async {
    final nextTotal = alreadyCount + 1;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Repetir exercício',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          '«$exerciseName» já está neste grupo $alreadyCount vez(es). '
          'Ao confirmar, passará a $nextTotal vez(es).\n\n'
          'Deseja mesmo adicionar outra ocorrência?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, repetir'),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _tryAddExercise(
    BuildContext context,
    String exerciseId,
    String exerciseName,
    List<WorkoutGroupExerciseEntity> currentLines,
  ) async {
    final already =
        currentLines.where((l) => l.exerciseId == exerciseId).length;
    if (already >= 1) {
      final ok = await _confirmRepeatExerciseDialog(
        context,
        exerciseName: exerciseName,
        alreadyCount: already,
      );
      if (!ok || !context.mounted) return;
    }

    final inserted = await widget.repo.addExerciseToWorkoutGroup(
      workoutGroupId: widget.group.id,
      exerciseId: exerciseId,
    );
    if (!inserted || !context.mounted) return;
    await _propagateAfterGroupMutation();
    if (!context.mounted) return;

    final after =
        already + 1; // nova linha = ocorrências após insert bem-sucedido
    await _showExerciseInsertedDialog(
      context,
      exerciseName: exerciseName,
      totalOccurrencesInGroup: after,
    );
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
    await _propagateAfterGroupMutation();
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
              final qRaw = searchC.text.trim();
              final byGroup = <String, List<ExerciseEntity>>{};
              for (final e in candidates) {
                byGroup.putIfAbsent(e.muscleGroupId, () => []).add(e);
              }
              for (final entry in byGroup.entries) {
                entry.value.sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
              }

              final visible =
                  <({MuscleGroupEntity g, List<ExerciseEntity> ex})>[];
              for (final g in groups) {
                final raw = byGroup[g.id] ?? const <ExerciseEntity>[];
                final exercises = qRaw.isEmpty
                    ? raw
                    : filterExercisesByNameQuery(qRaw, raw);
                if (qRaw.isNotEmpty && exercises.isEmpty) continue;
                visible.add((g: g, ex: exercises));
              }

              if (qRaw.isNotEmpty && visible.isEmpty) {
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
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum exercício contém "$qRaw" no nome.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: AppCadastroSearchField(
                      controller: searchC,
                      label: 'Pesquisar por nome',
                      hint: 'Digite para filtrar',
                      onChanged: (_) => setModal(() {}),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, gi) {
                        final entry = visible[gi];
                        final g = entry.g;
                        final exercises = entry.ex;
                        return ExerciseMuscleGroupSection(
                          group: g,
                          exerciseCount: exercises.length,
                          initiallyExpanded:
                              qRaw.isNotEmpty && exercises.isNotEmpty,
                          expansionResetKey: qRaw.isEmpty ? null : qRaw,
                          children: [
                            if (exercises.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'Nenhum exercício neste grupo.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              for (final e in exercises)
                                ExerciseRegistryListRow(
                                  title: e.name,
                                  subtitle: _addExerciseRowSubtitle(groups, e),
                                  scale: 0.62,
                                  onTap: () => Navigator.pop(ctx, e),
                                  trailing: exerciseRegistryVideoTrailingButtons(
                                    ctx,
                                    e,
                                    e.name,
                                    iconSize: 22 * _iconScale,
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
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
        const SnackBar(content: Text('Não foi possível combinar.')),
      );
    } else {
      await _propagateAfterGroupMutation();
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
    List<WorkoutGroupExerciseEntity> lines,
  ) {
    final filtered = filterExercisesByNameQuery(_searchC.text, flatAvailable);
    return [
      for (final e in filtered)
        ExerciseRegistryListRow(
          title: e.name,
          subtitle: _addExerciseRowSubtitle(groups, e),
          onTap: () => _tryAddExercise(context, e.id, e.name, lines),
          scale: 0.62,
          trailing: [
            ...exerciseRegistryVideoTrailingButtons(
              context,
              e,
              e.name,
              iconSize: 22 * _iconScale,
            ),
            IconButton(
              tooltip: 'Adicionar ao grupo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.add_circle_rounded,
                color: kExerciseRegistryRowIconTint,
                size: 22 * _iconScale,
              ),
              onPressed: () => _tryAddExercise(context, e.id, e.name, lines),
            ),
          ],
        ),
    ];
  }

  List<Widget> _buildAddExerciseRowsByMuscleGroup({
    required List<MuscleGroupEntity> groups,
    required Map<String, List<ExerciseEntity>> byGroupAvailable,
    required List<WorkoutGroupExerciseEntity> lines,
  }) {
    final tiles = <Widget>[];
    for (final g in groups) {
      final list = byGroupAvailable[g.id] ?? const <ExerciseEntity>[];
      if (list.isEmpty) continue;
      tiles.add(
        ExerciseMuscleGroupSection(
          group: g,
          exerciseCount: list.length,
          expansionResetKey:
              'wg_add_${widget.group.id}_${_searchC.text.trim()}',
          initiallyExpanded: false,
          children: [
            for (final e in list)
              ExerciseRegistryListRow(
                title: e.name,
                subtitle: exerciseVideoSubtitle(e),
                onTap: () => _tryAddExercise(context, e.id, e.name, lines),
                scale: 0.62,
                trailing: [
                  ...exerciseRegistryVideoTrailingButtons(
                    context,
                    e,
                    e.name,
                    iconSize: 22 * _iconScale,
                  ),
                  IconButton(
                    tooltip: 'Adicionar ao grupo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color: kExerciseRegistryRowIconTint,
                      size: 22 * _iconScale,
                    ),
                    onPressed: () => _tryAddExercise(context, e.id, e.name, lines),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutGroupExerciseEntity>>(
      stream: widget.repo.watchGroupExercises(widget.group.id),
      builder: (context, snapLines) {
        final lines = snapLines.data ?? [];
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
                                  _reorderComboBlocks(
                                    lines,
                                    oldIndex,
                                    newIndex,
                                  ),
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
                                      scale: 0.62,
                                      borderColor: AppColors.accentGreen
                                          .withValues(alpha: 0.55),
                                      subtitleColor: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      backgroundGradient: [
                                        AppColors.accentGreen.withValues(
                                          alpha: 0.16,
                                        ),
                                        AppColors.splashMint.withValues(
                                          alpha: 0.1,
                                        ),
                                        Colors.black.withValues(alpha: 0.22),
                                      ],
                                      subtitle:
                                          'Séries: ${line.lastSets ?? '—'}  Reps: ${reps.isEmpty ? '—' : reps}  '
                                          'Descanso: ${line.restBetweenSetsSec}s  '
                                          'Carga: ${line.lastLoadKg != null ? '${line.lastLoadKg} kg' : '—'}',
                                      onTap: () =>
                                          _lineDialog(context, line, name),
                                      onSlidableCombine: () =>
                                          _combineAfterAnchor(
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
                                        await _propagateAfterGroupMutation();
                                      },
                                      trailing: [
                                        ...exerciseRegistryVideoTrailingButtons(
                                          context,
                                          ex,
                                          name,
                                          iconSize: 22 * _iconScale,
                                        ),
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
                                    scale: 0.62,
                                    borderColor: AppColors.accentGreen
                                        .withValues(alpha: 0.55),
                                    subtitleColor: Colors.white.withValues(
                                      alpha: 0.62,
                                    ),
                                    backgroundGradient: [
                                      AppColors.accentGreen.withValues(
                                        alpha: 0.16,
                                      ),
                                      AppColors.splashMint.withValues(
                                        alpha: 0.1,
                                      ),
                                      Colors.black.withValues(alpha: 0.22),
                                    ],
                                    subtitle: sub,
                                    onTap: () async {
                                      final choice =
                                          await showModalBottomSheet<
                                            WorkoutGroupExerciseEntity
                                          >(
                                            context: context,
                                            backgroundColor:
                                                AppColors.barBackground,
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
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            line,
                                                          ),
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
                                        await _propagateAfterGroupMutation();
                                      }
                                    },
                                    trailing: [
                                      if (block.any(
                                        (l) => exerciseEntityHasAnyVideoUrl(
                                          idToExercise[l.exerciseId],
                                        ),
                                      ))
                                        IconButton(
                                          tooltip: 'Vídeos do bloco',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                            width: 40,
                                            height: 40,
                                          ),
                                          icon: Icon(
                                            Icons.ondemand_video_rounded,
                                            color: kExerciseRegistryRowIconTint,
                                            size: 24 * _iconScale,
                                          ),
                                          onPressed: () =>
                                              showExerciseBlockVideoLinksBottomSheet(
                                            context,
                                            title: 'Vídeos do bloco',
                                            lines: [
                                              for (final line in block)
                                                (
                                                  name:
                                                      idToExercise[line
                                                              .exerciseId]
                                                          ?.name ??
                                                      'Exercício',
                                                  exercise: idToExercise[
                                                    line.exerciseId
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      if (blocks.length > 1)
                                        ReorderableDragStartListener(
                                          index: bi,
                                          child: SizedBox(
                                            width: kMinInteractiveDimension,
                                            height: kMinInteractiveDimension,
                                            child: Center(
                                              child: Icon(
                                                Icons.drag_indicator_rounded,
                                                color: Colors.white.withValues(
                                                  alpha: 0.58,
                                                ),
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
                          : all.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum exercício cadastrado.',
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
                              children: _searchC.text.trim().isEmpty
                                  ? _buildAddExerciseRowsByMuscleGroup(
                                      groups: groups,
                                      byGroupAvailable: byGroupAvailable,
                                      lines: lines,
                                    )
                                  : _buildAddExerciseRows(
                                      groups,
                                      flatAvailable,
                                      lines,
                                    ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPrimaryButton(
                            label: 'Concluir',
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              await _showGroupSavedFinishDialog(context);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
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
    await _propagateAfterGroupMutation();
  }
}
