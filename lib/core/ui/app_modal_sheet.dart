import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'keyboard_bottom_inset.dart';

/// Conteúdo do modal; use [scrollController] no [ListView] principal para
/// combinar com o arraste do sheet e evitar overflow em telas pequenas.
typedef AppModalContentBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Modal em fração da altura da tela (padrão ~93%), arraste vertical, fundo escuro.
///
/// [futuristicChrome] aplica gradiente, faixa superior e borda azul (calendário / ajustes).
///
/// [initialChildSize] / [maxChildSize] controlam quanto o sheet ocupa (ex.: 0.85 no calendário).
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required AppModalContentBuilder builder,
  String? title,
  String? subtitle,
  List<Widget>? actions,
  bool futuristicChrome = false,
  double initialChildSize = 0.93,
  double minChildSize = 0.35,
  double maxChildSize = 0.97,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: futuristicChrome
        ? Colors.black.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          final sheetBody = Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: futuristicChrome ? 0.28 : 0.2,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    if (futuristicChrome)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.headerGradientPink.withValues(
                                alpha: 0.95,
                              ),
                              AppColors.cadastroCardBorder.withValues(
                                alpha: 0.9,
                              ),
                              AppColors.headerGradientMint.withValues(
                                alpha: 0.85,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 4, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (futuristicChrome)
                                      Text(
                                        'CALENDÁRIO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.35,
                                          color: AppColors.accentGreen
                                              .withValues(alpha: 0.78),
                                        ),
                                      ),
                                    if (futuristicChrome)
                                      const SizedBox(height: 6),
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: futuristicChrome ? 19 : 18,
                                        fontWeight: futuristicChrome
                                            ? FontWeight.w800
                                            : FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (subtitle != null &&
                                        subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.48,
                                          ),
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (actions != null) ...actions,
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withValues(
                                alpha: futuristicChrome ? 0.7 : 1,
                              ),
                              size: 26,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: builder(context, scrollController)),
            ],
          );

          final sheetPadded = KeyboardBottomInsetPadding(child: sheetBody);

          if (!futuristicChrome) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B14).withValues(alpha: 0.99),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border.all(
                  color: AppColors.accentPink.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: sheetPadded,
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.barBackground,
                  AppColors.backgroundDeep,
                  Colors.black.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.52),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: sheetPadded,
          );
        },
      );
    },
  );
}
