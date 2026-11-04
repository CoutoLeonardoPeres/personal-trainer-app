import 'package:uuid/uuid.dart';

import '../models/day_workout_performed_set.dart';

const _uuid = Uuid();

/// Merge append-only de séries por [DayWorkoutPerformedSet.setId].
abstract final class PerformedSetsMerge {
  PerformedSetsMerge._();

  static String newSetId() => _uuid.v4();

  /// Garante `setId` em entradas legadas (derivado estável do índice).
  static List<DayWorkoutPerformedSet> normalizeLegacySets(
    List<DayWorkoutPerformedSet> sets, {
    required String lineId,
  }) {
    if (sets.isEmpty) return const [];
    final out = <DayWorkoutPerformedSet>[];
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      out.add(
        s.setId != null && s.setId!.isNotEmpty
            ? s
            : s.copyWith(setId: '$lineId:set:$i'),
      );
    }
    return out;
  }

  /// União por `setId` — nunca descarta série de outro dispositivo.
  static List<DayWorkoutPerformedSet> unionBySetId(
    Iterable<DayWorkoutPerformedSet> a,
    Iterable<DayWorkoutPerformedSet> b,
  ) {
    final byId = <String, DayWorkoutPerformedSet>{};
    for (final s in a) {
      final id = s.setId;
      if (id == null || id.isEmpty) continue;
      byId[id] = s;
    }
    for (final s in b) {
      final id = s.setId;
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => s);
    }
    final merged = byId.values.toList()
      ..sort((x, y) {
        final tx = x.loggedAtMs ?? 0;
        final ty = y.loggedAtMs ?? 0;
        if (tx != ty) return tx.compareTo(ty);
        return (x.setId ?? '').compareTo(y.setId ?? '');
      });
    return merged;
  }

  static String toCacheJson(List<DayWorkoutPerformedSet> sets) =>
      DayWorkoutPerformedSetCodec.encode(sets);
}
