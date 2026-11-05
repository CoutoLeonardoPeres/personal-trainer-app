import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador de progresso leve, sem animação customizada contínua.
class ModernLoadingIndicator extends StatelessWidget {
  const ModernLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: size >= 64 ? 3 : 2.5,
        color: AppColors.accentGreen,
      ),
    );
  }
}

/// Indicador de carregamento (sem texto) — calendário, modais e sync.
class FuturisticLoadingView extends StatelessWidget {
  const FuturisticLoadingView({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ModernLoadingIndicator(size: size);
  }
}

/// Overlay discreto para operações curtas de troca de aba e sincronização.
class FuturisticLoadingOverlay extends StatelessWidget {
  const FuturisticLoadingOverlay({super.key, this.indicatorSize = 72});

  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FuturisticLoadingView(size: indicatorSize),
          ),
        ),
      ),
    );
  }
}
