import 'package:flutter/material.dart';

/// Desloca o conteúdo para cima quando o teclado abre (bottom sheets, colunas com CTA fixo).
///
/// Use na **raiz** do `builder` de [showModalBottomSheet] / [DraggableScrollableSheet].
class KeyboardBottomInsetPadding extends StatelessWidget {
  const KeyboardBottomInsetPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}

/// Evita que [Dialog] / [AlertDialog] fiquem atrás do teclado.
///
/// Envolve o widget retornado no `builder` de [showDialog].
class KeyboardAvoidingDialog extends StatelessWidget {
  const KeyboardAvoidingDialog({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: b),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
