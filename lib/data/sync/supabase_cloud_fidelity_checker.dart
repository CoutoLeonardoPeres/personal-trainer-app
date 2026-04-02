import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';

/// Compara contagens SQLite × Postgres em segundo plano (não depende de auditoria
/// nem de haver dados locais — local 0 vs nuvem N já sinaliza divergência).
class SupabaseCloudFidelityChecker {
  SupabaseCloudFidelityChecker(this._db, this._sync);

  final AppDatabase _db;
  final SupabaseSyncController _sync;

  Timer? _timer;
  bool _started = false;

  static const Duration _firstDelay = Duration(minutes: 3);
  static const Duration _interval = Duration(minutes: 18);

  static const _tables = <String>[
    'muscle_groups',
    'exercises',
    'gyms',
    'personals',
    'students',
    'student_gyms',
    'training_methods',
    'workout_groups',
    'workout_group_exercises',
    'week_schedule_blocks',
    'week_schedule_items',
    'day_workouts',
    'day_workout_exercises',
    'audit_logs',
  ];

  void start() {
    _timer?.cancel();
    _started = false;
    if (!supabaseAppEnabled) return;
    _started = true;
    unawaited(_schedulePeriodic());
  }

  Future<void> _schedulePeriodic() async {
    await Future<void>.delayed(_firstDelay);
    if (!_started || !supabaseAppEnabled) return;
    unawaited(_runOnce());
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => unawaited(_runOnce()));
  }

  void dispose() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runOnce() async {
    if (!supabaseAppEnabled) return;
    try {
      final client = Supabase.instance.client;
      final mismatches = <String>[];

      for (var i = 0; i < _tables.length; i++) {
        final name = _tables[i];
        final local = await _localCount(_db, name);
        final remote = await _remoteCount(client, name);
        if (local != remote) {
          mismatches.add('$name: celular $local / nuvem $remote');
        }
        if (i % 3 == 2) await Future<void>.delayed(Duration.zero);
      }

      final detail = mismatches.isEmpty
          ? null
          : (mismatches.length > 6
              ? '${mismatches.take(6).join('; ')}… (+${mismatches.length - 6})'
              : mismatches.join('; '));

      _sync.noteFidelityResult(
        at: DateTime.now(),
        aligned: mismatches.isEmpty,
        detail: detail,
      );
    } catch (e, st) {
      debugPrint('SupabaseCloudFidelityChecker: $e\n$st');
      _sync.noteFidelityCheckFailed(e);
    }
  }

  static Future<int> _remoteCount(SupabaseClient client, String table) async {
    final n = await client.from(table).count();
    return n;
  }

  static Future<int> _localCount(AppDatabase db, String table) async {
    final agg = countAll();
    switch (table) {
      case 'muscle_groups':
        final q = db.selectOnly(db.muscleGroups)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'exercises':
        final q = db.selectOnly(db.exercises)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'gyms':
        final q = db.selectOnly(db.gyms)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'personals':
        final q = db.selectOnly(db.personals)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'students':
        final q = db.selectOnly(db.students)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'student_gyms':
        final q = db.selectOnly(db.studentGyms)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'training_methods':
        final q = db.selectOnly(db.trainingMethods)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'workout_groups':
        final q = db.selectOnly(db.workoutGroups)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'workout_group_exercises':
        final q = db.selectOnly(db.workoutGroupExercises)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'week_schedule_blocks':
        final q = db.selectOnly(db.weekScheduleBlocks)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'week_schedule_items':
        final q = db.selectOnly(db.weekScheduleItems)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'day_workouts':
        final q = db.selectOnly(db.dayWorkouts)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'day_workout_exercises':
        final q = db.selectOnly(db.dayWorkoutExercises)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      case 'audit_logs':
        final q = db.selectOnly(db.auditLogs)..addColumns([agg]);
        return (await q.getSingle()).read(agg)!;
      default:
        return 0;
    }
  }
}
