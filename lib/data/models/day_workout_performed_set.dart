import 'dart:convert';

import '../../domain/scoring.dart' as scoring;

/// Uma série registrada na linha do treino do dia (carga + repetições feitas).
class DayWorkoutPerformedSet {
  const DayWorkoutPerformedSet({
    this.setId,
    this.loadKg,
    required this.reps,
    this.loggedAtMs,
    this.restPrescribedSec,
    this.restCountdownElapsedMs,
    this.postRestModalMs,
  });

  /// Identificador estável (UUID) — chave de merge append-only entre dispositivos.
  final String? setId;
  final double? loadKg;
  final int reps;

  /// Momento em que a série foi registrada (epoch ms). Usado para ordenar exercícios no calendário.
  final int? loggedAtMs;

  /// Descanso prescrito entre esta série e a próxima (s), no momento do registro.
  final int? restPrescribedSec;

  /// Tempo real do timer regressivo até o fim do descanso (ms).
  final int? restCountdownElapsedMs;

  /// Tempo na modal após o bipe até o aluno fechar (ms) — uso em relatórios.
  final int? postRestModalMs;

  DayWorkoutPerformedSet copyWith({
    String? setId,
    double? loadKg,
    int? reps,
    int? loggedAtMs,
    int? restPrescribedSec,
    int? restCountdownElapsedMs,
    int? postRestModalMs,
  }) => DayWorkoutPerformedSet(
    setId: setId ?? this.setId,
    loadKg: loadKg ?? this.loadKg,
    reps: reps ?? this.reps,
    loggedAtMs: loggedAtMs ?? this.loggedAtMs,
    restPrescribedSec: restPrescribedSec ?? this.restPrescribedSec,
    restCountdownElapsedMs:
        restCountdownElapsedMs ?? this.restCountdownElapsedMs,
    postRestModalMs: postRestModalMs ?? this.postRestModalMs,
  );

  Map<String, dynamic> toJson() => {
    if (setId != null && setId!.isNotEmpty) 'setId': setId,
    'loadKg': loadKg,
    'reps': reps,
    if (loggedAtMs != null) 'loggedAtMs': loggedAtMs,
    if (restPrescribedSec != null) 'restPrescribedSec': restPrescribedSec,
    if (restCountdownElapsedMs != null)
      'restCountdownElapsedMs': restCountdownElapsedMs,
    if (postRestModalMs != null) 'postRestModalMs': postRestModalMs,
  };

  static DayWorkoutPerformedSet? fromJson(Object? e) {
    if (e is! Map) return null;
    final m = Map<String, dynamic>.from(e);
    final repsRaw = m['reps'];
    if (repsRaw == null) return null;
    final reps = (repsRaw is num) ? repsRaw.toInt() : int.tryParse('$repsRaw');
    if (reps == null || reps < 1) return null;
    final setIdRaw = m['setId'];
    final setId = setIdRaw?.toString().trim();
    final loadRaw = m['loadKg'];
    double? loadKg;
    if (loadRaw != null) {
      if (loadRaw is num) {
        loadKg = loadRaw.toDouble();
      } else {
        loadKg = double.tryParse('$loadRaw'.replaceAll(',', '.'));
      }
    }
    final atRaw = m['loggedAtMs'];
    int? loggedAtMs;
    if (atRaw is num) {
      loggedAtMs = atRaw.toInt();
    } else if (atRaw != null) {
      loggedAtMs = int.tryParse('$atRaw');
    }
    int? optInt(String k) {
      final v = m[k];
      if (v is num) return v.toInt();
      if (v != null) return int.tryParse('$v');
      return null;
    }

    return DayWorkoutPerformedSet(
      setId: setId != null && setId.isNotEmpty ? setId : null,
      loadKg: loadKg,
      reps: reps,
      loggedAtMs: loggedAtMs,
      restPrescribedSec: optInt('restPrescribedSec'),
      restCountdownElapsedMs: optInt('restCountdownElapsedMs'),
      postRestModalMs: optInt('postRestModalMs'),
    );
  }
}

/// Serialização da coluna [DayWorkoutExerciseEntity.performedSetsJson].
abstract final class DayWorkoutPerformedSetCodec {
  static List<DayWorkoutPerformedSet> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return [];
      return decoded
          .map(DayWorkoutPerformedSet.fromJson)
          .whereType<DayWorkoutPerformedSet>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encode(List<DayWorkoutPerformedSet> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  /// Menor [DayWorkoutPerformedSet.loggedAtMs] da lista (séries antigas sem campo → ignora).
  static int? minLoggedAtMs(List<DayWorkoutPerformedSet> list) {
    int? minMs;
    for (final s in list) {
      final t = s.loggedAtMs;
      if (t != null && (minMs == null || t < minMs)) minMs = t;
    }
    return minMs;
  }

  static int? maxLoggedAtMs(List<DayWorkoutPerformedSet> list) {
    int? maxMs;
    for (final s in list) {
      final t = s.loggedAtMs;
      if (t != null && (maxMs == null || t > maxMs)) maxMs = t;
    }
    return maxMs;
  }

  /// Volume bruto: soma (carga × reps) por série (p.ex. calorias / tonelagem).
  static double totalVolumeScore(List<DayWorkoutPerformedSet> list) {
    var sum = 0.0;
    for (final s in list) {
      sum += (s.loadKg ?? 0) * s.reps;
    }
    return sum;
  }

  /// Score do exercício na UI: soma de (carga × reps ÷ 10) por série.
  static double totalExerciseScore(List<DayWorkoutPerformedSet> list) {
    var sum = 0.0;
    for (final s in list) {
      sum += scoring.perSetScoreContribution(
        loadKg: s.loadKg ?? 0,
        reps: s.reps,
      );
    }
    return sum;
  }
}
