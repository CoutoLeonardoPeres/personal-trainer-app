import 'dart:async';

import 'package:flutter/foundation.dart';

/// Garante no máximo uma folha de “treino do dia” por vez e evita duplicar a mesma
/// ao tocar repetidamente no widget de atividade / deep link.
///
/// O estado “aberto” fica só em [registerSheet] ([_popCurrent] não nulo).
///
/// **Importante:** o padrão antigo `_chain.then(run)` enfileirava **todas** as
/// chamadas a [openSingleton]. Duas chamadas seguidas (ex.: rebuild + gesto, ou
/// dois pedidos no mesmo turno) faziam correr um segundo `pushSheet` **depois** de
/// fechares a folha — parecia “reabrir sozinha” após o intervalo. Agora os pedidos
/// são **fundidos** após um [Future.delayed] zero: só o último `workoutId` + closure
/// desse burst é executado. Não se descarta o pedido só porque `_activeWorkoutId`
/// coincide: após fechar a folha (por vezes sem limpar estado na mesma ordem), o
/// próximo toque no calendário tinha de voltar a abrir.
final class ActiveWorkoutSheetCoordinator {
  ActiveWorkoutSheetCoordinator._();

  static String? _activeWorkoutId;
  static VoidCallback? _popCurrent;

  static Future<void>? _consumeLoopFuture;
  static String? _pendingWorkoutId;
  static Future<void> Function()? _pendingPush;

  static void registerSheet(String workoutId, VoidCallback pop) {
    _activeWorkoutId = workoutId;
    _popCurrent = pop;
  }

  static bool get hasOpenSheet => _popCurrent != null;

  static bool isWorkoutOpen(String workoutId) =>
      _popCurrent != null && _activeWorkoutId == workoutId;

  static void notifyClosed(String workoutId) {
    if (_activeWorkoutId == workoutId) {
      _activeWorkoutId = null;
      _popCurrent = null;
    }
    // Se entrou um pedido duplicado do mesmo treino enquanto a sheet estava aberta
    // (comum ao desbloquear e tocar no widget), não reabrir automaticamente após
    // fechar por gesto.
    if (_pendingWorkoutId == workoutId) {
      _pendingWorkoutId = null;
      _pendingPush = null;
    }
  }

  /// Fecha a folha atual, se houver (troca de treino ou limpeza).
  static void dismissCurrent() {
    final pop = _popCurrent;
    if (pop != null) {
      try {
        pop();
      } catch (_) {}
    }
    _popCurrent = null;
    _activeWorkoutId = null;
  }

  /// Abre [pushSheet]. Se já existir folha (qualquer treino), fecha antes — inclusive
  /// o mesmo id (ex.: folha minimizada), para o novo pedido abrir de novo.
  static Future<void> openSingleton(
    String workoutId,
    Future<void> Function() pushSheet,
  ) {
    _pendingWorkoutId = workoutId;
    _pendingPush = pushSheet;
    return _ensureConsumeLoop();
  }

  static Future<void> _ensureConsumeLoop() {
    _consumeLoopFuture ??= _consumeLoop();
    return _consumeLoopFuture!;
  }

  static Future<void> _consumeLoop() async {
    try {
      while (true) {
        await Future<void>.delayed(Duration.zero);
        final id = _pendingWorkoutId;
        final push = _pendingPush;
        if (id == null || push == null) break;

        _pendingWorkoutId = null;
        _pendingPush = null;

        if (_popCurrent != null || _activeWorkoutId != null) {
          dismissCurrent();
          await Future<void>.delayed(Duration.zero);
        }
        try {
          await push();
        } finally {
          notifyClosed(id);
        }
      }
    } finally {
      _consumeLoopFuture = null;
    }
  }
}
