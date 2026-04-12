import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:live_activities/live_activities.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import 'rest_live_activity_controller.dart';

// Live Activity no ecrã bloqueado: requer extensão `WorkoutLiveActivityExtension` no Xcode,
// App Group registado na Apple (mesmo ID em Runner + extensão) e Live Activities ativas
// nas definições do iPhone. Ver `ios/WorkoutLiveActivityExtension/`.

/// App Group **idêntico** ao configurado no Xcode (Runner + extensão Widget).
/// Criar em developer.apple.com → Identifiers → App Groups.
const kIosWorkoutLiveActivitiesAppGroup =
    'group.com.personaltrainer.appPersonal.workoutlive';

/// ID estável para createOrUpdate (plugin deriva UUID v5 internamente).
const kIosWorkoutLiveActivityId = 'personal_trainer_workout_lock';

/// Live Activity no ecrã bloqueado / Dynamic Island (iOS 16.1+). Requer extensão Widget no Xcode.
final class IosLockScreenLiveActivity {
  IosLockScreenLiveActivity._();

  static final LiveActivities _plugin = LiveActivities();
  static var _inited = false;
  static var _lastThrottleMs = 0;

  static Future<void> ensureInit() async {
    if (!Platform.isIOS || _inited) return;
    try {
      await _plugin.init(
        appGroupId: kIosWorkoutLiveActivitiesAppGroup,
        requestAndroidNotificationPermission: false,
      );
      _inited = true;
    } catch (e, st) {
      debugPrint('IosLockScreenLiveActivity.init failed: $e\n$st');
    }
  }

  static Future<void> sync({
    required DayWorkoutEntity? workout,
    required RestLiveActivityController rest,
    required AppDataRepository repo,
    /// Ignora throttle de 1s (útil ao ir para background / ecrã bloqueado).
    bool force = false,
  }) async {
    if (!Platform.isIOS) return;
    await ensureInit();
    if (!_inited) return;

    try {
      final supported = await _plugin.areActivitiesSupported();
      if (!supported) {
        if (kDebugMode) {
          debugPrint(
            'IosLockScreenLiveActivity: Live Activities não suportadas '
            '(simulador, iOS < 16.1 ou App no Mac).',
          );
        }
        return;
      }
      final enabled = await _plugin.areActivitiesEnabled();
      if (!enabled) {
        if (kDebugMode) {
          debugPrint(
            'IosLockScreenLiveActivity: Live Activities desativadas nas '
            'Definições do iPhone — ativa em Definições → [App] ou Face ID e código.',
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('IosLockScreenLiveActivity caps: $e');
      return;
    }

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch.toDouble();

    if (workout == null && !rest.hasRestSession) {
      try {
        await _plugin.endActivity(kIosWorkoutLiveActivityId);
      } catch (_) {}
      return;
    }

    final tick = now.millisecondsSinceEpoch;
    if (!force &&
        _lastThrottleMs != 0 &&
        tick - _lastThrottleMs < 1000) {
      return;
    }
    _lastThrottleMs = tick;

    var phase = 'idle';
    var restStartMs = 0.0;
    var restEndMs = 0.0;
    var postStartMs = 0.0;
    var postEndMs = 0.0;
    var prescribedRest = 0;

    if (rest.hasRestSession) {
      prescribedRest = rest.prescribedSec;
      final end = rest.countdownEndsAt;
      restEndMs = end?.millisecondsSinceEpoch.toDouble() ?? 0;
      if (prescribedRest > 0 && restEndMs > 0) {
        restStartMs = restEndMs - prescribedRest * 1000;
        if (restStartMs < 0) restStartMs = 0;
      }
      if (rest.inPostPhase && rest.postPhaseStartedAt != null) {
        phase = 'rest_post';
        postStartMs = rest.postPhaseStartedAt!.millisecondsSinceEpoch.toDouble();
        postEndMs = postStartMs + 6 * 60 * 60 * 1000;
      } else if (end != null && now.isBefore(end)) {
        phase = 'rest';
      } else if (end != null) {
        phase = 'rest_post';
        postStartMs = end.millisecondsSinceEpoch.toDouble();
        postEndMs = postStartMs + 6 * 60 * 60 * 1000;
      }
    } else if (workout != null && workout.status == 'started') {
      phase = 'workout';
    }

    var workoutRunning = false;
    var workoutVirtualStartMs = 0.0;
    var workoutFrozenLabel = '';
    if (workout != null && workout.status == 'started') {
      final sec = repo.effectiveActiveSeconds(workout, now);
      final paused = workout.timerResumeAt == null;
      if (paused) {
        workoutFrozenLabel = _fmtMmSs(sec);
      } else {
        workoutRunning = true;
        workoutVirtualStartMs = nowMs - sec * 1000;
      }
    }

    final data = <String, dynamic>{
      'phase': phase,
      'prescribedRest': prescribedRest,
      'restStartMs': restStartMs,
      'restEndMs': restEndMs,
      'postStartMs': postStartMs,
      'postEndMs': postEndMs,
      'workoutRunning': workoutRunning,
      'workoutVirtualStartMs': workoutVirtualStartMs,
      'workoutFrozenLabel': workoutFrozenLabel,
      'dayWorkoutId': workout?.id ?? '',
    };

    try {
      await _plugin.createOrUpdateActivity(
        kIosWorkoutLiveActivityId,
        data,
        iOSEnableRemoteUpdates: false,
        staleIn: const Duration(hours: 8),
      );
    } catch (e, st) {
      debugPrint('IosLockScreenLiveActivity sync: $e\n$st');
    }
  }

  static Future<void> endIfAny() async {
    if (!Platform.isIOS) return;
    await ensureInit();
    if (!_inited) return;
    try {
      await _plugin.endActivity(kIosWorkoutLiveActivityId);
    } catch (_) {}
  }

  static String _fmtMmSs(int totalSeconds) {
    final s = totalSeconds.clamp(0, 24 * 3600);
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}
