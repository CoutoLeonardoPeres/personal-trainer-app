import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'remote_sync_service.dart';
import 'supabase_catalog_cloud_reconcile.dart';
import 'supabase_table_mappers.dart';

class _QueuedAudit {
  _QueuedAudit({
    required this.auditLogId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.payload,
  });

  final String auditLogId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, Object?>? payload;
}

/// Espelha o SQLite no Supabase **logo após** cada gravação local que regista auditoria
/// ([AppDataRepository._audit]): [enqueueAudit] arranca a fila de imediato (`unawaited`)
/// e os pedidos são processados em série (com pequeno intervalo entre um e outro para
/// não bloquear a UI).
///
/// O “envio completo” periódico ([SupabaseAutoPushScheduler]) é redundância / recuperação;
/// o fluxo normal é **incremental** por entidade.
///
/// Falha de rede ou JWT **não** apaga nem altera o SQLite: o utilizador continua com
/// os dados no telemóvel; ao arranque, [recoverPendingWork] volta a enfileirar envios
/// a partir dos `audit_logs`. A nuvem é espelho, não fonte única.
class SupabaseRemoteSyncService implements RemoteSyncService {
  SupabaseRemoteSyncService(this._db, this._controller);

  final AppDatabase _db;
  final SupabaseSyncController _controller;

  final List<_QueuedAudit> _queue = [];
  final Set<String> _queuedAuditIds = <String>{};
  bool _workerRunning = false;
  bool _recovering = false;

  /// Um `Duration.zero` entre jobs devolve o controlo ao loop de eventos sem esperar
  /// um frame inteiro — fila continua não bloqueante e o primeiro envio sai logo a seguir
  /// à gravação local.
  static const Duration _yieldBetweenJobs = Duration.zero;

