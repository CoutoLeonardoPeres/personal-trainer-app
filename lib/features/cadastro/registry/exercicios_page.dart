import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/exercise_video_web_page.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/exercise_registry_list_row.dart';
import '../../../core/widgets/muscle_group_picker_sheet.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/exercise_name_similarity.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class ExerciciosPage extends StatefulWidget {
  const ExerciciosPage({super.key});

  @override
  State<ExerciciosPage> createState() => _ExerciciosPageState();
}

class _ExerciciosPageState extends State<ExerciciosPage> {
  final TextEditingController _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  bool _hasVideoUrl(String? u) => u != null && u.trim().isNotEmpty;

  /// Outro exercício cujo [ExerciseEntity.videoUrl] coincide com a alternativa (edição).
  String? _inferAltSourceExerciseId(
    ExerciseEntity? existing,
    List<ExerciseEntity> all,
  ) {
    if (existing == null) return null;
    final av = existing.alternativeVideoUrl?.trim() ?? '';
    if (av.isEmpty) return null;
    for (final e in all) {
      if (e.id == existing.id) continue;
      final v = e.videoUrl?.trim() ?? '';
      if (v.isNotEmpty && v == av) return e.id;
    }
    return null;
  }

  void _openVideoInApp(BuildContext context, String raw, String title) {
    ExerciseVideoWebPage.showInAppWindow(
      context,
      initialUrl: raw,
      title: title,
    );
  }

