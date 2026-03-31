import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/exercise_video_web_page.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class ExerciciosPage extends StatelessWidget {
  const ExerciciosPage({super.key});

  static bool _hasVideoUrl(String? u) => u != null && u.trim().isNotEmpty;

  static String _videoSubtitle(ExerciseEntity e) {
    final parts = <String>[];
    if (_hasVideoUrl(e.videoUrl)) parts.add('Vídeo');
    if (_hasVideoUrl(e.alternativeVideoUrl)) parts.add('Vídeo alt.');
    if (parts.isEmpty) return 'Sem links de vídeo';
    return parts.join(' • ');
  }

  static void _openVideoInApp(BuildContext context, String raw, String title) {
    if (ExerciseVideoWebPage.normalizeVideoUri(raw) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço de vídeo inválido.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseVideoWebPage(initialUrl: raw, title: title),
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, AppDataRepository repo) async {
    final g = await repo.watchMuscleGroupsAlphabetical().first;
    if (!context.mounted) return;
    _openForm(context, repo, null, g);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de exercício'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.splashMint,
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.splashMint.withValues(alpha: 0.16),
                              AppColors.accentGreen.withValues(alpha: 0.06),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.splashMint.withValues(alpha: 0.28),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              splashColor: AppColors.splashMint.withValues(alpha: 0.12),
                              highlightColor: AppColors.splashMint.withValues(alpha: 0.08),
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey<String>('mg_${g.id}'),
                              maintainState: true,
                              initiallyExpanded: true,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Icon(
                                Icons.fitness_center_rounded,
                                color: AppColors.splashMint,
                                size: 26,
                              ),
                              title: Text(
                                g.name,
                                style: const TextStyle(
                                  color: AppColors.splashMint,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              subtitle: Text(
                                '${exercises.length} exercício${exercises.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: AppColors.splashMint.withValues(alpha: 0.78),
                                  fontSize: 13,
                                ),
                              ),
                              iconColor: AppColors.splashMint,
                              collapsedIconColor: AppColors.splashMint,
                              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                              children: [
                                if (exercises.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
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
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _ExerciseRow(
                                        exercise: e,
                                        videoSubtitle: _videoSubtitle(e),
                                        onEdit: () async {
                                          final gr =
                                              await repo.watchMuscleGroupsAlphabetical().first;
                                          if (!context.mounted) return;
                                          _openForm(context, repo, e, gr);
                                        },
                                        onDelete: () async {
                                          final ok = await confirmDeleteDialog(
                                            context,
                                            itemName: e.name,
                                          );
                                          if (ok == true && context.mounted) {
                                            await repo.deleteExercise(e.id);
                                          }
                                        },
                                        onOpenMainVideo: _hasVideoUrl(e.videoUrl)
                                            ? () => _openVideoInApp(
                                                  context,
                                                  e.videoUrl!,
                                                  'Vídeo — ${e.name}',
                                                )
                                            : null,
                                        onOpenAltVideo: _hasVideoUrl(e.alternativeVideoUrl)
                                            ? () => _openVideoInApp(
                                                  context,
                                                  e.alternativeVideoUrl!,
                                                  'Vídeo alternativo — ${e.name}',
                                                )
                                            : null,
                                      ),
                                    ),
                              ],
                            ),
                          ),
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
    );
  }

  void _openForm(
    BuildContext context,
    AppDataRepository repo,
    ExerciseEntity? existing,
    List<MuscleGroupEntity> groups,
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
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              AppTextField(controller: nameC, label: 'Nome do exercício', required: true),
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
                onPressed: () async {
                  final n = nameC.text.trim();
                  final m = muscleId;
                  if (n.isEmpty || m == null) return;
                  await repo.upsertExercise(
                    id: existing?.id,
                    name: n,
                    muscleGroupId: m,
                    videoUrl: videoC.text.trim().isEmpty ? null : videoC.text.trim(),
                    alternativeNote: altC.text.trim().isEmpty ? null : altC.text.trim(),
                    alternativeVideoUrl:
                        altVidC.text.trim().isEmpty ? null : altVidC.text.trim(),
                  );
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

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.videoSubtitle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenMainVideo,
    this.onOpenAltVideo,
  });

  final ExerciseEntity exercise;
  final String videoSubtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenMainVideo;
  final VoidCallback? onOpenAltVideo;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(exercise.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Excluir',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(kRegistrySlidableActionRadius),
              bottomRight: Radius.circular(kRegistrySlidableActionRadius),
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accentGreen.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        videoSubtitle,
                        style: TextStyle(
                          color: AppColors.splashMint.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 22,
                  ),
                  onPressed: onEdit,
                ),
                if (onOpenMainVideo != null)
                  IconButton(
                    tooltip: 'Abrir vídeo',
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 28,
                    ),
                    onPressed: onOpenMainVideo,
                  ),
                if (onOpenAltVideo != null)
                  IconButton(
                    tooltip: 'Vídeo alternativo',
                    icon: Icon(
                      Icons.video_library_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 24,
                    ),
                    onPressed: onOpenAltVideo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
