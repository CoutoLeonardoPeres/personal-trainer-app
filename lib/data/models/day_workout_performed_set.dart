import 'dart:convert';

/// Uma série registrada na linha do treino do dia (carga + repetições feitas).
class DayWorkoutPerformedSet {
  const DayWorkoutPerformedSet({
    this.loadKg,
    required this.reps,
  });

  final double? loadKg;
  final int reps;

  Map<String, dynamic> toJson() => {
        'loadKg': loadKg,
        'reps': reps,
      };

  static DayWorkoutPerformedSet? fromJson(Object? e) {
    if (e is! Map) return null;
    final m = Map<String, dynamic>.from(e);
    final repsRaw = m['reps'];
    if (repsRaw == null) return null;
    final reps = (repsRaw is num) ? repsRaw.toInt() : int.tryParse('$repsRaw');
    if (reps == null || reps < 1) return null;
    final loadRaw = m['loadKg'];
    double? loadKg;
    if (loadRaw != null) {
      if (loadRaw is num) {
        loadKg = loadRaw.toDouble();
      } else {
        loadKg = double.tryParse('$loadRaw'.replaceAll(',', '.'));
      }
    }
    return DayWorkoutPerformedSet(loadKg: loadKg, reps: reps);
  }
}

/// Serialização da coluna [DayWorkoutExerciseEntity.performedSetsJson].
abstract final class DayWorkoutPerformedSetCodec {
  static List<DayWorkoutPerformedSet> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return [];
      return decoded.map(DayWorkoutPerformedSet.fromJson).whereType<DayWorkoutPerformedSet>().toList();
    } catch (_) {
      return [];
    }
  }

  static String encode(List<DayWorkoutPerformedSet> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  /// Score do exercício: soma de (carga × repetições) por série (carga nula = 0).
  static double totalVolumeScore(List<DayWorkoutPerformedSet> list) {
    var sum = 0.0;
    for (final s in list) {
      sum += (s.loadKg ?? 0) * s.reps;
    }
    return sum;
  }
}