  @override
  Future<void> enqueueAudit({
    required String auditLogId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    if (!_queuedAuditIds.add(auditLogId)) return;
    _queue.add(
      _QueuedAudit(
        auditLogId: auditLogId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
      ),
    );
    unawaited(_pumpQueue());
  }

  Future<void> _pumpQueue() async {
    if (_workerRunning) return;
    _workerRunning = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        try {
          await _syncOneJob(job);
        } finally {
          _queuedAuditIds.remove(job.auditLogId);
        }
        if (_queue.isNotEmpty) {
          await Future<void>.delayed(_yieldBetweenJobs);
        }
      }
    } finally {
      _workerRunning = false;
      if (_queue.isNotEmpty) {
        unawaited(_pumpQueue());
      }
    }
  }

  @override
  Future<void> recoverPendingWork() async {
    if (_recovering || !supabaseAppEnabled) return;
    _recovering = true;
    try {
      final rows = await (_db.select(_db.auditLogs)
            ..orderBy([
              (t) => OrderingTerm.desc(t.at),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .get();

      final seenEntityKeys = <String>{};
      final recovered = <AuditLogEntity>[];
      for (final row in rows) {
        final entityId = row.entityId;
        if (entityId == null || entityId.isEmpty) continue;
        final key = '${row.entityType}::$entityId';
        if (!seenEntityKeys.add(key)) continue;
        recovered.add(row);
      }

      for (final row in recovered.reversed) {
        await enqueueAudit(
          auditLogId: row.id,
          action: row.action,
          entityType: row.entityType,
          entityId: row.entityId,
        );
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> _syncOneJob(_QueuedAudit job) async {
    if (!supabaseAppEnabled) return;

    final client = Supabase.instance.client;
    final auditRow = await (_db.select(_db.auditLogs)
          ..where((a) => a.id.equals(job.auditLogId)))
        .getSingleOrNull();
    if (auditRow == null) return;

    _controller.beginUpload();
    try {
      const catalogThrottleTypes = {
        'muscle_group',
        'exercise',
        'workout_group',
        'workout_group_exercise',
        'week_schedule',
        'week_schedule_item',
        'day_workout',
        'day_workout_exercise',
      };
      if (catalogThrottleTypes.contains(job.entityType)) {
        // Sem throttle: vários jobs seguidos (ex.: linhas de treino) precisam de
        // reconciliação fresh antes de cada upsert — senão 23505 em exercises / muscle_groups.
        await reconcileLocalCatalogWithCloud(_db, client);
      }
      try {
        await client.from('audit_logs').upsert(supabaseAuditLog(auditRow));
      } catch (e, st) {
        debugPrint('SupabaseRemoteSyncService audit_logs (ignorado): $e\n$st');
      }

      await _mirrorAfterAudit(
        client,
        action: job.action,
        entityType: job.entityType,
        entityId: job.entityId,
        payload: job.payload,
      );
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
    } catch (e, st) {
      debugPrint('SupabaseRemoteSyncService: $e\n$st');
      _controller.noteDisconnected();
      _controller.noteBackgroundPushError(e);
    } finally {
      _controller.endUpload();
    }
  }

  static bool _isExerciseNormalizedNameConflict(Object e) {
    final s = e.toString();
    return s.contains('23505') && s.contains('exercises_unique_normalized_name');
  }

  Future<({MuscleGroupEntity mg, ExerciseEntity ex})?> _bundledExerciseForPush(
    String exerciseId,
  ) async {
    final e = await (_db.select(_db.exercises)..where((t) => t.id.equals(exerciseId)))
        .getSingleOrNull();
    if (e == null) return null;
    final m = await (_db.select(_db.muscleGroups)
          ..where((t) => t.id.equals(e.muscleGroupId)))
        .getSingleOrNull();
    if (m == null) {
      debugPrint(
        'SupabaseRemoteSyncService: exercício ${e.id} referencia muscle_group '
        '${e.muscleGroupId} inexistente no SQLite; não enviar exercises.',
      );
      return null;
    }
    return (mg: m, ex: e);
  }

  Future<void> _pushMuscleGroupAndExercise(
    SupabaseClient client,
    MuscleGroupEntity mg,
    ExerciseEntity e,
  ) async {
    await client.from('muscle_groups').upsert(supabaseMuscleGroup(mg));
    await client.from('exercises').upsert(supabaseExercise(e));
  }

  /// Envia primeiro o grupo muscular e depois o exercício (FK `muscle_group_id`).
  Future<void> _mirrorExerciseWithDependencies(
    SupabaseClient client,
    ExerciseEntity ex,
  ) async {
    final first = await _bundledExerciseForPush(ex.id);
    if (first == null) return;

    try {
      await _pushMuscleGroupAndExercise(client, first.mg, first.ex);
    } catch (e, st) {
      if (!_isExerciseNormalizedNameConflict(e)) {
        debugPrint('SupabaseRemoteSyncService: $e\n$st');
        rethrow;
      }
      await reconcileLocalCatalogWithCloud(_db, client);
      final again = await _bundledExerciseForPush(ex.id);
      if (again == null) {
        debugPrint(
          'SupabaseRemoteSyncService: após reconciliar, exercício ${ex.id} '
          'sumiu do SQLite (fundido a id remoto); upsert em exercises não necessário.',
        );
        return;
      }
      await _pushMuscleGroupAndExercise(client, again.mg, again.ex);
    }
  }

  /// Garante `muscle_groups` + `exercises` na nuvem antes de FK `exercise_id`
  /// em tabelas filhas (evita 23503 com fila fora de ordem).
  Future<void> _ensureExerciseDependenciesMirrored(
    SupabaseClient client,
    String exerciseId,
  ) async {
    final ex = await (_db.select(_db.exercises)..where((t) => t.id.equals(exerciseId)))
        .getSingleOrNull();
    if (ex == null) {
      debugPrint(
        'SupabaseRemoteSyncService: exercise id=$exerciseId ausente no SQLite; '
        'sem pré-sync para FK.',
      );
      return;
    }
    await _mirrorExerciseWithDependencies(client, ex);
  }

  Future<void> _mirrorAfterAudit(
    SupabaseClient client, {
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    final eid = entityId;
    if (eid == null) return;

    final isDelete = action == 'delete';

    switch (entityType) {
      case 'muscle_group':
        if (isDelete) {
          await client.from('muscle_groups').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.muscleGroups)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await client.from('muscle_groups').upsert(supabaseMuscleGroup(row));
          }
        }
      case 'exercise':
        if (isDelete) {
          await client.from('exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.exercises)..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) await _mirrorExerciseWithDependencies(client, row);
        }
      case 'gym':
        if (isDelete) {
          await client.from('gyms').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.gyms)..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) await client.from('gyms').upsert(supabaseGym(row));
        }
      case 'personal':
        if (isDelete) {
          await client.from('personals').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.personals)..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) await client.from('personals').upsert(supabasePersonal(row));
        }
      case 'student':
        if (isDelete) {
          await client.from('students').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.students)..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await client.from('students').upsert(supabaseStudent(row));
            await client.from('student_gyms').delete().eq('student_id', eid);
            final links = await (_db.select(_db.studentGyms)
                  ..where((t) => t.studentId.equals(eid)))
                .get();
            for (var i = 0; i < links.length; i++) {
              final l = links[i];
              await client.from('student_gyms').insert({
                'student_id': l.studentId,
                'gym_id': l.gymId,
              });
              if (i % 4 == 3) await Future<void>.delayed(Duration.zero);
            }
          }
        }
      case 'training_method':
        if (isDelete) {
          await client.from('training_methods').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.trainingMethods)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await client.from('training_methods').upsert(supabaseTrainingMethod(row));
          }
        }
      case 'workout_group':
        if (isDelete) {
          await client.from('workout_groups').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.workoutGroups)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await client.from('workout_groups').upsert(supabaseWorkoutGroup(row));
          }
          final lines = await (_db.select(_db.workoutGroupExercises)
                ..where((t) => t.workoutGroupId.equals(eid)))
              .get();
          for (var i = 0; i < lines.length; i++) {
            final l = lines[i];
            await _ensureExerciseDependenciesMirrored(client, l.exerciseId);
            await client.from('workout_group_exercises').upsert(supabaseWorkoutGroupExercise(l));
            if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
          }
        }
      case 'workout_group_exercise':
        if (isDelete) {
          await client.from('workout_group_exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.workoutGroupExercises)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await _ensureExerciseDependenciesMirrored(client, row.exerciseId);
            await client.from('workout_group_exercises').upsert(supabaseWorkoutGroupExercise(row));
          }
        }
      case 'week_schedule_block':
        if (isDelete) {
          await client.from('week_schedule_blocks').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.weekScheduleBlocks)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await client.from('week_schedule_blocks').upsert(supabaseWeekBlock(row));
          }
        }
      case 'week_schedule':
        await _mirrorWeekScheduleBlock(client, eid);
      case 'week_schedule_item':
        if (isDelete) {
          await client.from('week_schedule_items').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.weekScheduleItems)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await _ensureExerciseDependenciesMirrored(client, row.exerciseId);
            await client.from('week_schedule_items').upsert(supabaseWeekItem(row));
          }
        }
      case 'day_workout':
        if (isDelete) {
          await client
              .from('day_workout_exercises')
              .delete()
              .eq('day_workout_id', eid);
          await client.from('day_workouts').delete().eq('id', eid);
        } else {
          await _mirrorDayWorkoutBundle(client, eid);
        }
      case 'day_workout_exercise':
        if (isDelete) {
          await client.from('day_workout_exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(_db.dayWorkoutExercises)
                ..where((t) => t.id.equals(eid)))
              .getSingleOrNull();
          if (row != null) {
            await _ensureExerciseDependenciesMirrored(client, row.exerciseId);
            await client.from('day_workout_exercises').upsert(supabaseDayWorkoutExercise(row));
          }
        }
      default:
        break;
    }
  }

  Future<void> _mirrorWeekScheduleBlock(SupabaseClient client, String blockId) async {
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(blockId)))
        .getSingleOrNull();
    if (block == null) return;
    await client.from('week_schedule_blocks').upsert(supabaseWeekBlock(block));
    final items = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId)))
        .get();
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      await _ensureExerciseDependenciesMirrored(client, it.exerciseId);
      await client.from('week_schedule_items').upsert(supabaseWeekItem(it));
      if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _mirrorDayWorkoutBundle(SupabaseClient client, String workoutId) async {
    final w = await (_db.select(_db.dayWorkouts)..where((d) => d.id.equals(workoutId)))
        .getSingleOrNull();
    if (w == null) return;
    await client.from('day_workouts').upsert(supabaseDayWorkout(w));
    final lines = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(workoutId)))
        .get();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      await _ensureExerciseDependenciesMirrored(client, line.exerciseId);
      await client.from('day_workout_exercises').upsert(supabaseDayWorkoutExercise(line));
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }
  }
}
