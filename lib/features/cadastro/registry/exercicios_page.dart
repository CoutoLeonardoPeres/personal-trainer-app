import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/exercise_video_web_page.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/exercise_registry_list_row.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/exercise_name_similarity.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class ExerciciosPage extends StatelessWidget {
  const ExerciciosPage({super.key});

  static bool _hasVideoUrl(String? u) => u != null && u.trim().isNotEmpty;

  static void _openVideoInApp(BuildContext context, String raw, String title) {
    ExerciseVideoWebPage.showInAppWindow(context, initialUrl: raw, title: title);
  }

  Future<void> _addExercise(BuildContext context, AppDataRepository repo) async {
    final g = await repo.watchMuscleGroupsAlphabetical().first;
    final all = await repo.watchExercisesAlphabetical().first;
    if (!context.mounted) return;
    _openForm(context, repo, null, g, all);
  }

  static const double _rowScale = 0.7;

  Widget _exerciseRowCard(
    BuildContext context,
    AppDataRepository repo,
    ExerciseEntity e,
    List<ExerciseEntity> allExercises,
  ) {
    final iconEdit = 22 * _rowScale;
    final iconPlay = 28 * _rowScale;
    final iconAlt = 24 * _rowScale;
    return ExerciseRegistryListRow(
      title: e.name,
      subtitle: exerciseVideoSubtitle(e),
      slidableKey: e.id,
      onTap: () async {
        final gr = await repo.watchMuscleGroupsAlphabetical().first;
        if (!context.mounted) return;
        _openForm(context, repo, e, gr, allExercises);
      },
      onSlidableDelete: () async {
        final ok = await confirmDeleteDialog(context, itemName: e.name);
        if (ok == true && context.mounted) await repo.deleteExercise(e.id);
      },
      trailing: [
        IconButton(
          tooltip: 'Editar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: Icon(
            Icons.edit_outlined,
            color: kExerciseRegistryRowIconTint,
            size: iconEdit,
          ),
          onPressed: () async {
            final gr = await repo.watchMuscleGroupsAlphabetical().first;
            if (!context.mounted) return;
            _openForm(context, repo, e, gr, allExercises);
          },
        ),
        if (_hasVideoUrl(e.videoUrl))
          IconButton(
            tooltip: 'Abrir vídeo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Icon(
              Icons.play_circle_fill_rounded,
              color: kExerciseRegistryRowIconTint,
              size: iconPlay,
            ),
            onPressed: () => _openVideoInApp(context, e.videoUrl!, 'Vídeo — ${e.name}'),
          ),
        if (_hasVideoUrl(e.alternativeVideoUrl))
          IconButton(
            tooltip: 'Vídeo alternativo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Icon(
              Icons.video_library_rounded,
              color: kExerciseRegistryRowIconTint,
              size: iconAlt,
            ),
            onPressed: () => _openVideoInApp(
              context,
              e.alternativeVideoUrl!,
              'Vídeo alternativo — ${e.name}',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Scaffold(
      appBar: buildGradientAppBar(
        title: const Text('Cadastro de exercício'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo exercício',
            onPressed: () => _addExercise(context, repo),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExercise(context, repo),
        backgroundColor: AppColors.splashMint,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: FuturisticBackground(
        child: StreamBuilder<List<MuscleGroupEntity>>(
          stream: repo.watchMuscleGroupsAlphabetical(),
          builder: (context, snapG) {
            final groups = snapG.data ?? [];
            return StreamBuilder<List<ExerciseEntity>>(
              stream: repo.watchExercisesAlphabetical(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (groups.isEmpty) {
                  return const Center(
                    child: Text(
                      'Cadastre grupos musculares antes dos exercícios.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final byGroup = <String, List<ExerciseEntity>>{};
                for (final e in list) {
                  byGroup.putIfAbsent(e.muscleGroupId, () => []).add(e);
                }
                for (final entry in byGroup.entries) {
                  entry.value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: groups.length,
                  itemBuilder: (context, gi) {
                    final g = groups[gi];
                    final exercises = byGroup[g.id] ?? const <ExerciseEntity>[];

                    return ExerciseMuscleGroupSection(
                      group: g,
                      exerciseCount: exercises.length,
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
                            _exerciseRowCard(context, repo, e, list),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String? _muscleGroupName(List<MuscleGroupEntity> groups, String muscleGroupId) {
    for (final g in groups) {
      if (g.id == muscleGroupId) return g.name;
    }
    return null;
  }

  void _openForm(
    BuildContext context,
    AppDataRepository repo,
    ExerciseEntity? existing,
    List<MuscleGroupEntity> groups,
    List<ExerciseEntity> allExercises,
  ) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final videoC = TextEditingController(text: existing?.videoUrl ?? '');
    final altC = TextEditingController(text: existing?.alternativeNote ?? '');
    final altVidC = TextEditingController(text: existing?.alternativeVideoUrl ?? '');
    String? muscleId = existing?.muscleGroupId ??
        (groups.isNotEmpty ? groups.first.id : null);

    showAppModalSheet<void>(
      context: context,
      title: existing == null ? 'Cadastrar novo exercício' : 'Editar exercício',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) {
          final typedName = nameC.text.trim();
          final dup = typedName.isEmpty
              ? null
              : findDuplicateExerciseByNormalizedName(
                  typedName,
                  allExercises,
                  excludeExerciseId: existing?.id,
                );
          var similar = typedName.length < 2
              ? const <ExerciseEntity>[]
              : exercisesSimilarForCadastro(
                  typedName,
                  allExercises,
                  excludeExerciseId: existing?.id,
                );
          if (dup != null) {
            similar = similar.where((e) => e.id != dup.id).toList();
          }

          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              AppTextField(
                controller: nameC,
                label: 'Nome do exercício',
                required: true,
                onChanged: (_) => setSt(() {}),
              ),
              if (dup != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'Este nome já existe: "${dup.name}". Altere o nome ou edite o cadastro existente.',
                    style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              if (similar.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Nomes parecidos já cadastrados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ...similar.map((e) {
                  final gName = _muscleGroupName(groups, e.muscleGroupId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          e.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: gName != null
                            ? Text(
                                gName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: kCadastroFieldGap),
              DropdownButtonFormField<String>(
                key: ValueKey(muscleId),
                initialValue: muscleId,
                isExpanded: true,
                dropdownColor: AppColors.barBackground,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Grupo muscular *',
                ),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: groups.isEmpty ? null : (v) => setSt(() => muscleId = v),
              ),
              const SizedBox(height: kCadastroFieldGap),
              AppTextField(
                controller: videoC,
                label: 'Link vídeo (opcional)',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: kCadastroFieldGap),
              AppTextField(controller: altC, label: 'Alternativa (opcional)'),
              const SizedBox(height: kCadastroFieldGap),
              AppTextField(
                controller: altVidC,
                label: 'Link vídeo alternativa (opcional)',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: kCadastroFieldGap),
              AppPrimaryButton(
                label: existing == null ? 'Salvar exercício' : 'Atualizar exercício',
                icon: Icons.check_rounded,
                onPressed: dup != null
                    ? null
                    : () async {
                        final n = nameC.text.trim();
                        final m = muscleId;
                        if (n.isEmpty || m == null) return;
                        try {
                          await repo.upsertExercise(
                            id: existing?.id,
                            name: n,
                            muscleGroupId: m,
                            videoUrl:
                                videoC.text.trim().isEmpty ? null : videoC.text.trim(),
                            alternativeNote:
                                altC.text.trim().isEmpty ? null : altC.text.trim(),
                            alternativeVideoUrl: altVidC.text.trim().isEmpty
                                ? null
                                : altVidC.text.trim(),
                          );
                        } on DuplicateExerciseNameException catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Já existe um exercício com esse nome: "${e.existingDisplayName}".',
                              ),
                            ),
                          );
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
