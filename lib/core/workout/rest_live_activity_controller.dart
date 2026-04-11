import 'dart:async';

import 'package:flutter/foundation.dart';

/// Estado espelhado do descanso entre séries para o “gadget” flutuante (aluno).
class RestLiveActivityController extends ChangeNotifier {
  Timer? _pulse;
  int? _prescribedSec;
  DateTime? _deadline;
  var _postPhase = false;
  DateTime? _postStart;

  bool get hasRestSession => _prescribedSec != null && _prescribedSec! > 0;

  int get prescribedSec => _prescribedSec ?? 0;

  bool get inPostPhase => _postPhase;

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
    notifyListeners();
  }

  void enterPostPhase() {
    if (!hasRestSession) return;
    _postPhase = true;
    _postStart = DateTime.now();
    _startPulse();
    notifyListeners();
  }

  void clear() {
    _stopPulse();
    _prescribedSec = null;
    _deadline = null;
    _postPhase = false;
    _postStart = null;
    notifyListeners();
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
    super.dispose();
  }
}
