import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../supabase/supabase_sync_controller.dart';
import '../theme/app_colors.dart';

/// Indicador na AppBar: cápsula futurista — verde online / vermelho offline;
/// com animação de “fluxo de dados” (partículas + varredura) durante upload/download.
class SupabaseTrafficIndicator extends StatelessWidget {
  const SupabaseTrafficIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseSyncController>(
      builder: (context, sync, _) {
        final base = sync.supabaseConfigured
            ? 'Supabase'
            : 'Supabase não configurado (use --dart-define=SUPABASE_PUBLISHABLE_KEY=… ou SUPABASE_ANON_KEY=…)';
        final fid = sync.fidelitySummaryForTooltip;
        final trafficHint = sync.isTrafficActive && sync.supabaseConfigured
            ? (sync.trafficKind == SupabaseTrafficKind.uploading
                ? '\nTráfego: enviando'
                : '\nTráfego: recebendo')
            : '';
        return Tooltip(
          message: fid == null ? '$base$trafficHint' : '$base$trafficHint\n$fid',
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _SupabaseLinkBadge(sync: sync),
          ),
        );
      },
    );
  }
}

class _SupabaseLinkBadge extends StatelessWidget {
  const _SupabaseLinkBadge({required this.sync});

  final SupabaseSyncController sync;

  @override
  Widget build(BuildContext context) {
    if (!sync.supabaseConfigured) {
      return const _UnconfiguredChip();
    }
    final online = sync.cloudStatus == SupabaseCloudStatus.online;
    final traffic = sync.isTrafficActive && online;
    final upload = sync.trafficKind == SupabaseTrafficKind.uploading;

    if (traffic) {
      return _HypertrafficLinkCapsule(
        isUpload: upload,
        coreColor: AppColors.accentGreen,
      );
    }
    return _IdleLinkCapsule(online: online);
  }
}

/// Chip mínimo quando Supabase não está configurado.
class _UnconfiguredChip extends StatelessWidget {
  const _UnconfiguredChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        color: Colors.black.withValues(alpha: 0.35),
      ),
      child: Icon(
        Icons.cloud_off_rounded,
        size: 14,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

const Color _kDisconnectedRed = Color(0xFFE53935);

class _IdleLinkCapsule extends StatelessWidget {
  const _IdleLinkCapsule({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = online ? AppColors.accentGreen : _kDisconnectedRed;
    return CustomPaint(
      painter: _CapsuleChromePainter(
        phase: 0,
        animateChrome: false,
        accent: c,
        dim: !online,
      ),
      child: SizedBox(
        width: _kCapsuleW,
        height: _kCapsuleH,
        child: Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CoreOrb(color: c, pulse: false),
          ),
        ),
      ),
    );
  }
}

const double _kCapsuleW = 58;
const double _kCapsuleH = 24;

class _HypertrafficLinkCapsule extends StatefulWidget {
  const _HypertrafficLinkCapsule({
    required this.isUpload,
    required this.coreColor,
  });

  final bool isUpload;
  final Color coreColor;

  @override
  State<_HypertrafficLinkCapsule> createState() =>
      _HypertrafficLinkCapsuleState();
}

class _HypertrafficLinkCapsuleState extends State<_HypertrafficLinkCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streamTint = widget.isUpload
        ? const Color(0xFF7CFFB2)
        : const Color(0xFF5CE1FF);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _CapsuleChromePainter(
            phase: _c.value,
            animateChrome: true,
            accent: streamTint,
            dim: false,
          ),
          child: SizedBox(
            width: _kCapsuleW,
            height: _kCapsuleH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _DataStreamPainter(
                        t: _c.value,
                        isUpload: widget.isUpload,
                        tint: streamTint,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CoreOrb(
                      color: widget.coreColor,
                      pulse: true,
                      pulsePhase: _c.value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoreOrb extends StatelessWidget {
  const _CoreOrb({
    required this.color,
    required this.pulse,
    this.pulsePhase = 0,
  });

  final Color color;
  final bool pulse;
  final double pulsePhase;

  @override
  Widget build(BuildContext context) {
    final s = pulse ? 1.0 + 0.14 * math.sin(pulsePhase * 2 * math.pi) : 1.0;
    return Transform.scale(
      scale: s,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.65),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: pulse ? 0.85 : 0.55),
              blurRadius: pulse ? 10 : 6,
              spreadRadius: pulse ? 0.5 : 0,
            ),
          ],
        ),
      ),
    );
  }
}

