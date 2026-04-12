import 'package:flutter/foundation.dart';

/// Pedido vindos do URL scheme da Live Activity (`apppersonal://workout/register-set`).
final class WorkoutLiveDeepLinkController extends ChangeNotifier {
  String? _pendingWorkoutId;

  /// ID do treino do dia a abrir na sheet ativa (após resolver permissões).
  String? get pendingWorkoutId => _pendingWorkoutId;

  void requestOpenActiveSheet(String dayWorkoutId) {
    if (dayWorkoutId.isEmpty) return;
    _pendingWorkoutId = dayWorkoutId;
    notifyListeners();
  }

  /// Lê e limpa o pedido (ex.: ao abrir a sheet no [MainShell]).
  String? takePendingWorkoutId() {
    final id = _pendingWorkoutId;
    _pendingWorkoutId = null;
    if (id != null) notifyListeners();
    return id;
  }
}
