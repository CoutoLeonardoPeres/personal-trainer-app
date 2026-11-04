import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Confirmação de exclusão no estilo futurista do app (gradiente, faixa, CTAs).
Future<bool?> showFuturisticConfirmDeleteDialog(
  BuildContext context, {
  String? itemName,
  String title = 'Excluir registro?',
  String? entityTag,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _FuturisticConfirmDeletePanel(
      itemName: itemName,
      title: title,
      entityTag: entityTag,
    ),
  );
}

class _FuturisticConfirmDeletePanel extends StatelessWidget {
  const _FuturisticConfirmDeletePanel({
    required this.itemName,
    required this.title,
    this.entityTag,
  });

  final String? itemName;
  final String title;
  final String? entityTag;

  @override
  Widget build(BuildContext context) {
    final tagLine = entityTag?.trim();
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E18),
                  Color(0xFF1A1018),
                  Color(0xFF0A1220),
                ],
              ),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.38),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.16),
                  blurRadius: 28,
                  spreadRadius: -4,
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
                        AppColors.cadastroCardBorder.withValues(alpha: 0.88),
                        AppColors.headerGradientMint.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.danger.withValues(alpha: 0.28),
                                  AppColors.accentPink.withValues(alpha: 0.14),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.delete_forever_rounded,
                                color: AppColors.danger,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tagLine != null && tagLine.isNotEmpty) ...[
                                  Text(
                                    tagLine.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.35,
                                      color: AppColors.accentGreen.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.35,
                                    height: 1.12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (itemName != null && itemName!.isNotEmpty)
                        Text(
                          '"${itemName!}"',
                          style: TextStyle(
                            color: AppColors.registrySectionBlueLight
                                .withValues(alpha: 0.92),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        )
                      else
                        Text(
                          'Este registro será removido permanentemente.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Esta ação não pode ser desfeita.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _FuturisticDeleteDialogCancelCta(
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(height: 12),
                      _FuturisticDeleteDialogConfirmCta(
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

class _FuturisticDeleteDialogCancelCta extends StatelessWidget {
  const _FuturisticDeleteDialogCancelCta({required this.onPressed});

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
            color: const Color(0xFF1A1424).withValues(alpha: 0.95),
            border: Border.all(
              color: AppColors.splashMint.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.splashMint.withValues(alpha: 0.08),
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
                color: AppColors.splashMint.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Cancelar',
                style: TextStyle(
                  color: AppColors.splashMint.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuturisticDeleteDialogConfirmCta extends StatelessWidget {
  const _FuturisticDeleteDialogConfirmCta({required this.onPressed});

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
              colors: [
                AppColors.danger,
                AppColors.danger.withValues(alpha: 0.78),
                AppColors.accentPink.withValues(alpha: 0.88),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Excluir',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.98),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
