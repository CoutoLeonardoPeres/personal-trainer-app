import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'pull_applier.dart';
import 'remote_sync_service.dart';
import 'supabase_sync_api.dart';
import 'sync_engine.dart';
import 'sync_outbox_repository.dart';
import 'sync_state_repository.dart';

/// Ponte local-first usada pelo repositório atual durante a migração.
///
/// A API pública preserva o contrato de [RemoteSyncService], mas nenhuma
/// escrita remota é feita por `.from(...).insert/update/delete`.
class ModernRemoteSyncService implements RemoteSyncService {
  ModernRemoteSyncService(this._db, this._controller)
    : _state = SyncStateRepository(_db),
      _outbox = SyncOutboxRepository(_db, SyncStateRepository(_db));

  final AppDatabase _db;
  final SupabaseSyncController _controller;
  final SyncStateRepository _state;
  final SyncOutboxRepository _outbox;
  Future<void> _serial = Future<void>.value();

  @override
  Future<void> enqueueAudit({
    required String auditLogId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    final id = entityId?.trim();
    if (id == null || id.isEmpty || !supabaseAppEnabled) return;
    final entity = _entityName(entityType);
    if (entity == null) return;

    if (_isSetEvent(action, entityType)) {
      await _enqueueSetEvent(id);
    } else if (_isTimerEvent(action, entityType)) {
      await _enqueueTimerEvent(id, action);
    } else {
      final operation = switch (action) {
        'delete' => 'delete',
        'create' => 'create',
        _ => 'update',
      };
      final row = operation == 'delete'
          ? <String, dynamic>{}
          : await _localPayload(entity, id);
      if (operation != 'delete' && row.isEmpty) return;
      await _outbox.enqueue(
        entity: entity,
        entityId: id,
        opType: operation,
        payload: row,
      );
    }
    unawaited(_scheduleRun());
  }

  Future<void> _scheduleRun() {
    _serial = _serial.then((_) async {
      try {
        await _runOnce();
      } catch (error, stack) {
        _controller.noteDisconnected();
        _controller.noteBackgroundPushError(error);
        if (kDebugMode) debugPrint('ModernSync: $error\n$stack');
      }
    });
    return _serial;
  }

  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _polling?.cancel();
    _polling = Timer.periodic(interval, (_) => unawaited(_scheduleRun()));
  }

  void dispose() => _polling?.cancel();

  void stopPolling() => _polling?.cancel();

  Timer? _polling;

  Future<void> _runOnce() async {
    if (!supabaseAppEnabled) return;
    final client = Supabase.instance.client;
    var user = client.auth.currentUser;
    var metadata = user?.appMetadata ?? const <String, dynamic>{};
    if (user != null &&
        (metadata['tenant_id'] == null || metadata['role'] == null)) {
      try {
        final refreshed = await client.auth.refreshSession();
        user = refreshed.user ?? client.auth.currentUser;
        metadata = user?.appMetadata ?? const <String, dynamic>{};
      } catch (_) {
        // A sessão local continua válida para o modo offline; o outbox fica
        // pendente e será retomado no próximo ciclo.
      }
    }
    if (user == null ||
        metadata['tenant_id'] == null ||
        metadata['role'] == null) {
      return;
    }
    _controller.beginUpload();
    try {
      final engine = SyncEngine(
        api: SupabaseSyncApi(client),
        outbox: _outbox,
        state: _state,
        applyChange: PullApplier(_db).apply,
      );
      await engine.runOnce();
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
    } finally {
      _controller.endUpload();
    }
  }

  Future<Map<String, dynamic>> _localPayload(String entity, String id) async {
    final table = entity;
    final rows = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    if (rows.isEmpty) return <String, dynamic>{};
    final raw = rows.single.data;
    final allowed = _allowedFields[entity] ?? const <String>{};
    return {
      for (final entry in raw.entries)
        if (allowed.contains(entry.key))
          entry.key: _rpcValue(entry.key, entry.value),
    };
  }

  Future<void> _enqueueSetEvent(String lineId) async {
    final event =
        await (_db.select(_db.performedSetEvents)
              ..where((row) => row.lineId.equals(lineId))
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (event == null) return;
    final line = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((row) => row.id.equals(lineId))).getSingleOrNull();
    if (line == null) return;
    final workout = await (_db.select(
      _db.dayWorkouts,
    )..where((row) => row.id.equals(line.dayWorkoutId))).getSingleOrNull();
    if (workout == null) return;
    await _outbox.enqueue(
      entity: 'performed_set_events',
      entityId: event.id,
      opType: 'logged',
      coalescible: false,
      payload: {
        'day_workout_exercise_id': line.id,
        'student_id': workout.studentId,
        'reps': event.reps,
        'load_kg': event.loadKg,
      },
    );
  }

