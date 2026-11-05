import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Superfície neutra compartilhada pelas telas principais.
class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(color: AppColors.background, child: child);
  }
}

class FuturisticCard extends StatelessWidget {
  const FuturisticCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.backgroundGradient,
    this.borderWidth = 1,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Se nulo, mantém a borda rosa (cadastro / padrão).
  final Color? borderColor;

  /// Se nulo, gradiente rosa suave + escuro (padrão).
  final List<Color>? backgroundGradient;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.cadastroCardBorder;
    final color = backgroundGradient?.first ?? AppColors.barBackground;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color,
            border: Border.all(color: border, width: borderWidth),
          ),
          child: child,
        ),
      ),
    );
  }
}
