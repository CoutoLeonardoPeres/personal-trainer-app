import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_colors.dart';
import '../ui/futuristic_confirm_delete_dialog.dart';

/// Raio dos botões revelados pelo Slidable (encaixa com o card ~16).
const double kRegistrySlidableActionRadius = 14;

/// Card de lista com ações de editar / excluir ao arrastar para a esquerda.
class SwipeableRegistryCard extends StatelessWidget {
  const SwipeableRegistryCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.trailing,

    /// Chave estável para o [Slidable] (ex.: id do registro). Evita colisão quando [title] se repete.
    this.slidableKey,

    /// Fundo azul translúcido + borda azul (itens dentro do bloco na tela de planejamento).
    this.translucentBlueExerciseStyle = false,

    /// Toque no card (ex.: tela de personais: abre edição).
    this.onCardTap,

    /// Se false, o arraste revela só [onDelete] (ex.: personais).
    this.showEditOnSwipe = true,
    this.onSlidableCombine,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? trailing;
  final Object? slidableKey;
  final bool translucentBlueExerciseStyle;
  final VoidCallback? onCardTap;
  final bool showEditOnSwipe;
  final VoidCallback? onSlidableCombine;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: translucentBlueExerciseStyle
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.registryRowBlueDeep.withValues(alpha: 0.28),
                AppColors.cadastroCardBorder.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.3),
              ],
            )
          : LinearGradient(
              colors: [
                AppColors.accentPink.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.15),
              ],
            ),
      border: Border.all(
        color: translucentBlueExerciseStyle
            ? AppColors.cadastroCardBorder.withValues(alpha: 0.82)
            : AppColors.cadastroCardBorder.withValues(alpha: 0.55),
        width: translucentBlueExerciseStyle ? 1.05 : 1,
      ),
    );

    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );

    final cardBody = onCardTap != null
        ? InkWell(
            onTap: onCardTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: decoration,
              child: Padding(padding: pad, child: row),
            ),
          )
        : Container(padding: pad, decoration: decoration, child: row);

    final actions = <Widget>[
      if (showEditOnSwipe)
        SlidableAction(
          onPressed: (_) => onEdit(),
          backgroundColor: AppColors.accentGreen.withValues(alpha: 0.35),
          foregroundColor: AppColors.textPrimary,
          icon: Icons.edit_rounded,
          label: 'Editar',
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRegistrySlidableActionRadius),
            bottomLeft: Radius.circular(kRegistrySlidableActionRadius),
          ),
        ),
      if (onSlidableCombine != null)
        SlidableAction(
          onPressed: (_) => onSlidableCombine!(),
          backgroundColor: const Color(0xFF7E57C2),
          foregroundColor: Colors.white,
          icon: Icons.merge_type_rounded,
          label: 'Combinar',
          borderRadius: showEditOnSwipe
              ? BorderRadius.zero
              : const BorderRadius.only(
                  topLeft: Radius.circular(kRegistrySlidableActionRadius),
                  bottomLeft: Radius.circular(kRegistrySlidableActionRadius),
                ),
        ),
      SlidableAction(
        onPressed: (_) => onDelete(),
        backgroundColor: AppColors.danger.withValues(alpha: 0.9),
        foregroundColor: Colors.white,
        icon: Icons.delete_outline_rounded,
        label: 'Excluir',
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(kRegistrySlidableActionRadius),
          bottomRight: Radius.circular(kRegistrySlidableActionRadius),
        ),
      ),
    ];
    final actionCount = actions.length;
    final extent = 0.22 * actionCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(slidableKey ?? title),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: extent.clamp(0.22, 0.66),
          children: actions,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: cardBody,
        ),
      ),
    );
  }
}

Future<bool?> confirmDeleteDialog(
  BuildContext context, {
  String? itemName,
  String? title,
  String? entityTag,
}) {
  return showFuturisticConfirmDeleteDialog(
    context,
    itemName: itemName,
    title: title ?? 'Excluir registro?',
    entityTag: entityTag,
  );
}
