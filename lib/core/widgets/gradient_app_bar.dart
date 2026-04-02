import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

const BoxDecoration _kAppBarGradientDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.headerGradientPink,
      AppColors.headerGradientMint,
    ],
  ),
);

/// 15% abaixo de [kToolbarHeight] (56 → ~47,6).
double get kAppBarToolbarHeight => kToolbarHeight * 0.85;

/// Barra superior padrão do app: gradiente rosa → menta, texto e ícones brancos.
AppBar buildGradientAppBar({
  Key? key,
  Widget? title,
  Widget? leading,
  double? leadingWidth,
  bool automaticallyImplyLeading = true,
  List<Widget>? actions,
  bool? centerTitle,
}) {
  return AppBar(
    key: key,
    toolbarHeight: kAppBarToolbarHeight,
    title: title,
    leading: leading,
    leadingWidth: leadingWidth,
    automaticallyImplyLeading: automaticallyImplyLeading,
    actions: actions,
    centerTitle: centerTitle,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
    flexibleSpace: const DecoratedBox(
      decoration: _kAppBarGradientDecoration,
      child: SizedBox.expand(),
    ),
  );
}
