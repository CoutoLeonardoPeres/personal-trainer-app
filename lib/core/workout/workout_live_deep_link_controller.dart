import 'package:flutter/foundation.dart';

/// Pedido vindos do URL scheme da Live Activity (`apppersonal://workout/register-set`).
class WorkoutLiveSheetOpenRequest {
  const WorkoutLiveSheetOpenRequest({
    required this.dayWorkoutId,
    this.preferRestTimerOverlay = false,
  });

  final String dayWorkoutId;
  final bool preferRestTimerOverlay;
}

final class WorkoutLiveDeepLinkController extends ChangeNotifier {
  WorkoutLiveSheetOpenRequest? _pendingRequest;
  String? _lastAcceptedWorkoutId;
  DateTime? _lastAcceptedAt;
  static const Duration _sameWorkoutThrottle = Duration(seconds: 4);

  /// ID do treino do dia a abrir na sheet ativa (após resolver permissões).
  String? get pendingWorkoutId => _pendingRequest?.dayWorkoutId;

  void requestOpenActiveSheet(
    String dayWorkoutId, {
    bool preferRestTimerOverlay = false,
  }) {
    if (dayWorkoutId.isEmpty) return;
    final now = DateTime.now();
    final lastId = _lastAcceptedWorkoutId;
    final lastAt = _lastAcceptedAt;
    if (lastId == dayWorkoutId &&
        lastAt != null &&
        now.difference(lastAt) < _sameWorkoutThrottle) {
      return;
    }
    // Vários `apppersonal://…` (ex.: toques na Live Activity ao desbloquear) não
    // devem enfileirar o mesmo pedido várias vezes antes do [MainShell] consumir.
    final pending = _pendingRequest;
    if (pending != null &&
        pending.dayWorkoutId == dayWorkoutId &&
        pending.preferRestTimerOverlay == preferRestTimerOverlay) {
      return;
    }
    _pendingRequest = WorkoutLiveSheetOpenRequest(
      dayWorkoutId: dayWorkoutId,
      preferRestTimerOverlay: preferRestTimerOverlay,
    );
    _lastAcceptedWorkoutId = dayWorkoutId;
    _lastAcceptedAt = now;
    notifyListeners();
  }

  /// Lê e limpa o pedido (ex.: ao abrir a sheet no [MainShell]).
  WorkoutLiveSheetOpenRequest? takePendingRequest() {
    final req = _pendingRequest;
    _pendingRequest = null;
    if (req != null) notifyListeners();
    return req;
  }
}
