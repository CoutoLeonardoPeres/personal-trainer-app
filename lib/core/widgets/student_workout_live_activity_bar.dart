import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_session.dart';
import '../workout/ios_lock_screen_live_activity.dart';
import '../workout/rest_live_activity_controller.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';

/// Sincroniza a Live Activity no iOS durante treino `started` / intervalo, sem overlay na app.
class StudentWorkoutLiveActivityLayer extends StatefulWidget {
  const StudentWorkoutLiveActivityLayer({super.key, required this.child});

  final Widget? child;

  @override
  State<StudentWorkoutLiveActivityLayer> createState() =>
      _StudentWorkoutLiveActivityLayerState();
}

class _StudentWorkoutLiveActivityLayerState
    extends State<StudentWorkoutLiveActivityLayer> with WidgetsBindingObserver {
  Timer? _workoutTick;
  var _iosLiveActivityFrameScheduled = false;
  var _iosLaSyncInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workoutTick?.cancel();
    IosLockScreenLiveActivity.endIfAny();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<RestLiveActivityController>().syncWithWallClock();
      setState(() {});
    }
    if (mounted &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      final rest = context.read<RestLiveActivityController>();
      if (rest.hasRestSession && !rest.inPostPhase) {
        unawaited(rest.armEndNotificationForBackground());
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        _flushIosLiveActivityForLockScreen();
      }
    }
  }

  /// Antes do ecrã bloquear, grava App Group e força novo ContentState (refreshToken).
  Future<void> _flushIosLiveActivityForLockScreen() async {
    if (!mounted) return;
    final repo = context.read<AppDataRepository>();
    final rest = context.read<RestLiveActivityController>();
    try {
      final list = await repo.fetchAccessibleStartedDayWorkouts();
      if (!mounted) return;
      final w = list.isEmpty ? null : list.first;
      if (w == null && !rest.hasRestSession) return;
      await IosLockScreenLiveActivity.sync(
        workout: w,
        rest: rest,
        repo: repo,
        force: true,
      );
    } catch (_) {}
  }

  void _ensureWorkoutTick(bool need) {
    if (need) {
      _workoutTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _iosLaSyncInFlight) return;
        _iosLaSyncInFlight = true;
        _tickIosLiveActivityForLockScreen();
      });
    } else {
      _workoutTick?.cancel();
      _workoutTick = null;
    }
  }

  /// Atualiza a Live Activity a cada segundo (novo `refreshToken` + App Group), para o ecrã bloqueado
  /// acompanhar o treino/intervalo mesmo quando o `Text(timerInterval:)` do sistema falha.
  Future<void> _tickIosLiveActivityForLockScreen() async {
    try {
      if (!mounted) return;
      final repo = context.read<AppDataRepository>();
      final rest = context.read<RestLiveActivityController>();
      final list = await repo.fetchAccessibleStartedDayWorkouts();
      if (!mounted) return;
      final w = list.isEmpty ? null : list.first;
      if (w == null && !rest.hasRestSession) return;
      await IosLockScreenLiveActivity.sync(
        workout: w,
        rest: rest,
        repo: repo,
        force: true,
      );
    } catch (_) {
    } finally {
      if (mounted) _iosLaSyncInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppSession>();
    final repo = context.watch<AppDataRepository>();
    final restCtrl = context.watch<RestLiveActivityController>();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: widget.child ?? const SizedBox.shrink(),
        ),
        StreamBuilder<List<DayWorkoutEntity>>(
          stream: repo.watchAccessibleStartedDayWorkouts(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            final w = list.isEmpty ? null : list.first;
            final show = w != null;
            _ensureWorkoutTick(show || restCtrl.hasRestSession);

            if (!show && !restCtrl.hasRestSession) {
              IosLockScreenLiveActivity.endIfAny();
              return const SizedBox.shrink();
            }

            if (!_iosLiveActivityFrameScheduled) {
              _iosLiveActivityFrameScheduled = true;
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _iosLiveActivityFrameScheduled = false;
                IosLockScreenLiveActivity.sync(
                  workout: w,
                  rest: restCtrl,
                  repo: repo,
                );
              });
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
