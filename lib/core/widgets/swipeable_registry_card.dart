import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_colors.dart';

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
  });

  final String title;
  final String? subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? trailing;
  final Object? slidableKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(slidableKey ?? title),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.42,
          children: [
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
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.accentPink.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.15),
                ],
              ),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
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
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> confirmDeleteDialog(BuildContext context, {String? itemName}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.barBackground,
      title: const Text('Excluir registro?', style: TextStyle(color: AppColors.textPrimary)),
      content: Text(
        itemName != null
            ? 'Deseja excluir "$itemName"? Esta ação não pode ser desfeita.'
            : 'Deseja excluir este registro? Esta ação não pode ser desfeita.',
        style: const TextStyle(color: AppColors.textMuted),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
}
