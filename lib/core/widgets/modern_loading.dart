import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador de carregamento “gadget” para splash e troca de abas.
class ModernLoadingIndicator extends StatefulWidget {
  const ModernLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  State<ModernLoadingIndicator> createState() => _ModernLoadingIndicatorState();
}

class _ModernLoadingIndicatorState extends State<ModernLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RingPainter(phase: t),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const segments = 3;
    for (var i = 0; i < segments; i++) {
      final start = phase + (i * 2 * math.pi / segments);
      final sweep = math.pi * 0.55;
      paint.shader = SweepGradient(
        colors: [
          AppColors.accentPink.withValues(alpha: 0.2),
          AppColors.accentGreen,
          AppColors.accentPink.withValues(alpha: 0.2),
        ],
        startAngle: start,
        endAngle: start + sweep * 2,
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        paint..shader,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
