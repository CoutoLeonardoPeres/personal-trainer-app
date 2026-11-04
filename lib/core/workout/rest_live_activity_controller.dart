import 'dart:async';

import 'package:flutter/foundation.dart';

import '../notifications/workout_activity_local_notifier.dart';
import '../preferences/rest_timer_prefs.dart';

/// Estado espelhado do descanso entre séries para o “gadget” flutuante (aluno).
class RestLiveActivityController extends ChangeNotifier {
  Timer? _pulse;
  int? _prescribedSec;
  DateTime? _deadline;
  var _postPhase = false;
  DateTime? _postStart;
  var _endNotificationArmed = false;

  bool get hasRestSession => _prescribedSec != null && _prescribedSec! > 0;

  int get prescribedSec => _prescribedSec ?? 0;

  bool get inPostPhase => _postPhase;

  /// Fim do countdown (para alinhar UI com o mesmo instante).
  DateTime? get countdownEndsAt => _deadline;

  /// Início da fase pós-intervalo (bipe / “pronto para próxima”).
  DateTime? get postPhaseStartedAt => _postStart;

  bool get endNotificationArmed => _endNotificationArmed;

  /// Fase regressiva: segundos até acabar o intervalo prescrito.
  int get remainingCountdownSec {
    final d = _deadline;
    if (d == null || _postPhase) return 0;
    final r = d.difference(DateTime.now()).inSeconds;
    return r < 0 ? 0 : r;
  }

  /// Após o bip: tempo decorrido na fase “pronto para próxima série”.
  int get postPhaseElapsedSec {
    final s = _postStart;
    if (s == null) return 0;
    return DateTime.now().difference(s).inSeconds;
  }

  void beginCountdown({required int prescribedSec}) {
    _stopPulse();
    if (prescribedSec <= 0) {
      clear();
      return;
    }
    _prescribedSec = prescribedSec;
    _deadline = DateTime.now().add(Duration(seconds: prescribedSec));
    _postPhase = false;
    _postStart = null;
    _startPulse();
    unawaited(armEndNotificationForBackground());
    notifyListeners();
  }

  /// Agenda notificação com som para o fim do intervalo (tela bloqueada / outro app).
  Future<void> armEndNotificationForBackground() async {
    final d = _deadline;
    if (d == null || _postPhase || !hasRestSession) {
      await _cancelEndNotification();
      return;
    }
    if (!await RestTimerPrefs.isSoundEnabled()) {
      await _cancelEndNotification();
      return;
    }
    if (!d.isAfter(DateTime.now())) return;
    _endNotificationArmed = true;
    await WorkoutActivityLocalNotifier.instance.scheduleRestTimerEnd(at: d);
  }

  /// Quando o app volta do segundo plano / ecrã bloqueado: entra na fase pós-bipe
  /// se o prazo já passou (timers Dart não correm em background).
  void syncWithWallClock() {
    if (!hasRestSession || _postPhase) return;
    final d = _deadline;
    if (d == null) return;
    if (DateTime.now().isBefore(d)) return;
    unawaited(_cancelEndNotification());
    _postPhase = true;
    _postStart = d;
    _startPulse();
    notifyListeners();
  }

  void enterPostPhase({DateTime? startedAt}) {
    if (!hasRestSession) return;
    unawaited(_cancelEndNotification());
    _postPhase = true;
    _postStart = startedAt ?? DateTime.now();
    _startPulse();
    notifyListeners();
  }

  void clear() {
    _stopPulse();
    unawaited(_cancelEndNotification());
    _prescribedSec = null;
    _deadline = null;
    _postPhase = false;
    _postStart = null;
    notifyListeners();
  }

  Future<void> _cancelEndNotification() async {
    _endNotificationArmed = false;
    await WorkoutActivityLocalNotifier.instance.cancelRestTimerEnd();
  }

  void _startPulse() {
    _pulse ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopPulse() {
    _pulse?.cancel();
    _pulse = null;
  }

  @override
  void dispose() {
    _stopPulse();
    unawaited(_cancelEndNotification());
    super.dispose();
  }
}
