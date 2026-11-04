import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';
import 'performed_sets_merge.dart';
import 'supabase_table_mappers.dart';

/// Push/pull de eventos append-only em `day_workout_performed_sets`.
abstract final class PerformedSetSyncService {
  PerformedSetSyncService._();

  static Map<String, dynamic> toRemoteRow({
    required PerformedSetEventEntity e,
  }) =>
      {
        'id': e.id,
        'day_workout_exercise_id': e.lineId,
        'load_kg': e.loadKg,
        'reps': e.reps,
        'logged_at_ms': e.loggedAtMs,
        'rest_prescribed_sec': e.restPrescribedSec,
        'rest_countdown_elapsed_ms': e.restCountdownElapsedMs,
        'post_rest_modal_ms': e.postRestModalMs,
        'device_id': e.deviceId,
        'created_at': supabaseTs(e.createdAt),
      };

  static DayWorkoutPerformedSet fromRemoteRow(Map<String, dynamic> row) =>
      DayWorkoutPerformedSet(
        setId: row['id'] as String?,
        loadKg: (row['load_kg'] as num?)?.toDouble(),
        reps: (row['reps'] as num?)?.toInt() ?? 1,
        loggedAtMs: (row['logged_at_ms'] as num?)?.toInt(),
        restPrescribedSec: (row['rest_prescribed_sec'] as num?)?.toInt(),
        restCountdownElapsedMs:
            (row['rest_countdown_elapsed_ms'] as num?)?.toInt(),
        postRestModalMs: (row['post_rest_modal_ms'] as num?)?.toInt(),
      );

  /// Insert idempotente (append-only). Retorna true se inseriu ou já existia.
  static Future<bool> pushEvent(
    SupabaseClient client,
    PerformedSetEventEntity event,
  ) async {
    try {
      await client.from('day_workout_performed_sets').insert(
            toRemoteRow(e: event),
          );
      return true;
    } catch (e) {
      final s = e.toString();
      if (s.contains('23505') || s.contains('duplicate')) return true;
      rethrow;
    }
  }

  static Future<List<DayWorkoutPerformedSet>> pullEventsForLine(
    SupabaseClient client,
    String lineId, {
    DateTime? since,
  }) async {
    var q = client
        .from('day_workout_performed_sets')
        .select()
        .eq('day_workout_exercise_id', lineId);
    if (since != null) {
      q = q.gte('created_at', supabaseTs(since));
    }
    final res = await q.order('created_at');
    final list = res as List<dynamic>;
    return list
        .map((e) => fromRemoteRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Persiste merge na linha local (cache JSON derivado dos eventos).
  static Future<void> applyMergedSetsToLine(
    AppDatabase db,
    String lineId,
    List<DayWorkoutPerformedSet> merged,
  ) async {
    final cache = PerformedSetsMerge.toCacheJson(merged);
    final score = merged.isNotEmpty
        ? DayWorkoutPerformedSetCodec.totalExerciseScore(merged)
        : null;
    await (db.update(db.dayWorkoutExercises)
          ..where((e) => e.id.equals(lineId)))
        .write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(cache),
        exerciseScore: score != null ? Value(score) : const Value.absent(),
      ),
    );
  }
}
