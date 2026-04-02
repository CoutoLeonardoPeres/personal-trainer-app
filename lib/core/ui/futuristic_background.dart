import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gradiente + imagem em [BoxFit.cover] + overlay (origem: pasta Personal / personal_trainer_app).
class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key, required this.child});

  final Widget child;

  static const String _assetPath = 'assets/images/fitness_background.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.backgroundDeep,
            AppColors.background,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              _assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                    'FuturisticBackground: falha ao carregar $_assetPath — $error',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class FuturisticCard extends StatelessWidget {
  const FuturisticCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  /// Se nulo, mantém a borda rosa (ex.: calendário).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.accentPink.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                AppColors.accentPink.withValues(alpha: 0.07),
                Colors.black.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}