  Future<void> _enqueueTimerEvent(String workoutId, String action) async {
    final workout = await (_db.select(
      _db.dayWorkouts,
    )..where((row) => row.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return;
    final kind = switch (action) {
      'complete' => 'finish',
      'start' => 'start',
      'pause' => 'pause',
      'resume' => 'resume',
      _ => null,
    };
    if (kind == null) return;
    await _outbox.enqueue(
      entity: 'workout_timer_events',
      entityId: const Uuid().v4(),
      opType: kind,
      coalescible: false,
      payload: {'day_workout_id': workout.id, 'student_id': workout.studentId},
    );
  }

  static bool _isSetEvent(String action, String entityType) =>
      entityType == 'day_workout_exercise' && action == 'append_set';

  static bool _isTimerEvent(String action, String entityType) =>
      entityType == 'day_workout' &&
      (action == 'start' ||
          action == 'pause' ||
          action == 'resume' ||
          action == 'complete');

  static String? _entityName(String value) => switch (value) {
    'muscle_group' => 'muscle_groups',
    'exercise' => 'exercises',
    'gym' => 'gyms',
    'personal' => 'personals',
    'student' => 'students',
    'student_gym' => 'student_gyms',
    'training_method' => 'training_methods',
    'workout_group' => 'workout_groups',
    'workout_group_exercise' => 'workout_group_exercises',
    'week_schedule_block' => 'week_schedule_blocks',
    'week_schedule_item' => 'week_schedule_items',
    'day_workout' => 'day_workouts',
    'day_workout_exercise' => 'day_workout_exercises',
    _ => null,
  };

  static dynamic _rpcValue(String key, dynamic value) {
    if (key == 'status' && value is String) {
      return switch (value) {
        'programmed' => 'programado',
        'started' => 'em_andamento',
        'completed' => 'concluido',
        'cancelled' => 'cancelado',
        _ => value,
      };
    }
    if (value is DateTime) {
      if (key == 'day_date' || key == 'week_start_monday') {
        return value.toUtc().toIso8601String().substring(0, 10);
      }
      return value.toUtc().toIso8601String();
    }
    if (value is int &&
        (key.endsWith('_at') || key == 'created_at' || key == 'updated_at')) {
      return DateTime.fromMillisecondsSinceEpoch(
        value * 1000,
        isUtc: true,
      ).toIso8601String();
    }
    return value;
  }

  static const Map<String, Set<String>> _allowedFields = {
    'muscle_groups': {'name'},
    'exercises': {
      'name',
      'muscle_group_id',
      'video_url',
      'alternative_note',
      'alternative_video_url',
    },
    'gyms': {
      'name',
      'cnpj',
      'street',
      'number',
      'complement',
      'district',
      'city',
      'state_uf',
      'cep',
    },
    'personals': {
      'name',
      'cpf',
      'professional_registry',
      'street',
      'number',
      'complement',
      'city',
      'state_uf',
      'cep',
      'email',
      'phone_commercial',
      'phone_mobile',
      'must_change_password',
      'auth_user_id',
      'is_admin',
      'access_tier',
      'max_students_cap',
    },
    'students': {
      'name',
      'is_archived',
      'archived_at',
      'email',
      'goal',
      'cpf',
      'birth_date',
      'street',
      'number',
      'complement',
      'district',
      'city',
      'state_uf',
      'cep',
      'phone_commercial',
      'phone_mobile',
      'must_change_password',
      'auth_user_id',
      'created_by_personal_id',
      'anamnese_completed',
      'access_tier',
      'premium_plan_expires_at',
    },
    'training_methods': {'method', 'description'},
    'workout_groups': {
      'name',
      'description',
      'created_by_personal_id',
      'is_shared',
    },
    'workout_group_exercises': {
      'workout_group_id',
      'exercise_id',
      'position',
      'sort_order',
      'last_load_kg',
      'last_reps',
      'last_reps_text',
      'last_sets',
      'rest_between_sets_sec',
      'training_method_id',
      'combo_id',
    },
    'week_schedule_blocks': {'student_id', 'week_start_monday'},
    'week_schedule_items': {
      'block_id',
      'exercise_id',
      'source_workout_group_id',
      'position',
      'sort_order',
      'sets',
      'reps',
      'reps_text',
      'load_kg',
      'needs_detail',
      'rest_between_sets_sec',
      'training_method_id',
      'combo_id',
    },
    'day_workouts': {
      'student_id',
      'day_date',
      'status',
      'week_item_id',
      'active_duration_seconds',
      'workout_score',
      'started_at',
      'completed_at',
      'timer_resume_at',
      'source_workout_group_id',
      'watch_calories_kcal',
      'watch_avg_heart_rate_bpm',
    },
    'day_workout_exercises': {
      'day_workout_id',
      'exercise_id',
      'position',
      'sort_order',
      'sets',
      'reps',
      'reps_text',
      'load_kg',
      'exercise_score',
      'rest_between_sets_sec',
      'training_method_id',
      'combo_id',
    },
  };

  @override
  Future<void> recoverPendingWork() => _scheduleRun();

  @override
  Future<void> mirrorStudentRowNow(String studentId) => _scheduleRun();

  @override
  Future<void> mirrorPersonalRowNow(String personalId) => _scheduleRun();

  @override
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) =>
      _scheduleRun();

  @override
  Future<void> refreshRecentCompletedHistoryForStudent(
    String studentId, {
    int limit = 40,
  }) => _scheduleRun();

  @override
  Future<void> refreshStudentWeekScheduleFromCloud(
    String studentId, {
    required DateTime weekMonday,
  }) => _scheduleRun();

  @override
  Future<void> repairMissingStudentWeekScheduleItemsOnCloud(
    String studentId, {
    required DateTime weekMonday,
  }) => _scheduleRun();

  @override
  Future<void> refreshExercisesCatalogFromCloud() => _scheduleRun();

  @override
  Future<void> refreshWorkoutGroupsCatalogFromCloud() => _scheduleRun();

  @override
  Future<void> refreshExercisesByIdsFromCloud(Iterable<String> exerciseIds) =>
      _scheduleRun();
}
