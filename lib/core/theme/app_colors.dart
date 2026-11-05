import 'package:flutter/material.dart';

/// Paleta funcional: superfícies neutras e cor de ação reservada a estados.
abstract final class AppColors {
  static const Color background = Color(0xFF0B0B0D);
  static const Color backgroundDeep = Color(0xFF151517);
  static const Color barBackground = Color(0xFF1C1C1E);
  static const Color accentGreen = Color(0xFF0A84FF);
  static const Color splashMint = Color(0xFF64D2FF);
  static const Color accentPink = Color(0xFFFF375F);
  static const Color headerGradientPink = Color(0xFF1C1C1E);
  static const Color headerGradientMint = Color(0xFF1C1C1E);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color danger = Color(0xFFE53935);
  static const Color calendarIncomplete = Color(0xFFE53935);

  /// Dias futuros com treino programado / em aberto no calendário.
  static const Color calendarFutureProgrammed = Color(0xFF42A5F5);

  /// Borda dos cards na tela Cadastro e listas de registro (subtelas).
  static const Color cadastroCardBorder = Color(0xFF636366);

  /// Azul claro (ciano) — cartão de **seção** (grupo muscular, bloco na semana de planejamento).
  static const Color registrySectionBlueLight = Color(0xFF81D4FA);

  /// Azul mais fechado — cartão de **linha** (exercício em lista, item agendado).
  static const Color registryRowBlueDeep = Color(0xFF1565C0);

  /// Preenchimento translúcido de dia com treino no calendário (e cards concluídos).
  static Color workoutDayFillTint(Color accent) =>
      accent.withValues(alpha: 0.24);

  /// Borda de dia com treino no calendário (e cards concluídos).
  static Color workoutDayBorderTint(Color accent) =>
      accent.withValues(alpha: 0.5);
}
