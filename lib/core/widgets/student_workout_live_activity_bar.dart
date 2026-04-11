import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_session.dart';
import '../theme/app_colors.dart';
import '../workout/rest_live_activity_controller.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';

/// Faixa flutuante “ao vivo” para o aluno durante treino iniciado: cronômetro do treino + intervalo entre séries.
class StudentWorkoutLiveActivityLayer extends StatefulWidget {
  const StudentWorkoutLiveActivityLayer({super.key, required this.child});

  final Widget? child;

  @override
  State<StudentWorkoutLiveActivityLayer> createState() =>
      _StudentWorkoutLiveActivityLayerState();
}

class _StudentWorkoutLiveActivityLayerState
    extends State<StudentWorkoutLiveActivityLayer> {
  Timer? _workoutTick;

  @override
  void dispose() {
    _workoutTick?.cancel();
    super.dispose();
  }

  void _ensureWorkoutTick(bool need) {
    if (need) {
      _workoutTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _workoutTick?.cancel();
      _workoutTick = null;
    }
  }

  static String _fmtDuration(int sec) {
    final s = sec.clamp(0, 24 * 3600);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final r = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${r.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final repo = context.watch<AppDataRepository>();
    final restCtrl = context.watch<RestLiveActivityController>();

    if (!session.isStudent || session.studentId == null) {
      return widget.child ?? const SizedBox.shrink();
    }

    final sid = session.studentId!;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: widget.child ?? const SizedBox.shrink(),
        ),
        StreamBuilder<List<DayWorkoutEntity>>(
          stream: repo.watchStudentStartedDayWorkouts(sid),
          builder: (context, snap) {
            final list = snap.data ?? [];
            final w = list.isEmpty ? null : list.first;
            if (w == null && restCtrl.hasRestSession) {
              Future.microtask(() {
                if (!context.mounted) return;
                context.read<RestLiveActivityController>().clear();
              });
            }
            final show = w != null;
            _ensureWorkoutTick(show || restCtrl.hasRestSession);

            if (!show && !restCtrl.hasRestSession) {
              return const SizedBox.shrink();
            }

            final now = DateTime.now();
            final activeSec = w != null ? repo.effectiveActiveSeconds(w, now) : 0;
            final paused = w != null &&
                w.status == 'started' &&
                w.timerResumeAt == null;

            return Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: ListenableBuilder(
                    listenable: restCtrl,
                    builder: (context, _) {
                      return _LiveActivityCard(
                        workoutLabel: w != null
                            ? _fmtDuration(activeSec)
                            : '—',
                        workoutPaused: paused,
                        prescribedRestSec: restCtrl.prescribedSec,
                        restRemainingSec: restCtrl.remainingCountdownSec,
                        restPostPhase: restCtrl.inPostPhase,
                        restPostElapsedSec: restCtrl.postPhaseElapsedSec,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LiveActivityCard extends StatefulWidget {
  const _LiveActivityCard({
    required this.workoutLabel,
    required this.workoutPaused,
    required this.prescribedRestSec,
    required this.restRemainingSec,
    required this.restPostPhase,
    required this.restPostElapsedSec,
  });

  final String workoutLabel;
  final bool workoutPaused;
  final int prescribedRestSec;
  final int restRemainingSec;
  final bool restPostPhase;
  final int restPostElapsedSec;

  @override
  State<_LiveActivityCard> createState() => _LiveActivityCardState();
}

class _LiveActivityCardState extends State<_LiveActivityCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasRest = widget.prescribedRestSec > 0;
    final showRestRow = hasRest &&
        (widget.restRemainingSec > 0 ||
            widget.restPostPhase ||
            widget.restPostElapsedSec > 0);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14, 10, 14, _expanded ? 12 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.splashMint.withValues(alpha: 0.22),
              AppColors.barBackground.withValues(alpha: 0.92),
              Colors.black.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: AppColors.accentGreen.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.splashMint.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_filled_rounded,
                  color: AppColors.accentGreen.withValues(alpha: 0.95),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Treino ao vivo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Icon(
                  widget.workoutPaused ? Icons.pause_circle_filled : Icons.timer_rounded,
                  size: 20,
                  color: widget.workoutPaused
                      ? Colors.amberAccent.shade200
                      : AppColors.splashMint.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.workoutLabel,
                  style: TextStyle(
                    color: AppColors.splashMint.withValues(alpha: 0.98),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (showRestRow) ...[
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 20,
                    color: const Color(0xFF26C6DA).withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restPostPhase
                              ? 'Intervalo — pronto para próxima série'
                              : 'Intervalo entre séries',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!widget.restPostPhase)
                          Text(
                            _fmtMmSs(widget.restRemainingSec),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )
                        else
                          Text(
                            '+${_fmtMmSs(widget.restPostElapsedSec)}',
                            style: TextStyle(
                              color: AppColors.accentPink.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                hasRest
                    ? 'Tempo de intervalo prescrito: ${widget.prescribedRestSec}s. '
                        'Toque de novo para recolher.'
                    : 'Quando registrar uma série, o intervalo aparece aqui durante o descanso. '
                        'Toque de novo para recolher.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ] else if (hasRest || showRestRow)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Toque para detalhes do intervalo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmtMmSs(int totalSeconds) {
    final s = totalSeconds.clamp(0, 24 * 3600);
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}
