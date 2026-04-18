import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_colors.dart';
import '../ui/exercise_video_web_page.dart';
import '../../data/local/app_database.dart';
import 'swipeable_registry_card.dart';

/// Ícones de ação no card (mesmo tom da tela de cadastro de exercícios).
const Color kExerciseRegistryRowIconTint = Color(0xFF90CAF9);

/// Subtítulo de vídeo alinhado à tela de cadastro de exercícios.
String exerciseVideoSubtitle(ExerciseEntity e) {
  bool has(String? u) => u != null && u.trim().isNotEmpty;
  final parts = <String>[];
  if (has(e.videoUrl)) parts.add('Vídeo');
  if (has(e.alternativeVideoUrl)) parts.add('Vídeo alt.');
  if (parts.isEmpty) return 'Sem links de vídeo';
  return parts.join(' • ');
}

bool exerciseEntityHasAnyVideoUrl(ExerciseEntity? e) {
  if (e == null) return false;
  bool has(String? u) => u != null && u.trim().isNotEmpty;
  return has(e.videoUrl) || has(e.alternativeVideoUrl);
}

void openExerciseVideoInApp(
  BuildContext context,
  String rawUrl,
  String title,
) {
  ExerciseVideoWebPage.showInAppWindow(
    context,
    initialUrl: rawUrl,
    title: title,
  );
}

/// Botões de vídeo principal / alternativo (mesmo padrão da tela de exercícios).
List<Widget> exerciseRegistryVideoTrailingButtons(
  BuildContext context,
  ExerciseEntity? ex,
  String exerciseDisplayName, {
  double iconSize = 22,
}) {
  if (ex == null) return const [];
  final widgets = <Widget>[];
  final main = ex.videoUrl?.trim();
  if (main != null && main.isNotEmpty) {
    widgets.add(
      IconButton(
        tooltip: 'Abrir vídeo',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        icon: Icon(
          Icons.play_circle_fill_rounded,
          color: kExerciseRegistryRowIconTint,
          size: iconSize,
        ),
        onPressed: () => openExerciseVideoInApp(
          context,
          main,
          'Vídeo — $exerciseDisplayName',
        ),
      ),
    );
  }
  final alt = ex.alternativeVideoUrl?.trim();
  if (alt != null && alt.isNotEmpty) {
    widgets.add(
      IconButton(
        tooltip: 'Vídeo alternativo',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        icon: Icon(
          Icons.video_library_rounded,
          color: kExerciseRegistryRowIconTint,
          size: iconSize * 0.92,
        ),
        onPressed: () => openExerciseVideoInApp(
          context,
          alt,
          'Vídeo alternativo — $exerciseDisplayName',
        ),
      ),
    );
  }
  return widgets;
}

