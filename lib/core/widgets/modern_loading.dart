import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador orbital neon (anéis + partículas) — uso em splash, tabs, listas e diálogos.
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
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _FuturisticOrbitalPainter(phase: t),
          );
        },
      ),
    );
  }
}

class _FuturisticOrbitalPainter extends CustomPainter {
  _FuturisticOrbitalPainter({required this.phase});

  final double phase;

  static const _pink = AppColors.accentPink;
  static const _mint = AppColors.splashMint;
  static const _cyan = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    // Halo suave
    final halo = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 1.05,
        [
          _mint.withValues(alpha: 0.22),
          _pink.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(c, r * 0.92, halo);

    // Orbita trace (muito subtil)
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(c, r * 0.78, track);

    // Arco principal — sentido horário
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final sweep1 = math.pi * 0.62;
    arcPaint.shader = SweepGradient(
      colors: [
        _pink.withValues(alpha: 0.15),
        _mint,
        _cyan.withValues(alpha: 0.85),
        _pink.withValues(alpha: 0.15),
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
      startAngle: phase * 1.15,
      endAngle: phase * 1.15 + sweep1 * 2,
    ).createShader(Rect.fromCircle(center: c, radius: r * 0.78));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      phase * 1.15,
      sweep1,
      false,
      arcPaint,
    );

    // Arco secundário — sentido contrário, mais fino
    final arc2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final sweep2 = math.pi * 0.45;
    arc2.shader = SweepGradient(
      colors: [
        _cyan.withValues(alpha: 0.2),
        _pink.withValues(alpha: 0.95),
        _mint.withValues(alpha: 0.75),
        _cyan.withValues(alpha: 0.2),
      ],
      startAngle: -phase * 0.95 + math.pi * 0.4,
      endAngle: -phase * 0.95 + math.pi * 0.4 + sweep2 * 2.2,
    ).createShader(Rect.fromCircle(center: c, radius: r * 0.52));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.52),
      -phase * 0.95 + math.pi * 0.4,
      sweep2,
      false,
      arc2,
    );

    // Partículas em órbita
    final orbitR = r * 0.88;
    for (var k = 0; k < 3; k++) {
      final a = phase + (k * 2 * math.pi / 3);
      final p = Offset(
        c.dx + orbitR * math.cos(a),
        c.dy + orbitR * math.sin(a),
      );
      final node = Paint()
        ..shader = ui.Gradient.radial(
          p,
          r * 0.12,
          [
            Colors.white.withValues(alpha: 0.95),
            (k == 0
                    ? _mint
                    : k == 1
                    ? _cyan
                    : _pink)
                .withValues(alpha: 0.35),
            Colors.transparent,
          ],
          [0.0, 0.55, 1.0],
        );
      canvas.drawCircle(p, r * 0.09, node);
    }

    // Núcleo central pulsante (via fase)
    final pulse = 0.55 + 0.12 * math.sin(phase * 1.8);
    final core = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 0.22,
        [
          Colors.white.withValues(alpha: 0.35 * pulse),
          _mint.withValues(alpha: 0.25 * pulse),
          Colors.transparent,
        ],
        [0.0, 0.65, 1.0],
      );
    canvas.drawCircle(c, r * 0.2, core);
  }

  @override
  bool shouldRepaint(covariant _FuturisticOrbitalPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// Indicador de carregamento (sem texto) — calendário, modais e sync.
class FuturisticLoadingView extends StatelessWidget {
  const FuturisticLoadingView({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ModernLoadingIndicator(size: size);
  }
}

/// Overlay escuro com blur leve + [FuturisticLoadingView] — troca de abas, sync, etc.
class FuturisticLoadingOverlay extends StatelessWidget {
  const FuturisticLoadingOverlay({super.key, this.indicatorSize = 72});

  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.52),
                  AppColors.backgroundDeep.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.58),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FuturisticLoadingView(size: indicatorSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
