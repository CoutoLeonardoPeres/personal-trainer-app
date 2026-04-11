import 'package:flutter/material.dart';

/// Paleta alinhada ao app de referência (preto, rosa e verde neon).
abstract final class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundDeep = Color(0xFF090014);
  static const Color barBackground = Color(0xFF0A0A12);
  static const Color accentGreen = Color(0xFF69F0AE); // greenAccent
  /// Título da splash (mint do layout de referência).
  static const Color splashMint = Color(0xFF82E0AA);
  static const Color accentPink = Color(0xFFFF4081); // pinkAccent
  /// Barra superior (AppBar): gradiente rosa → menta (layout de referência).
  static const Color headerGradientPink = Color(0xFFFF2D78);
  static const Color headerGradientMint = Color(0xFF70FFAF);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color danger = Color(0xFFE53935);
  static const Color calendarIncomplete = Color(0xFFE53935);
  /// Dias futuros com treino programado / em aberto no calendário.
  static const Color calendarFutureProgrammed = Color(0xFF42A5F5);
  /// Borda dos cards na tela Cadastro e listas de registro (subtelas).
  static const Color cadastroCardBorder = Color(0xFF42A5F5);
  /// Azul claro (ciano) — cartão de **seção** (grupo muscular, bloco na semana de planejamento).
  static const Color registrySectionBlueLight = Color(0xFF81D4FA);
  /// Azul mais fechado — cartão de **linha** (exercício em lista, item agendado).
  static const Color registryRowBlueDeep = Color(0xFF1565C0);
}
