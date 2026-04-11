import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'supabase_traffic_indicator.dart';

/// Espaço à esquerda para a cápsula do indicador; à direita para um ícone de ação típico.
const double _kToolbarTrafficSlot = 72;
const double _kToolbarOneActionSlot = 56;

/// Título da AppBar com o indicador Supabase à esquerda (após o [leading]),
/// alinhado às telas de cadastro e configurações.
///
/// Com [centerTitleInToolbar], o texto do título fica centralizado na barra (ex.: abas principais).
Widget? _titleWithTrafficIndicator(
  Widget? title, {
  bool centerTitleInToolbar = false,
}) {
  if (title == null) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SupabaseTrafficIndicator(),
      ],
    );
  }
  if (centerTitleInToolbar) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _kToolbarTrafficSlot,
            0,
            _kToolbarOneActionSlot,
            0,
          ),
          child: Center(
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
              child: title,
            ),
          ),
        ),
        const Positioned(
          left: 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: SupabaseTrafficIndicator(),
          ),
        ),
      ],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SupabaseTrafficIndicator(),
      const SizedBox(width: 8),
      Expanded(
        child: DefaultTextStyle.merge(
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          child: title,
        ),
      ),
    ],
  );
}

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

/// Tamanho base do título na AppBar em gradiente; +20% em relação ao 17 anterior.
double get kGradientAppBarTitleFontSize => 17 * 1.2;

/// Barra superior padrão do app: gradiente rosa → menta, texto e ícones brancos.
AppBar buildGradientAppBar({
  Key? key,
  Widget? title,
  Widget? leading,
  double? leadingWidth,
  bool automaticallyImplyLeading = true,
  List<Widget>? actions,
  bool? centerTitle,
  bool showSupabaseTrafficIndicator = true,
  /// Título visualmente ao centro da barra (telas das abas inferiores), com indicador à esquerda.
  bool centerTitleInToolbar = false,
}) {
  final effectiveTitle = showSupabaseTrafficIndicator
      ? _titleWithTrafficIndicator(
          title,
          centerTitleInToolbar: centerTitleInToolbar,
        )
      : title;
  final effectiveCenterTitle = centerTitleInToolbar
      ? false
      : (showSupabaseTrafficIndicator ? (centerTitle ?? false) : centerTitle);

  return AppBar(
    key: key,
    toolbarHeight: kAppBarToolbarHeight,
    title: effectiveTitle,
    leading: leading,
    leadingWidth: leadingWidth,
    automaticallyImplyLeading: automaticallyImplyLeading,
    actions: actions,
    centerTitle: effectiveCenterTitle,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: kGradientAppBarTitleFontSize,
      fontWeight: FontWeight.w600,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
    flexibleSpace: const DecoratedBox(
      decoration: _kAppBarGradientDecoration,
      child: SizedBox.expand(),
    ),
  );
}
