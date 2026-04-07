import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/exercise_registry_list_row.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
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
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: e.description,
                  onEdit: () => _groupForm(context, repo, e),
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(context, itemName: e.name);
                    if (ok == true && context.mounted) await repo.deleteWorkoutGroup(e.id);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.playlist_add, color: AppColors.accentGreen),
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

  void _groupForm(BuildContext context, AppDataRepository repo, WorkoutGroupEntity? x) {
    final name = TextEditingController(text: x?.name ?? '');
    final desc = TextEditingController(text: x?.description ?? '');
    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar novo grupo de treinos' : 'Editar grupo de treinos',
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppTextField(controller: name, label: 'Nome do grupo', required: true),
          const SizedBox(height: kCadastroFieldGap),
          AppTextField(controller: desc, label: 'Descrição', required: true, maxLines: 3),
          const SizedBox(height: kCadastroFieldGap),
          AppPrimaryButton(
            label: x == null ? 'Salvar grupo de treinos' : 'Atualizar grupo de treinos',
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

  void _exercisesEditor(BuildContext context, AppDataRepository repo, WorkoutGroupEntity group) {
    showAppModalSheet<void>(
      context: context,
      title: 'Exercícios — ${group.name}',
      builder: (ctx, _) => _GroupExercisesBody(
        repo: repo,
        group: group,
      ),
    );
  }
}

class _GroupExercisesBody extends StatelessWidget {
  const _GroupExercisesBody({
    required this.repo,
    required this.group,
  });

  static const double _iconScale = 0.7;

  final AppDataRepository repo;
  final WorkoutGroupEntity group;

  Future<void> _tryAddExercise(BuildContext context, String exerciseId) async {
    final ok = await repo.addExerciseToWorkoutGroup(
      workoutGroupId: group.id,
      exerciseId: exerciseId,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este exercício já está neste grupo.')),
      );
    }
  }

  Future<void> _reorderGroupLines(
    List<WorkoutGroupExerciseEntity> lines,
    int oldIndex,
    int newIndex,
  ) async {
    if (lines.length < 2) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= lines.length) return;

    final reordered = List<WorkoutGroupExerciseEntity>.from(lines);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);
    await repo.reorderWorkoutGroupExerciseLines(
      workoutGroupId: group.id,
      orderedLineIds: reordered.map((e) => e.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutGroupExerciseEntity>>(
      stream: repo.watchGroupExercises(group.id),
      builder: (context, snapLines) {
        final lines = snapLines.data ?? [];
        final inGroup = {for (final l in lines) l.exerciseId};
        return StreamBuilder<List<MuscleGroupEntity>>(
          stream: repo.watchMuscleGroupsAlphabetical(),
          builder: (context, snapG) {
            final groups = snapG.data ?? [];
            return StreamBuilder<List<ExerciseEntity>>(
              stream: repo.watchExercisesAlphabetical(),
              builder: (context, snapE) {
                final all = snapE.data ?? [];
                final idToExercise = {for (final e in all) e.id: e};

                final byGroupAvailable = <String, List<ExerciseEntity>>{};
                for (final e in all) {
                  if (inGroup.contains(e.id)) continue;
                  byGroupAvailable.putIfAbsent(e.muscleGroupId, () => []).add(e);
                }
                for (final entry in byGroupAvailable.entries) {
                  entry.value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                }
                final totalAvailable =
                    byGroupAvailable.values.fold<int>(0, (a, list) => a + list.length);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Toque no card para séries, repetições e carga. Arraste para a esquerda para remover. '
                        'As mudanças no modelo ficam salvas ao editar; use o botão Salvar e aplicar abaixo para '
                        'replicar nas agendas dos alunos.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.3,
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
                              itemCount: lines.length,
                              onReorder: (oldIndex, newIndex) =>
                                  _reorderGroupLines(lines, oldIndex, newIndex),
                              itemBuilder: (context, i) {
                                final line = lines[i];
                                final ex = idToExercise[line.exerciseId];
                                final name = ex?.name ?? 'Exercício';
                                final needs = _wgLineIncomplete(line);
                                final reps = _wgRepsDisplay(line);
                                return KeyedSubtree(
                                  key: ValueKey('wg_line_${line.id}'),
                                  child: ExerciseRegistryListRow(
                                    title: name,
                                    urgent: needs,
                                    slidableKey: line.id,
                                    subtitle:
                                        'Séries: ${line.lastSets ?? '—'}  Reps: ${reps.isEmpty ? '—' : reps}  '
                                        'Carga: ${line.lastLoadKg != null ? '${line.lastLoadKg} kg' : '—'}',
                                    onTap: () => _lineDialog(context, repo, line),
                                    onSlidableDelete: () async {
                                      await repo.removeWorkoutGroupExerciseLine(line.id);
                                    },
                                    trailing: [
                                      if (lines.length > 1)
                                        ReorderableDragStartListener(
                                          index: i,
                                          child: Icon(
                                            Icons.drag_indicator_rounded,
                                            color: Colors.white.withValues(alpha: 0.58),
                                            size: 22 * _iconScale,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Expanda um grupo muscular e toque no exercício ou no +.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.3,
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
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  children: [
                                    for (final g in groups)
                                      if ((byGroupAvailable[g.id] ?? []).isNotEmpty)
                                        ExerciseMuscleGroupSection(
                                          group: g,
                                          exerciseCount: byGroupAvailable[g.id]!.length,
                                          children: [
                                            for (final e in byGroupAvailable[g.id]!)
                                              ExerciseRegistryListRow(
                                                title: e.name,
                                                subtitle: exerciseVideoSubtitle(e),
                                                onTap: () => _tryAddExercise(context, e.id),
                                                trailing: [
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
                                                    onPressed: () => _tryAddExercise(context, e.id),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                  ],
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
                              repo,
                              group.id,
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

  void _lineDialog(
    BuildContext context,
    AppDataRepository repo,
    WorkoutGroupExerciseEntity line,
  ) {
    final setsC = TextEditingController(text: '${line.lastSets ?? 3}');
    final repsRaw = _wgRepsDisplay(line);
    final repsC = TextEditingController(
      text: repsRaw.isEmpty ? '12-15' : repsRaw,
    );
    final loadC = TextEditingController(
      text: line.lastLoadKg != null ? '${line.lastLoadKg}' : '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Exercício no grupo',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: setsC,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Séries *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: repsC,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Repetições *',
                  hintText: 'Ex.: 12-15',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: loadC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Carga (kg)',
                  hintText: 'Opcional',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final s = int.tryParse(setsC.text.trim());
              final repsStr = repsC.text.trim();
              if (s == null || s <= 0 || repsStr.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Informe séries (inteiro > 0) e repetições.'),
                    ),
                  );
                }
                return;
              }
              final loadTrim = loadC.text.trim();
              final l = loadTrim.isEmpty
                  ? null
                  : double.tryParse(loadTrim.replaceAll(',', '.'));
              if (loadTrim.isNotEmpty && l == null) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Carga inválida. Use número (ex.: 20 ou 12,5).')),
                  );
                }
                return;
              }
              await repo.updateWorkoutGroupExerciseLine(
                lineId: line.id,
                lastSets: s,
                lastRepsText: repsStr,
                lastLoadKg: l,
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
                              AppColors.cadastroCardBorder.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withValues(alpha: 0.12),
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
                                color: AppColors.accentGreen.withValues(alpha: 0.82),
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
                    maxHeight: (MediaQuery.sizeOf(context).height * 0.42)
                        .clamp(140.0, 320.0),
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