Future<void> showExerciseBlockVideoLinksBottomSheet(
  BuildContext context, {
  required String title,
  required List<({String name, ExerciseEntity? exercise})> lines,
}) async {
  final withVideo = <({String name, ExerciseEntity ex})>[];
  for (final line in lines) {
    final ex = line.exercise;
    if (exerciseEntityHasAnyVideoUrl(ex)) {
      withVideo.add((name: line.name, ex: ex!));
    }
  }
  if (withVideo.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.barBackground,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            for (final entry in withVideo)
              ListTile(
                title: Text(
                  entry.name,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: exerciseRegistryVideoTrailingButtons(
                    ctx,
                    entry.ex,
                    entry.name,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Card de linha de exercício (azul translúcido) ou variante de alerta (vermelho).
class ExerciseRegistryListRow extends StatelessWidget {
  const ExerciseRegistryListRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing = const [],
    this.urgent = false,
    this.scale,
    this.backgroundGradient,
    this.borderColor,
    this.subtitleColor,
    this.slidableDeleteLabel = 'Excluir',
    this.onSlidableDelete,
    this.onSlidableCombine,
    this.slidableKey,
  });

  static const double _defaultScale = 0.7;
  static const double _fontBoost = 1.3;

  static const Color _cardBlueSubtitle = Color(0xFF90CAF9);

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final List<Widget> trailing;

  /// Destaque vermelho (ex.: falta séries/reps no grupo).
  final bool urgent;

  /// Ajustes visuais opcionais (usado em modais específicos).
  final double? scale;
  final List<Color>? backgroundGradient;
  final Color? borderColor;
  final Color? subtitleColor;
  final String slidableDeleteLabel;
  final VoidCallback? onSlidableDelete;
  final VoidCallback? onSlidableCombine;

  /// Identificador único para o [Slidable] (ex.: id do exercício).
  final String? slidableKey;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? _defaultScale;
    final padH = 12 * s;
    final padV = 12 * s;
    final radius = 14 * s;
    final titleSize = 15 * s * _fontBoost;
    final subSize = 12 * s * _fontBoost;

    final resolvedBorderColor =
        borderColor ??
        (urgent
            ? AppColors.danger.withValues(alpha: 0.72)
            : AppColors.cadastroCardBorder.withValues(alpha: 0.82));
    final splash = urgent
        ? AppColors.danger.withValues(alpha: 0.18)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.22);
    final highlight = urgent
        ? AppColors.danger.withValues(alpha: 0.1)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.12);
    final resolvedSubColor =
        subtitleColor ??
        (urgent
            ? AppColors.textMuted
            : _cardBlueSubtitle.withValues(alpha: 0.95));

    final resolvedGradient = backgroundGradient;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: resolvedBorderColor,
        width: urgent ? 1.0 : 1.05,
      ),
      gradient: urgent
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.danger.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.28),
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  resolvedGradient ??
                  [
                    AppColors.registryRowBlueDeep.withValues(alpha: 0.2),
                    AppColors.cadastroCardBorder.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.22),
                  ],
            ),
    );

    final card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: splash,
        highlightColor: highlight,
        child: Ink(
          decoration: decoration,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: titleSize,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4 * s),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: resolvedSubColor,
                          fontSize: subSize,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
        ),
      ),
    );

    if (onSlidableDelete == null && onSlidableCombine == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 6), child: card);
    }

    final r = kRegistrySlidableActionRadius * s;
    final actions = <Widget>[
      if (onSlidableCombine != null)
        SlidableAction(
          onPressed: (_) => onSlidableCombine!(),
          backgroundColor: const Color(0xFF7E57C2),
          foregroundColor: Colors.white,
          icon: Icons.merge_type_rounded,
          label: 'Combinar',
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r),
            bottomLeft: Radius.circular(r),
          ),
        ),
      if (onSlidableDelete != null)
        SlidableAction(
          onPressed: (_) => onSlidableDelete!(),
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          icon: Icons.delete_outline_rounded,
          label: slidableDeleteLabel,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(r),
            bottomRight: Radius.circular(r),
          ),
        ),
    ];
    final n = actions.length;
    final ratio = 0.22 * (n < 1 ? 1 : n);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Slidable(
        key: ValueKey(slidableKey ?? title),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: ratio.clamp(0.22, 0.66),
          children: actions,
        ),
        child: card,
      ),
    );
  }
}

/// Bloco de grupo muscular (ExpansionTile) igual ao da tela de exercícios.
class ExerciseMuscleGroupSection extends StatelessWidget {
  const ExerciseMuscleGroupSection({
    super.key,
    required this.group,
    required this.exerciseCount,
    required this.children,
    this.initiallyExpanded = false,

    /// Quando muda (ex.: texto da pesquisa), o tile é recriado e respeita [initiallyExpanded] de novo.
    this.expansionResetKey,
  });

  final MuscleGroupEntity group;
  final int exerciseCount;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Object? expansionResetKey;

  @override
  Widget build(BuildContext context) {
    final borderBlue = AppColors.cadastroCardBorder;
    final lightBlue = AppColors.registrySectionBlueLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightBlue.withValues(alpha: 0.17),
              borderBlue.withValues(alpha: 0.09),
              Colors.black.withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: borderBlue.withValues(alpha: 0.72),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: lightBlue.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: borderBlue.withValues(alpha: 0.14),
              highlightColor: lightBlue.withValues(alpha: 0.1),
            ),
            child: ExpansionTile(
              key: ValueKey<String>(
                expansionResetKey == null
                    ? 'mg_section_${group.id}'
                    : 'mg_section_${group.id}_$expansionResetKey',
              ),
              maintainState: true,
              initiallyExpanded: initiallyExpanded,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: Icon(
                Icons.fitness_center_rounded,
                color: lightBlue.withValues(alpha: 0.95),
                size: 26,
              ),
              title: Text(
                group.name,
                style: TextStyle(
                  color: lightBlue.withValues(alpha: 0.98),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              subtitle: Text(
                '$exerciseCount exercício${exerciseCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
              iconColor: borderBlue.withValues(alpha: 0.95),
              collapsedIconColor: borderBlue.withValues(alpha: 0.95),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
