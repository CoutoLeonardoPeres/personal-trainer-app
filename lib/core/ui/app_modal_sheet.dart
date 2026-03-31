import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Conteúdo do modal; use [scrollController] no [ListView] principal para
/// combinar com o arraste do sheet e evitar overflow em telas pequenas.
typedef AppModalContentBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

/// Modal ~93% da altura, arraste vertical, fundo escuro — padrão dos cadastros.
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required AppModalContentBuilder builder,
  String? title,
  List<Widget>? actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.93,
        minChildSize: 0.35,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B14).withValues(alpha: 0.99),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
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
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (actions != null) ...actions,
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: builder(context, scrollController),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
