import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_colors.dart';
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

/// Card de linha de exercício (azul) ou variante de alerta (vermelho) — mesmo padrão visual do cadastro de exercícios.
class ExerciseRegistryListRow extends StatelessWidget {
  const ExerciseRegistryListRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing = const [],
    this.urgent = false,
    this.slidableDeleteLabel = 'Excluir',
    this.onSlidableDelete,
    this.slidableKey,
  });

  static const double _scale = 0.7;
  static const double _fontBoost = 1.3;

  static const Color _cardBlueFill = Color(0xFF1565C0);
  static const Color _cardBlueSubtitle = Color(0xFF90CAF9);

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final List<Widget> trailing;
  /// Destaque vermelho (ex.: falta séries/reps no grupo).
  final bool urgent;
  final String slidableDeleteLabel;
  final VoidCallback? onSlidableDelete;
  /// Identificador único para o [Slidable] (ex.: id do exercício).
  final String? slidableKey;

  @override
  Widget build(BuildContext context) {
    final padH = 12 * _scale;
    final padV = 12 * _scale;
    final radius = 14 * _scale;
    final titleSize = 15 * _scale * _fontBoost;
    final subSize = 12 * _scale * _fontBoost;

    final fill = urgent
        ? AppColors.danger.withValues(alpha: 0.22)
        : _cardBlueFill.withValues(alpha: 0.28);
    final borderColor = urgent
        ? AppColors.danger.withValues(alpha: 0.55)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.55);
    final splash = urgent
        ? AppColors.danger.withValues(alpha: 0.18)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.22);
    final highlight = urgent
        ? AppColors.danger.withValues(alpha: 0.1)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.12);
    final subColor = urgent
        ? AppColors.textMuted
        : _cardBlueSubtitle.withValues(alpha: 0.95);

    final card = Material(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: splash,
        highlightColor: highlight,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
          ),
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
                    SizedBox(height: 4 * _scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subColor,
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
    );

    if (onSlidableDelete == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Slidable(
        key: ValueKey(slidableKey ?? title),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) => onSlidableDelete!(),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: slidableDeleteLabel,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(kRegistrySlidableActionRadius * _scale),
                bottomRight: Radius.circular(kRegistrySlidableActionRadius * _scale),
              ),
            ),
          ],
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
  });

  final MuscleGroupEntity group;
  final int exerciseCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
              key: ValueKey<String>('mg_section_${group.id}'),
              maintainState: true,
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Icon(
                Icons.fitness_center_rounded,
                color: AppColors.splashMint,
                size: 26,
              ),
              title: Text(
                group.name,
                style: const TextStyle(
                  color: AppColors.splashMint,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              subtitle: Text(
                '$exerciseCount exercício${exerciseCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: AppColors.splashMint.withValues(alpha: 0.78),
                  fontSize: 13,
                ),
              ),
              iconColor: AppColors.splashMint,
              collapsedIconColor: AppColors.splashMint,
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
