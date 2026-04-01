import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

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
              await repo.upsertWorkoutGroup(
                id: x?.id,
                name: name.text.trim(),
                description: desc.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
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
      builder: (ctx, scroll) => _GroupExercisesBody(
        repo: repo,
        group: group,
        scrollController: scroll,
      ),
    );
  }
}

class _GroupExercisesBody extends StatelessWidget {
  const _GroupExercisesBody({
    required this.repo,
    required this.group,
    required this.scrollController,
  });

  final AppDataRepository repo;
  final WorkoutGroupEntity group;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<WorkoutGroupExerciseEntity>>(
            stream: repo.watchGroupExercises(group.id),
            builder: (context, snapLines) {
              final inGroup = {for (final l in snapLines.data ?? []) l.exerciseId};
              return StreamBuilder<List<ExerciseEntity>>(
                stream: repo.watchExercisesAlphabetical(),
                builder: (context, snap) {
                  final ex = snap.data ?? [];
                  final available = ex.where((e) => !inGroup.contains(e.id)).toList();
                  if (available.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Todos os exercícios cadastrados já estão neste grupo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    key: ValueKey(inGroup.length),
                    hint: const Text(
                      'Adicionar exercício',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    dropdownColor: AppColors.barBackground,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: [
                      for (final e in available)
                        DropdownMenuItem(value: e.id, child: Text(e.name)),
                    ],
                    onChanged: (id) async {
                      if (id == null) return;
                      final ok = await repo.addExerciseToWorkoutGroup(
                        workoutGroupId: group.id,
                        exerciseId: id,
                      );
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Este exercício já está neste grupo.'),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<WorkoutGroupExerciseEntity>>(
            stream: repo.watchGroupExercises(group.id),
            builder: (context, snap) {
              final lines = snap.data ?? [];
              if (lines.isEmpty) {
                return const Center(
                  child: Text(
                    'Adicione exercícios. Cards em vermelho no planejamento '
                    'quando faltar carga/séries/reps obrigatórios.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                );
              }
              return StreamBuilder<List<ExerciseEntity>>(
                stream: repo.watchExercisesAlphabetical(),
                builder: (context, snapE) {
                  final all = snapE.data ?? [];
                  final map = {for (final e in all) e.id: e.name};
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    itemBuilder: (_, i) {
                      final line = lines[i];
                      final needs = line.lastReps == null ||
                          line.lastReps == 0 ||
                          line.lastSets == null ||
                          line.lastSets == 0;
                      return Card(
                        color: needs
                            ? AppColors.danger.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                        child: ListTile(
                          title: Text(
                            map[line.exerciseId] ?? 'Exercício',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            'Séries: ${line.lastSets ?? '—'}  Reps: ${line.lastReps ?? '—'}  '
                            'Carga: ${line.lastLoadKg ?? '—'} kg',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.accentGreen),
                            onPressed: () => _lineDialog(context, repo, line),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _lineDialog(
    BuildContext context,
    AppDataRepository repo,
    WorkoutGroupExerciseEntity line,
  ) {
    final setsC = TextEditingController(text: line.lastSets?.toString() ?? '');
    final repsC = TextEditingController(text: line.lastReps?.toString() ?? '');
    final loadC = TextEditingController(text: line.lastLoadKg?.toString() ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text('Séries / reps / carga', style: TextStyle(color: AppColors.textPrimary)),
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
          TextButton(
            onPressed: () async {
              await repo.removeWorkoutGroupExerciseLine(line.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remover', style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () async {
              final s = int.tryParse(setsC.text.trim());
              final r = int.tryParse(repsC.text.trim());
              final l = double.tryParse(loadC.text.trim().replaceAll(',', '.'));
              if (s == null || r == null) return;
              await repo.updateWorkoutGroupExerciseLine(
                lineId: line.id,
                lastSets: s,
                lastReps: r,
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
