import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'keyboard_bottom_inset.dart';

/// Conteúdo do modal; use [scrollController] no [ListView] principal para
/// combinar com o arraste do sheet e evitar overflow em telas pequenas.
typedef AppModalContentBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Modal em fração da altura da tela (padrão ~93%), arraste vertical, fundo escuro.
///
/// [futuristicChrome] aplica a moldura reforçada usada em calendário e ajustes.
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
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
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
                                          color: AppColors.textMuted,
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

          return Container(
            decoration: BoxDecoration(
              color: AppColors.barBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border.all(color: const Color(0xFF38383A)),
            ),
            child: sheetPadded,
          );
        },
      );
    },
  );
}
