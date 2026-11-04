import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogos futuristas reutilizáveis (confirmação de duas ações + informativo).

Future<bool?> showFuturisticConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String subtitle,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  IconData headerIcon = Icons.save_rounded,
  FuturisticDialogAccent accent = FuturisticDialogAccent.mint,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    useRootNavigator: true,
    builder: (ctx) => FuturisticConfirmDialog(
      title: title,
      message: message,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      headerIcon: headerIcon,
      accent: accent,
    ),
  );
}

Future<void> showFuturisticInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? footnote,
  required String buttonLabel,
  IconData headerIcon = Icons.verified_rounded,
  FuturisticDialogAccent accent = FuturisticDialogAccent.pink,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    useRootNavigator: true,
    builder: (ctx) => FuturisticInfoDialog(
      title: title,
      message: message,
      footnote: footnote,
      buttonLabel: buttonLabel,
      headerIcon: headerIcon,
      accent: accent,
    ),
  );
}

enum FuturisticDialogAccent { mint, pink }

class FuturisticConfirmDialog extends StatelessWidget {
  const FuturisticConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.subtitle,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.headerIcon,
    required this.accent,
  });

  final String title;
  final String message;
  final String subtitle;
  final String confirmLabel;
  final String cancelLabel;
  final IconData headerIcon;
  final FuturisticDialogAccent accent;

  @override
  Widget build(BuildContext context) {
    final isMint = accent == FuturisticDialogAccent.mint;
    final ring = isMint ? AppColors.accentGreen : AppColors.accentPink;
    final glow = isMint ? AppColors.accentGreen : AppColors.accentPink;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isMint
                    ? const [
                        Color(0xFF0E0E18),
                        Color(0xFF0A1220),
                        Color(0xFF050508),
                      ]
                    : const [
                        Color(0xFF0E0E18),
                        Color(0xFF1A1018),
                        Color(0xFF050508),
                      ],
              ),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ring.withValues(alpha: 0.55),
                          ),
                          gradient: RadialGradient(
                            colors: [
                              ring.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(headerIcon, color: ring, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FuturisticGhostDialogButton(
                          label: cancelLabel,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FuturisticPrimaryDialogButton(
                          label: confirmLabel,
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FuturisticInfoDialog extends StatelessWidget {
  const FuturisticInfoDialog({
    super.key,
    required this.title,
    required this.message,
    this.footnote,
    required this.buttonLabel,
    required this.headerIcon,
    required this.accent,
  });

  final String title;
  final String message;
  final String? footnote;
  final String buttonLabel;
  final IconData headerIcon;
  final FuturisticDialogAccent accent;

  @override
  Widget build(BuildContext context) {
    final isMint = accent == FuturisticDialogAccent.mint;
    final ring = isMint ? AppColors.accentGreen : AppColors.accentPink;
    final glow = isMint ? AppColors.accentGreen : AppColors.accentPink;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isMint
                    ? const [
                        Color(0xFF0E0E18),
                        Color(0xFF0A1220),
                        Color(0xFF050508),
                      ]
                    : const [
                        Color(0xFF0E0E18),
                        Color(0xFF1A1018),
                        Color(0xFF050508),
                      ],
              ),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ring.withValues(alpha: 0.55),
                          ),
                          gradient: RadialGradient(
                            colors: [
                              ring.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(headerIcon, color: ring, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (footnote != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      footnote!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FuturisticPrimaryDialogButton(
                    label: buttonLabel,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FuturisticPrimaryDialogButton extends StatelessWidget {
  const FuturisticPrimaryDialogButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.headerGradientMint,
                AppColors.accentGreen.withValues(alpha: 0.9),
                AppColors.headerGradientPink.withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0A0A12),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FuturisticGhostDialogButton extends StatelessWidget {
  const FuturisticGhostDialogButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF141424).withValues(alpha: 0.9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