  Future<void> _addExercise(
    BuildContext context,
    AppDataRepository repo,
  ) async {
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
        final ok = await confirmDeleteDialog(
          context,
          itemName: e.name,
          title: 'Excluir exercício?',
          entityTag: 'Exercício',
        );
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
            onPressed: () =>
                _openVideoInApp(context, e.videoUrl!, 'Vídeo — ${e.name}'),
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
      appBar: buildGradientAppBar(title: const Text('Cadastro de exercício')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExercise(context, repo),
        backgroundColor: AppColors.splashMint,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                  entry.value.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                }

                final qRaw = _searchC.text.trim();
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: AppCadastroSearchField(
                          controller: _searchC,
                          label: 'Pesquisar exercício por nome',
                          hint: 'Digite parte do nome',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Nenhum exercício contém "$qRaw" no nome.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: AppCadastroSearchField(
                        controller: _searchC,
                        label: 'Pesquisar exercício por nome',
                        hint: 'Digite parte do nome',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
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
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String? _muscleGroupName(
    List<MuscleGroupEntity> groups,
    String muscleGroupId,
  ) {
    for (final g in groups) {
      if (g.id == muscleGroupId) return g.name;
    }
    return null;
  }

  /// Mantém [altFromExerciseId] só se nome e URL ainda batem com o exercício vinculado.
  void _reconcileAlternativeExerciseLink({
    required TextEditingController altC,
    required TextEditingController altVidC,
    required List<ExerciseEntity> all,
    required String? linkedId,
    required void Function(String? id) setLinkedId,
  }) {
    if (linkedId == null) return;
    ExerciseEntity? linked;
    for (final x in all) {
      if (x.id == linkedId) {
        linked = x;
        break;
      }
    }
    if (linked == null) {
      setLinkedId(null);
      return;
    }
    if (normalizeExerciseName(altC.text) !=
        normalizeExerciseName(linked.name)) {
      setLinkedId(null);
      return;
    }
    final u = linked.videoUrl?.trim() ?? '';
    if (u.isNotEmpty && altVidC.text.trim() != u) {
      setLinkedId(null);
    }
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
    final altVidC = TextEditingController(
      text: existing?.alternativeVideoUrl ?? '',
    );
    String? muscleId =
        existing?.muscleGroupId ?? (groups.isNotEmpty ? groups.first.id : null);
    String? altFromExerciseId = _inferAltSourceExerciseId(
      existing,
      allExercises,
    );

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

          final altQ = altC.text.trim();
          var altMatches = altQ.isEmpty
              ? const <ExerciseEntity>[]
              : exercisesNameContains(
                  altQ,
                  allExercises,
                  excludeExerciseId: existing?.id,
                );
          altMatches = List<ExerciseEntity>.from(altMatches)
            ..sort((a, b) {
              final av = _hasVideoUrl(a.videoUrl);
              final bv = _hasVideoUrl(b.videoUrl);
              if (av != bv) {
                return av ? -1 : 1;
              }
              return normalizeExerciseName(
                a.name,
              ).compareTo(normalizeExerciseName(b.name));
            });
          if (altMatches.length > 20) {
            altMatches = altMatches.sublist(0, 20);
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
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.45),
                    ),
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
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.cadastroCardBorder.withValues(
                            alpha: 0.048,
                          ),
                          border: Border.all(
                            color: AppColors.cadastroCardBorder.withValues(
                              alpha: 0.42,
                            ),
                          ),
                        ),
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
                    ),
                  );
                }),
              ],
              const SizedBox(height: kCadastroFieldGap),
              MuscleGroupPickerField(
                groups: groups,
                selectedId: muscleId,
                onPick: (id) => setSt(() => muscleId = id),
              ),
              const SizedBox(height: kCadastroFieldGap),
              AppTextField(
                controller: videoC,
                label: 'Link vídeo (opcional)',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: kCadastroFieldGap),
              Text(
                'Alternativa',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Digite no campo abaixo: aparecem logo em seguida os exercícios '
                'cadastrados cujo nome contém o texto (lista no próprio campo). '
                'Toque para usar nome e vídeo do cadastro. Se nenhum bater, '
                'o texto vale como alternativa nova — preencha o link embaixo.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: kCadastroFieldGap),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: altC,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.splashMint,
                    decoration: cadastroFieldInputDecoration(
                      labelText: 'Nome da alternativa',
                      hintText: 'Buscar no cadastro ou nome novo',
                    ),
                    onChanged: (_) {
                      setSt(() {
                        if (altC.text.trim().isEmpty) {
                          altFromExerciseId = null;
                        } else {
                          _reconcileAlternativeExerciseLink(
                            altC: altC,
                            altVidC: altVidC,
                            all: allExercises,
                            linkedId: altFromExerciseId,
                            setLinkedId: (id) => altFromExerciseId = id,
                          );
                        }
                      });
                    },
                  ),
                  if (altMatches.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.cadastroCardBorder.withValues(
                          alpha: 0.07,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.splashMint.withValues(alpha: 0.42),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: altMatches.length,
                            separatorBuilder: (context, _) => Divider(
                              height: 1,
                              thickness: 0.6,
                              color: AppColors.cadastroCardBorder.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            itemBuilder: (context, index) {
                              final e = altMatches[index];
                              final gName =
                                  _muscleGroupName(groups, e.muscleGroupId);
                              final hasVid = _hasVideoUrl(e.videoUrl);
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setSt(() {
                                      altC.text = e.name;
                                      altVidC.text = e.videoUrl?.trim() ?? '';
                                      altFromExerciseId =
                                          hasVid ? e.id : null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          hasVid
                                              ? Icons
                                                  .play_circle_fill_rounded
                                              : Icons.videocam_off_outlined,
                                          color: hasVid
                                              ? AppColors.splashMint
                                                  .withValues(alpha: 0.88)
                                              : Colors.white.withValues(
                                                  alpha: 0.35,
                                                ),
                                          size: 26,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.name,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (gName != null)
                                                Text(
                                                  gName,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(
                                                      alpha: 0.45,
                                                    ),
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              Text(
                                                hasVid
                                                    ? 'Toque para usar este cadastro'
                                                    : 'Sem vídeo no cadastro — defina o link abaixo',
                                                style: TextStyle(
                                                  color: AppColors
                                                      .registrySectionBlueLight
                                                      .withValues(alpha: 0.82),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 22,
                                          color: AppColors.splashMint
                                              .withValues(alpha: 0.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else if (altQ.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nenhum exercício cadastrado contém "$altQ". '
                      'Pode salvar como alternativa nova e informar o link do vídeo abaixo.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
              if (altC.text.trim().isNotEmpty ||
                  altVidC.text.trim().isNotEmpty) ...[
                const SizedBox(height: kCadastroFieldGap),
                AppTextField(
                  controller: altVidC,
                  label: 'Link vídeo da alternativa',
                  hint: altFromExerciseId != null
                      ? 'Preenchido pela seleção; edite se quiser'
                      : (altC.text.trim().isNotEmpty
                            ? 'Obrigatório para salvar com este nome'
                            : 'Opcional se só houver link'),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    setSt(() {
                      _reconcileAlternativeExerciseLink(
                        altC: altC,
                        altVidC: altVidC,
                        all: allExercises,
                        linkedId: altFromExerciseId,
                        setLinkedId: (id) => altFromExerciseId = id,
                      );
                    });
                  },
                ),
              ],
              const SizedBox(height: kCadastroFieldGap),
              AppPrimaryButton(
                label: existing == null
                    ? 'Salvar exercício'
                    : 'Atualizar exercício',
                icon: Icons.check_rounded,
                onPressed: dup != null
                    ? null
                    : () async {
                        final n = nameC.text.trim();
                        final m = muscleId;
                        if (n.isEmpty || m == null) return;
                        final altNote = altC.text.trim();
                        final altVid = altVidC.text.trim();
                        if (altNote.isNotEmpty && altVid.isEmpty) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Informe o link do vídeo da alternativa ou apague o nome da alternativa.',
                              ),
                            ),
                          );
                          return;
                        }
                        try {
                          await repo.upsertExercise(
                            id: existing?.id,
                            name: n,
                            muscleGroupId: m,
                            videoUrl: videoC.text.trim().isEmpty
                                ? null
                                : videoC.text.trim(),
                            alternativeNote: altC.text.trim().isEmpty
                                ? null
                                : altC.text.trim(),
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
