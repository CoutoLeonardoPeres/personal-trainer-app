import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../preferences/rest_timer_prefs.dart';
import '../theme/app_colors.dart';
import '../ui/keyboard_bottom_inset.dart';
import '../workout/rest_live_activity_controller.dart';

/// Métricas gravadas na última série após o descanso entre séries.
class InterSetRestMetrics {
  const InterSetRestMetrics({
    required this.prescribedSec,
    required this.countdownElapsedMs,
    required this.postPhaseMs,
  });

  final int prescribedSec;
  final int countdownElapsedMs;
  final int postPhaseMs;
}

/// Após registrar uma série: timer regressivo (descanso) + fase pós-bipe com cronômetro progressivo.
Future<InterSetRestMetrics?> showInterSetRestModal({
  required BuildContext context,
  required int prescribedSec,
}) async {
  if (prescribedSec <= 0) return null;
  return showDialog<InterSetRestMetrics>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (ctx) => _InterSetRestDialog(prescribedSec: prescribedSec),
  );
}

class _InterSetRestDialog extends StatefulWidget {
  const _InterSetRestDialog({required this.prescribedSec});

  final int prescribedSec;

  @override
  State<_InterSetRestDialog> createState() => _InterSetRestDialogState();
}

class _InterSetRestDialogState extends State<_InterSetRestDialog>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late DateTime _countdownStart;
  DateTime? _postPhaseStart;
  var _phaseCountdown = true;
  var _transitionedToPost = false;
  var _playedEndSound = false;
  RestLiveActivityController? _restLive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restLive ??= context.read<RestLiveActivityController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownStart = DateTime.now();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_syncPhaseWithWallClock()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restLive?.beginCountdown(prescribedSec: widget.prescribedSec);
      final end = _restLive?.countdownEndsAt;
      if (end != null) {
        setState(() {
          _countdownStart =
              end.subtract(Duration(seconds: widget.prescribedSec));
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPhaseWithWallClock());
    }
  }

  /// Alinha fase com o relógio real (timers pausam com app em background / ecrã bloqueado).
  Future<void> _syncPhaseWithWallClock() async {
    _restLive?.syncWithWallClock();
    if (_transitionedToPost) {
      if (mounted) setState(() {});
      return;
    }
    final ctrl = _restLive;
    if (ctrl == null || !ctrl.inPostPhase) {
      if (mounted) setState(() {});
      return;
    }
    _transitionedToPost = true;
    _phaseCountdown = false;
    _postPhaseStart = ctrl.postPhaseStartedAt ??
        _countdownStart.add(Duration(seconds: widget.prescribedSec));
    if (!_playedEndSound) {
      _playedEndSound = true;
      final on = await RestTimerPrefs.isSoundEnabled();
      if (on && mounted) {
        await SystemSound.play(SystemSoundType.alert);
      }
    }
    if (mounted) setState(() {});
  }

  int get _remainingCountdownSec {
    final elapsed = DateTime.now().difference(_countdownStart).inSeconds;
    final r = widget.prescribedSec - elapsed;
    return r < 0 ? 0 : r;
  }

  int get _postPhaseMs {
    final s = _postPhaseStart;
    if (s == null) return 0;
    return DateTime.now().difference(s).inMilliseconds.clamp(0, 1 << 30);
  }

  void _finish() {
    _ticker?.cancel();
    _restLive?.clear();
    final postStart = _postPhaseStart;
    final countMs = postStart == null
        ? DateTime.now().difference(_countdownStart).inMilliseconds
        : postStart.difference(_countdownStart).inMilliseconds;
    final postMs = postStart == null ? 0 : DateTime.now().difference(postStart).inMilliseconds;
    Navigator.of(context).pop(
      InterSetRestMetrics(
        prescribedSec: widget.prescribedSec,
        countdownElapsedMs: countMs.clamp(0, 1 << 30),
        postPhaseMs: postMs.clamp(0, 1 << 30),
      ),
    );
  }

  void _skipCountdown() {
    if (!_phaseCountdown) return;
    final now = DateTime.now();
    _playedEndSound = true;
    _restLive?.enterPostPhase(startedAt: now);
    setState(() {
      _transitionedToPost = true;
      _phaseCountdown = false;
      _postPhaseStart = now;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _restLive?.clear();
    super.dispose();
  }

  static String _formatMmSs(int totalSeconds) {
    final s = totalSeconds.clamp(0, 24 * 3600);
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  static String _formatElapsedFromMs(int ms) {
    final sec = (ms / 1000).floor().clamp(0, 24 * 3600);
    return _formatMmSs(sec);
  }

  @override
  Widget build(BuildContext context) {
    final countdownLabel = _formatMmSs(_remainingCountdownSec);
    final postLabel = _formatElapsedFromMs(_postPhaseMs);
    final postCentis = ((_postPhaseMs % 1000) ~/ 10).toString().padLeft(2, '0');

    return KeyboardAvoidingDialog(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.barBackground,
                    AppColors.backgroundDeep,
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(
                  color: AppColors.splashMint.withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _phaseCountdown ? 'Descanso entre séries' : 'Pronto para a próxima',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_phaseCountdown) ...[
                      _DigitalClockDisplay(
                        primary: countdownLabel,
                        caption: 'Tempo restante',
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _skipCountdown,
                        child: const Text('Pular descanso'),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 26,
                            color: AppColors.accentPink.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cronômetro',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DigitalClockDisplay(
                        primary: postLabel,
                        secondaryTicks: postCentis,
                        caption: 'Tempo até registrar a próxima série',
                        accentPink: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.splashMint,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _finish,
                        child: const Text(
                          'Registrar próxima série',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Display estilo relógio digital (LED): alto contraste, monoespaçado, brilho nas bordas.
class _DigitalClockDisplay extends StatelessWidget {
  const _DigitalClockDisplay({
    required this.primary,
    required this.caption,
    this.secondaryTicks,
    this.accentPink = false,
  });

  final String primary;
  final String caption;
  final String? secondaryTicks;
  final bool accentPink;

  @override
  Widget build(BuildContext context) {
    final glow = accentPink ? AppColors.accentPink : AppColors.splashMint;
    final digitColor = accentPink
        ? const Color(0xFFFFD4E0)
        : const Color(0xFFB8FFF5);

    final digitStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 58,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: 4,
      color: digitColor,
      shadows: [
        Shadow(
          color: glow.withValues(alpha: 0.95),
          blurRadius: 22,
        ),
        Shadow(
          color: glow.withValues(alpha: 0.55),
          blurRadius: 42,
        ),
        Shadow(
          color: Colors.white.withValues(alpha: 0.35),
          blurRadius: 2,
          offset: const Offset(0, -0.5),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1118),
            Colors.black.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: glow.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(primary, style: digitStyle),
              if (secondaryTicks != null) ...[
                Text(
                  '.',
                  style: digitStyle.copyWith(
                    fontSize: 44,
                    letterSpacing: 0,
                    color: digitColor.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  secondaryTicks!,
                  style: digitStyle.copyWith(
                    fontSize: 36,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
