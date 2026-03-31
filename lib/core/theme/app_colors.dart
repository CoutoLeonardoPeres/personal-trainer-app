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
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color danger = Color(0xFFE53935);
  static const Color calendarIncomplete = Color(0xFFE53935);
  /// Dias futuros com treino programado / em aberto no calendário.
  static const Color calendarFutureProgrammed = Color(0xFF42A5F5);
}