/// Borda da cápsula + varredura holográfica quando [animateChrome].
class _CapsuleChromePainter extends CustomPainter {
  _CapsuleChromePainter({
    required this.phase,
    required this.animateChrome,
    required this.accent,
    required this.dim,
  });

  final double phase;
  final bool animateChrome;
  final Color accent;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    final baseBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = dim
          ? _kDisconnectedRed.withValues(alpha: 0.35)
          : accent.withValues(alpha: animateChrome ? 0.45 : 0.28);

    canvas.drawRRect(r.deflate(0.6), baseBorder);

    if (animateChrome) {
      final sweep = phase * 2 * math.pi;
      final cx = size.width / 2;
      final cy = size.height / 2;
      final shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.95),
          AppColors.headerGradientPink.withValues(alpha: 0.75),
          accent.withValues(alpha: 0),
        ],
        [0, 0.35, 0.55, 1],
        TileMode.clamp,
        sweep,
      );
      final glow = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRRect(r.deflate(0.5), glow);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CapsuleChromePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.animateChrome != animateChrome ||
        oldDelegate.accent != accent ||
        oldDelegate.dim != dim;
  }
}

/// Partículas / cometas deslizando no trilho (upload → direita, download ←).
class _DataStreamPainter extends CustomPainter {
  _DataStreamPainter({
    required this.t,
    required this.isUpload,
    required this.tint,
  });

  final double t;
  final bool isUpload;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;
    final trackLeft = 20.0;
    final trackRight = w - 4;
    final trackW = trackRight - trackLeft;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = tint.withValues(alpha: 0.08);
    for (var gx = trackLeft; gx < trackRight; gx += 5) {
      canvas.drawLine(Offset(gx, 4), Offset(gx, h - 4), grid);
    }

    const n = 4;
    for (var i = 0; i < n; i++) {
      final stagger = i / n;
      var u = (t + stagger) % 1.0;
      if (!isUpload) u = 1.0 - u;
      final x = trackLeft + u * trackW;
      final wave = math.sin((u + i * 0.17) * math.pi * 2) * 1.8;
      final y = midY + wave;

      final headAlpha = 0.15 + 0.55 * math.sin(u * math.pi);
      final tailLen = 14.0 + 6 * math.sin((t * 2 * math.pi) + i);
      final dir = isUpload ? -1.0 : 1.0;

      final tailPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x + dir * tailLen, y),
          Offset(x, y),
          [
            tint.withValues(alpha: 0),
            tint.withValues(alpha: headAlpha * 0.85),
          ],
        )
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, y), Offset(x + dir * tailLen, y), tailPaint);

      final head = Paint()
        ..color = tint.withValues(alpha: headAlpha.clamp(0.2, 0.95))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), 2.1, head);

      final crisp = Paint()..color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(Offset(x, y), 0.9, crisp);
    }

    final scanX = trackLeft + (t % 1.0) * trackW;
    final bandTop = 2.0;
    final bandH = h - 4.0;
    final scanCy = bandTop + bandH / 2;
    // Dois tons apenas: `dart:ui` exige length 2 se `colorStops` for omitido.
    // Radial centrado em scanX dá o mesmo “reflexo” sem linear de 3 cores.
    final scan = Paint()
      ..shader = ui.Gradient.radial(
        Offset(scanX, scanCy),
        10,
        [
          tint.withValues(alpha: 0.26),
          Colors.transparent,
        ],
      );
    canvas.drawRect(Rect.fromLTWH(trackLeft, bandTop, trackW, bandH), scan);
  }

  @override
  bool shouldRepaint(covariant _DataStreamPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.isUpload != isUpload ||
        oldDelegate.tint != tint;
  }
}
