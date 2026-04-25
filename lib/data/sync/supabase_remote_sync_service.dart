import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'remote_sync_service.dart';
import 'supabase_catalog_cloud_reconcile.dart';
import 'supabase_pull_sync_service.dart';
import 'supabase_table_mappers.dart';

class _QueuedAudit {
  _QueuedAudit({
    required this.queueItemId,
    required this.auditLogId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.payload,
    this.attempt = 0,
  });

  final String queueItemId;
  final String auditLogId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, Object?>? payload;
  final int attempt;

  _QueuedAudit copyWith({int? attempt}) => _QueuedAudit(
    queueItemId: queueItemId,
    auditLogId: auditLogId,
    action: action,
    entityType: entityType,
    entityId: entityId,
    payload: payload,
    attempt: attempt ?? this.attempt,
  );
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

  final List<_QueuedAudit> _priorityQueue = [];
  final List<_QueuedAudit> _queue = [];
  final Set<String> _queuedItemIds = <String>{};
  bool _workerRunning = false;
  bool _recovering = false;

  /// Um `Duration.zero` entre jobs devolve o controlo ao loop de eventos sem esperar
  /// um frame inteiro — fila continua não bloqueante e o primeiro envio sai logo a seguir
  /// à gravação local.
  static const Duration _yieldBetweenJobs = Duration.zero;
  static const int _maxImmediateRetries = 6;

  static Duration _retryDelayForAttempt(int attempt) {
    // Backoff curto para manter sensação de "tempo real" sem entrar em loop agressivo.
    final ms = switch (attempt) {
      <= 1 => 600,
      2 => 1200,
      3 => 2000,
      4 => 3200,
      5 => 5000,
      _ => 8000,
    };
    return Duration(milliseconds: ms);
  }

  static bool _isHighPriorityAudit({
    required String entityType,
    required String action,
  }) {
    if (entityType == 'day_workout' || entityType == 'day_workout_exercise') {
      return true;
    }
    // Catálogo: processar antes da fila longa (planejamento / semanas) para o indicador
    // de tráfego e o reconcile de exercícios reagirem de imediato.
    if (entityType == 'exercise' || entityType == 'muscle_group') {
      return true;
    }
    return action == 'complete' && entityType == 'week_schedule_item';
  }

  static int _priorityFor({
    required String entityType,
    required String action,
  }) {
    if (_isHighPriorityAudit(entityType: entityType, action: action)) {
      return 0;
    }
    if (entityType == 'day_workout' || entityType == 'day_workout_exercise') {
      return 0;
    }
    if (entityType == 'week_schedule' ||
        entityType == 'week_schedule_item' ||
        entityType == 'week_schedule_block') {
      return 1;
    }
    return 2;
  }

  static String? _dedupeKeyFor({
    required String action,
    required String entityType,
    required String? entityId,
  }) {
    if (entityId == null || entityId.isEmpty) return null;
    if (entityType == 'day_workout_exercise') {
      if (action == 'append_set' ||
          action == 'remove_set' ||
          action == 'update_set' ||
          action == 'patch_set_rest') {
        return 'line::$entityId::performed_sets';
      }
      return 'line::$entityId::$action';
    }
    if (entityType == 'day_workout') {
      if (action == 'touch') return 'workout::$entityId::touch';
      return 'workout::$entityId::$action';
    }
    if (action == 'update' || action == 'touch') {
      return '$entityType::$entityId::state';
    }
    return '$entityType::$entityId::$action';
  }

  Future<String> _upsertSyncQueueItem({
    required String auditLogId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? payload,
  }) async {
    final now = DateTime.now();
    var dedupeKey = _dedupeKeyFor(
      action: action,
      entityType: entityType,
      entityId: entityId,
    );
    final encodedPayload = payload == null ? null : jsonEncode(payload);
    if (dedupeKey != null) {
      final nonNullDedupeKey = dedupeKey;
      final existing =
          await (_db.select(_db.syncQueue)
                ..where((t) => t.dedupeKey.equals(nonNullDedupeKey)))
              .getSingleOrNull();
      if (existing != null && existing.status != 'syncing') {
        await (_db.update(
          _db.syncQueue,
        )..where((t) => t.id.equals(existing.id))).write(
          SyncQueueCompanion(
            operation: Value(action),
            payloadJson: Value(encodedPayload),
            status: const Value('pending'),
            retryCount: const Value(0),
            nextRetryAt: const Value(null),
            auditLogId: Value(auditLogId),
            updatedAt: Value(now),
            priority: Value(
              _priorityFor(entityType: entityType, action: action),
            ),
          ),
        );
        return existing.id;
      }
      if (existing != null && existing.status == 'syncing') {
        // Evita violação de unicidade quando a mesma entidade recebe novo evento
        // durante um envio em progresso.
        dedupeKey = null;
      }
    }
    final id = const Uuid().v4();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: action,
            payloadJson: Value(encodedPayload),
            priority: Value(_priorityFor(entityType: entityType, action: action)),
            status: const Value('pending'),
            retryCount: const Value(0),
            nextRetryAt: const Value(null),
            dedupeKey: Value(dedupeKey),
            auditLogId: Value(auditLogId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  @override
  Future<void> enqueueAudit({
    required String auditLogId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    final safeEntityId = entityId?.trim();
    if (safeEntityId == null || safeEntityId.isEmpty) return;
    final queueItemId = await _upsertSyncQueueItem(
      auditLogId: auditLogId,
      action: action,
      entityType: entityType,
      entityId: safeEntityId,
      payload: payload,
    );
    final q = _QueuedAudit(
      queueItemId: queueItemId,
      auditLogId: auditLogId,
      action: action,
      entityType: entityType,
      entityId: safeEntityId,
      payload: payload,
    );
    _enqueueInternal(q);
  }

  void _enqueueInternal(_QueuedAudit q) {
    if (!_queuedItemIds.add(q.queueItemId)) return;
    if (_isHighPriorityAudit(entityType: q.entityType, action: q.action)) {
      _priorityQueue.add(q);
    } else {
      _queue.add(q);
    }
    unawaited(_pumpQueue());
  }

  Future<void> _pumpQueue() async {
    if (_workerRunning) return;
    _workerRunning = true;
    try {
      while (_priorityQueue.isNotEmpty || _queue.isNotEmpty) {
        final job = _priorityQueue.isNotEmpty
            ? _priorityQueue.removeAt(0)
            : _queue.removeAt(0);
        var ok = false;
        try {
          ok = await _syncOneJob(job);
        } finally {
          _queuedItemIds.remove(job.queueItemId);
        }
        if (!ok) {
          final nextAttempt = job.attempt + 1;
          if (nextAttempt <= _maxImmediateRetries) {
            final retry = job.copyWith(attempt: nextAttempt);
            final delay = _retryDelayForAttempt(nextAttempt);
            debugPrint(
              'SupabaseRemoteSyncService: retry '
              '${retry.entityType}/${retry.entityId ?? retry.auditLogId} '
              'attempt=$nextAttempt in ${delay.inMilliseconds}ms',
            );
            await Future<void>.delayed(delay);
            _enqueueInternal(retry);
          } else {
            debugPrint(
              'SupabaseRemoteSyncService: retry limit reached '
              'for ${job.entityType}/${job.entityId ?? job.auditLogId}; '
              'will rely on pending audit recovery.',
            );
          }
        }
        if (_priorityQueue.isNotEmpty || _queue.isNotEmpty) {
          await Future<void>.delayed(_yieldBetweenJobs);
        }
      }
    } finally {
      _workerRunning = false;
      if (_priorityQueue.isNotEmpty || _queue.isNotEmpty) {
        unawaited(_pumpQueue());
      }
    }
  }

  @override
  Future<void> recoverPendingWork() async {
    if (_recovering || !supabaseAppEnabled) return;
    _recovering = true;
    try {
      // Compatibilidade: converte auditorias legadas sem item de fila.
      final audits =
          await (_db.select(_db.auditLogs)..orderBy([
                (t) => OrderingTerm.asc(t.at),
              ]))
              .get();
      for (final row in audits) {
        final entityId = row.entityId?.trim();
        if (entityId == null || entityId.isEmpty) continue;
        final existing =
            await (_db.select(_db.syncQueue)
                  ..where((q) => q.auditLogId.equals(row.id)))
                .getSingleOrNull();
        if (existing != null) continue;
        Map<String, Object?>? payload;
        final raw = row.payloadJson?.trim();
        if (raw != null && raw.isNotEmpty) {
          try {
            payload = Map<String, Object?>.from(
              jsonDecode(raw) as Map<dynamic, dynamic>,
            );
          } catch (_) {}
        }
        await enqueueAudit(
          auditLogId: row.id,
          action: row.action,
          entityType: row.entityType,
          entityId: entityId,
          payload: payload,
        );
      }

      final now = DateTime.now();
      final pending =
          await (_db.select(_db.syncQueue)..where(
                (q) =>
                    q.status.isIn(const ['pending', 'failed']) &
                    (q.nextRetryAt.isNull() | q.nextRetryAt.isSmallerThanValue(now)),
              )..orderBy([
                (q) => OrderingTerm.asc(q.priority),
                (q) => OrderingTerm.asc(q.updatedAt),
              ]))
              .get();
      for (final item in pending) {
        Map<String, Object?>? payload;
        final raw = item.payloadJson?.trim();
        if (raw != null && raw.isNotEmpty) {
          try {
            payload = Map<String, Object?>.from(
              jsonDecode(raw) as Map<dynamic, dynamic>,
            );
          } catch (_) {}
        }
        _enqueueInternal(
          _QueuedAudit(
            queueItemId: item.id,
            auditLogId: item.auditLogId ?? item.id,
            action: item.operation,
            entityType: item.entityType,
            entityId: item.entityId,
            payload: payload,
          ),
        );
      }
    } finally {
      _recovering = false;
    }
  }

  Future<bool> _syncOneJob(_QueuedAudit job) async {
    if (!supabaseAppEnabled) return true;

    final client = Supabase.instance.client;
    final queueItem = await (_db.select(
      _db.syncQueue,
    )..where((q) => q.id.equals(job.queueItemId))).getSingleOrNull();
    if (queueItem == null) return true;
    await (_db.update(_db.syncQueue)
          ..where((q) => q.id.equals(queueItem.id)))
        .write(
          SyncQueueCompanion(
            status: const Value('syncing'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _markLocalEntitySyncStatus(
      entityType: job.entityType,
      entityId: job.entityId,
      status: 'syncing',
    );
    final auditRow = await (_db.select(
      _db.auditLogs,
    )..where((a) => a.id.equals(job.auditLogId))).getSingleOrNull();

    // Blindagem contra "cancel" pendente antigo: só propaga cancel de treino
    // quando o estado local atual desse treino ainda estiver cancelado.
    if (job.entityType == 'day_workout' &&
        job.action == 'cancel' &&
        job.entityId != null) {
      final local = await (_db.select(
        _db.dayWorkouts,
      )..where((w) => w.id.equals(job.entityId!))).getSingleOrNull();
      if (local == null || local.status != 'cancelled') {
        debugPrint(
          'SupabaseRemoteSyncService: skip stale cancel '
          'entity=day_workout/${job.entityId} audit=${job.auditLogId} '
          '(local status=${local?.status ?? 'missing'})',
        );
        await _markQueueItemSynced(job.queueItemId);
        await _discardAuditLog(job.auditLogId);
        return true;
      }
    }

    _controller.beginUpload();
    try {
      if (job.entityType == 'day_workout_exercise' ||
          job.entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: start action=${job.action} '
          'entity=${job.entityType}/${job.entityId ?? '-'} '
          'audit=${job.auditLogId} attempt=${job.attempt}',
        );
      }
      const catalogReconcileTypes = {
        'muscle_group',
        'exercise',
        'workout_group',
        'workout_group_exercise',
      };
      if (catalogReconcileTypes.contains(job.entityType)) {
        // Reconciliação pesada só para entidades de catálogo com histórico de
        // conflito de unicidade. Eventos de treino/séries devem ir direto para
        // nuvem para reduzir latência entre dispositivos.
        await reconcileLocalCatalogWithCloud(_db, client);
      }
      try {
        if (auditRow != null) {
          await client.from('audit_logs').upsert(supabaseAuditLog(auditRow));
        }
      } catch (e, st) {
        debugPrint('SupabaseRemoteSyncService audit_logs (ignorado): $e\n$st');
      }

      await _mirrorAfterAudit(
        client,
        auditLogId: job.auditLogId,
        action: job.action,
        entityType: job.entityType,
        entityId: job.entityId,
        payload: job.payload,
      );
      // ACK do job: este audit já foi espelhado com sucesso.
      await _markQueueItemSynced(job.queueItemId);
      await _markLocalEntitySyncStatus(
        entityType: job.entityType,
        entityId: job.entityId,
        status: 'synced',
      );
      await _discardAuditLog(job.auditLogId);
      if (job.entityType == 'day_workout_exercise' ||
          job.entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: ok action=${job.action} '
          'entity=${job.entityType}/${job.entityId ?? '-'} '
          'audit=${job.auditLogId}',
        );
      }
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
      return true;
    } catch (e, st) {
      if (job.entityType == 'day_workout_exercise' ||
          job.entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: fail action=${job.action} '
          'entity=${job.entityType}/${job.entityId ?? '-'} '
          'audit=${job.auditLogId} error=$e',
        );
      }
      debugPrint('SupabaseRemoteSyncService: $e\n$st');
      _controller.noteDisconnected();
      _controller.noteBackgroundPushError(e);
      await _markQueueItemFailed(
        queueItemId: job.queueItemId,
        attempt: job.attempt + 1,
      );
      await _markLocalEntitySyncStatus(
        entityType: job.entityType,
        entityId: job.entityId,
        status: 'failed',
      );
      return false;
    } finally {
      _controller.endUpload();
    }
  }

  String _isoUpdatedAt(DateTime d) => d.toUtc().toIso8601String();

  Future<bool> _lwwUpdateById({
    required SupabaseClient client,
    required String table,
    required String id,
    required Map<String, dynamic> map,
    required DateTime localUpdatedAt,
  }) async {
    final localRevision = map['revision'];
    if (localRevision is num) {
      final rev = localRevision.toInt();
      final byLowerRevision = await client
          .from(table)
          .update(map)
          .eq('id', id)
          .lt('revision', rev)
          .select('id');
      final updatedByRevision = byLowerRevision as List<dynamic>;
      if (updatedByRevision.isNotEmpty) return true;

      final bySameRevisionOlderTs = await client
          .from(table)
          .update(map)
          .eq('id', id)
          .eq('revision', rev)
          .lt('updated_at', _isoUpdatedAt(localUpdatedAt))
          .select('id');
      final updatedByTimestamp = bySameRevisionOlderTs as List<dynamic>;
      if (updatedByTimestamp.isNotEmpty) return true;

      final byNullRevision = await client
          .from(table)
          .update(map)
          .eq('id', id)
          .isFilter('revision', null)
          .lt('updated_at', _isoUpdatedAt(localUpdatedAt))
          .select('id');
      final updatedByNullRevision = byNullRevision as List<dynamic>;
      return updatedByNullRevision.isNotEmpty;
    }

    // LWW fallback: só atualiza se a nuvem for mais antiga.
    final res = await client
        .from(table)
        .update(map)
        .eq('id', id)
        .lt('updated_at', _isoUpdatedAt(localUpdatedAt))
        .select('id');
    final list = res as List<dynamic>;
    return list.isNotEmpty;
  }

  Future<bool> _tryInsert({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> map,
  }) async {
    await client.from(table).insert(map);
    return true;
  }

  bool _looksLikeDuplicateKey(Object e) {
    final s = e.toString();
    return s.contains('23505') ||
        s.contains('duplicate key') ||
        s.contains('duplicate') ||
        s.contains('already exists');
  }

  Future<void> _discardAuditLog(String auditLogId) async {
    await (_db.delete(
      _db.auditLogs,
    )..where((a) => a.id.equals(auditLogId))).go();
  }

  Future<void> _markQueueItemSynced(String queueItemId) async {
    await (_db.update(
      _db.syncQueue,
    )..where((q) => q.id.equals(queueItemId))).write(
      SyncQueueCompanion(
        status: const Value('synced'),
        retryCount: const Value(0),
        nextRetryAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _markQueueItemFailed({
    required String queueItemId,
    required int attempt,
  }) async {
    final delay = _retryDelayForAttempt(attempt);
    await (_db.update(
      _db.syncQueue,
    )..where((q) => q.id.equals(queueItemId))).write(
      SyncQueueCompanion(
        status: const Value('failed'),
        retryCount: Value(attempt),
        nextRetryAt: Value(DateTime.now().add(delay)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _markLocalEntitySyncStatus({
    required String entityType,
    required String? entityId,
    required String status,
  }) async {
    final eid = entityId?.trim();
    if (eid == null || eid.isEmpty) return;
    if (entityType == 'day_workout') {
      await (_db.update(
        _db.dayWorkouts,
      )..where((w) => w.id.equals(eid))).write(
        DayWorkoutsCompanion(
          syncStatus: Value(status),
        ),
      );
      return;
    }
    if (entityType == 'day_workout_exercise') {
      await (_db.update(
        _db.dayWorkoutExercises,
      )..where((x) => x.id.equals(eid))).write(
        DayWorkoutExercisesCompanion(
          syncStatus: Value(status),
        ),
      );
    }
  }

  Future<void> _pullAfterConflict({
    required String entityType,
    required String entityId,
  }) async {
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    switch (entityType) {
      case 'student':
        await pull.pullStudentById(entityId);
      case 'personal':
        await pull.pullPersonalById(entityId);
      case 'muscle_group':
        await pull.pullMuscleGroupById(entityId);
      case 'exercise':
        await pull.pullExerciseById(entityId);
      case 'gym':
        await pull.pullGymById(entityId);
      case 'training_method':
        await pull.pullTrainingMethodById(entityId);
      case 'workout_group':
        await pull.pullWorkoutGroupById(entityId);
      case 'workout_group_exercise':
        await pull.pullWorkoutGroupExerciseById(entityId);
      case 'week_schedule_block':
      case 'week_schedule':
        await pull.pullWeekScheduleBlockById(entityId);
      case 'week_schedule_item':
        await pull.pullWeekScheduleItemById(entityId);
      case 'day_workout':
        await pull.pullDayWorkoutById(entityId);
      case 'day_workout_exercise':
        await pull.pullDayWorkoutExerciseById(entityId);
      default:
        await pull.pullAllFromRemote();
        break;
    }
  }

  Future<bool> _lwwUpsertOrConflictPull({
    required String auditLogId,
    required SupabaseClient client,
    required String table,
    required String entityTypeForPull,
    required String id,
    required Map<String, dynamic> map,
    required DateTime localUpdatedAt,
  }) async {
    final effectiveLocalUpdatedAt = localUpdatedAt;
    final ok = await _lwwUpdateById(
      client: client,
      table: table,
      id: id,
      map: map,
      localUpdatedAt: effectiveLocalUpdatedAt,
    );
    if (ok) return true;
    try {
      await _tryInsert(client: client, table: table, map: map);
      return true;
    } catch (e) {
      if (_looksLikeDuplicateKey(e)) {
        await _discardAuditLog(auditLogId);
        await _pullAfterConflict(entityType: entityTypeForPull, entityId: id);
        return false;
      }
      rethrow;
    }
  }

  static bool _isExerciseNormalizedNameConflict(Object e) {
    final s = e.toString();
    return s.contains('23505') &&
        s.contains('exercises_unique_normalized_name');
  }

  Future<({MuscleGroupEntity mg, ExerciseEntity ex})?> _bundledExerciseForPush(
    String exerciseId,
  ) async {
    final e = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.equals(exerciseId))).getSingleOrNull();
    if (e == null) return null;
    final m = await (_db.select(
      _db.muscleGroups,
    )..where((t) => t.id.equals(e.muscleGroupId))).getSingleOrNull();
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
    final ex = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.equals(exerciseId))).getSingleOrNull();
    if (ex == null) {
      debugPrint(
        'SupabaseRemoteSyncService: exercise id=$exerciseId ausente no SQLite; '
        'sem pré-sync para FK.',
      );
      return;
    }
    await _mirrorExerciseWithDependencies(client, ex);
  }

  Future<void> _replaceStudentGymsOnCloud(
    SupabaseClient client,
    String studentId,
  ) async {
    await client.from('student_gyms').delete().eq('student_id', studentId);
    final links = await (_db.select(
      _db.studentGyms,
    )..where((t) => t.studentId.equals(studentId))).get();
    for (var i = 0; i < links.length; i++) {
      final l = links[i];
      await client.from('student_gyms').insert({
        'student_id': l.studentId,
        'gym_id': l.gymId,
      });
      if (i % 4 == 3) await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> mirrorStudentRowNow(String studentId) async {
    if (!supabaseAppEnabled) return;
    final client = Supabase.instance.client;
    _controller.beginUpload();
    try {
      final row = await (_db.select(
        _db.students,
      )..where((t) => t.id.equals(studentId))).getSingleOrNull();
      if (row != null) {
        await _lwwUpsertOrConflictPull(
          auditLogId: '_direct_',
          client: client,
          table: 'students',
          entityTypeForPull: 'student',
          id: studentId,
          map: supabaseStudent(row),
          localUpdatedAt: row.updatedAt,
        );
      }
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
    } catch (e, st) {
      debugPrint('SupabaseRemoteSyncService mirrorStudentRowNow: $e\n$st');
      _controller.noteDisconnected();
      _controller.noteBackgroundPushError(e);
    } finally {
      _controller.endUpload();
    }
  }

  @override
  Future<void> mirrorPersonalRowNow(String personalId) async {
    if (!supabaseAppEnabled) return;
    final client = Supabase.instance.client;
    _controller.beginUpload();
    try {
      final row = await (_db.select(
        _db.personals,
      )..where((t) => t.id.equals(personalId))).getSingleOrNull();
      if (row != null) {
        await _lwwUpsertOrConflictPull(
          auditLogId: '_direct_',
          client: client,
          table: 'personals',
          entityTypeForPull: 'personal',
          id: personalId,
          map: supabasePersonal(row),
          localUpdatedAt: row.updatedAt,
        );
      }
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
    } catch (e, st) {
      debugPrint('SupabaseRemoteSyncService mirrorPersonalRowNow: $e\n$st');
      _controller.noteDisconnected();
      _controller.noteBackgroundPushError(e);
    } finally {
      _controller.endUpload();
    }
  }

  @override
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullDayWorkoutById(dayWorkoutId);
  }

  @override
  Future<void> refreshRecentCompletedHistoryForStudent(
    String studentId, {
    int limit = 40,
  }) async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullRecentCompletedDayWorkoutsForStudent(
      studentId,
      limit: limit,
    );
  }

  @override
  Future<void> refreshStudentWeekScheduleFromCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullWeekScheduleForStudentWeek(
      studentId,
      weekMonday: weekMonday,
    );
  }

  @override
  Future<void> refreshExercisesCatalogFromCloud() async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullExercisesCatalog();
  }

  @override
  Future<void> refreshExercisesByIdsFromCloud(
    Iterable<String> exerciseIds,
  ) async {
    if (!supabaseAppEnabled) return;
    final ids = exerciseIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    for (final id in ids) {
      await pull.pullExerciseById(id);
    }
  }

  Future<void> _mirrorAfterAudit(
    SupabaseClient client, {
    required String auditLogId,
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
          final row = await (_db.select(
            _db.muscleGroups,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'muscle_groups',
            entityTypeForPull: 'muscle_group',
            id: eid,
            map: supabaseMuscleGroup(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'exercise':
        if (isDelete) {
          await client.from('exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.exercises,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          // Garante a dependência (muscle_group) antes; ambos sob LWW.
          final mg = await (_db.select(
            _db.muscleGroups,
          )..where((t) => t.id.equals(row.muscleGroupId))).getSingleOrNull();
          if (mg != null) {
            await _lwwUpsertOrConflictPull(
              auditLogId: auditLogId,
              client: client,
              table: 'muscle_groups',
              entityTypeForPull: 'muscle_group',
              id: mg.id,
              map: supabaseMuscleGroup(mg),
              localUpdatedAt: mg.updatedAt,
            );
          }
          // Exercício em si
          try {
            await _lwwUpsertOrConflictPull(
              auditLogId: auditLogId,
              client: client,
              table: 'exercises',
              entityTypeForPull: 'exercise',
              id: eid,
              map: supabaseExercise(row),
              localUpdatedAt: row.updatedAt,
            );
          } catch (e) {
            // Mantém reconciliação de catálogo existente para conflitos 23505 por nome normalizado.
            if (_isExerciseNormalizedNameConflict(e)) {
              await reconcileLocalCatalogWithCloud(_db, client);
              // Releitura + tentativa novamente (best effort)
              final again = await (_db.select(
                _db.exercises,
              )..where((t) => t.id.equals(eid))).getSingleOrNull();
              if (again != null) {
                await _lwwUpsertOrConflictPull(
                  auditLogId: auditLogId,
                  client: client,
                  table: 'exercises',
                  entityTypeForPull: 'exercise',
                  id: eid,
                  map: supabaseExercise(again),
                  localUpdatedAt: again.updatedAt,
                );
              }
              return;
            }
            rethrow;
          }
        }
      case 'gym':
        if (isDelete) {
          await client.from('gyms').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.gyms,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'gyms',
            entityTypeForPull: 'gym',
            id: eid,
            map: supabaseGym(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'personal':
        if (isDelete) {
          await client.from('personals').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.personals,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'personals',
            entityTypeForPull: 'personal',
            id: eid,
            map: supabasePersonal(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'student':
        if (isDelete) {
          await client.from('students').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.students,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          final ok = await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'students',
            entityTypeForPull: 'student',
            id: eid,
            map: supabaseStudent(row),
            localUpdatedAt: row.updatedAt,
          );
          if (!ok) return;
          // Vínculos academias: apenas para create/update, e também sob LWW do próprio aluno.
          if (action == 'create' || action == 'update') {
            await _replaceStudentGymsOnCloud(client, eid);
          }
        }
      case 'training_method':
        if (isDelete) {
          await client.from('training_methods').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.trainingMethods,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'training_methods',
            entityTypeForPull: 'training_method',
            id: eid,
            map: supabaseTrainingMethod(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'workout_group':
        if (isDelete) {
          final row = await (_db.select(
            _db.workoutGroups,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row != null) {
            await _lwwUpsertOrConflictPull(
              auditLogId: auditLogId,
              client: client,
              table: 'workout_groups',
              entityTypeForPull: 'workout_group',
              id: eid,
              map: supabaseWorkoutGroup(row),
              localUpdatedAt: row.updatedAt,
            );
            await client
                .from('workout_group_exercises')
                .delete()
                .eq('workout_group_id', eid);
          } else {
            await client.from('workout_groups').delete().eq('id', eid);
          }
        } else {
          final row = await (_db.select(
            _db.workoutGroups,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row != null) {
            final ok = await _lwwUpsertOrConflictPull(
              auditLogId: auditLogId,
              client: client,
              table: 'workout_groups',
              entityTypeForPull: 'workout_group',
              id: eid,
              map: supabaseWorkoutGroup(row),
              localUpdatedAt: row.updatedAt,
            );
            if (!ok) return;
          }
          final lines = await (_db.select(
            _db.workoutGroupExercises,
          )..where((t) => t.workoutGroupId.equals(eid))).get();
          for (var i = 0; i < lines.length; i++) {
            final l = lines[i];
            await _ensureExerciseDependenciesMirrored(client, l.exerciseId);
            await _lwwUpsertOrConflictPull(
              auditLogId: auditLogId,
              client: client,
              table: 'workout_group_exercises',
              entityTypeForPull: 'workout_group_exercise',
              id: l.id,
              map: supabaseWorkoutGroupExercise(l),
              localUpdatedAt: l.updatedAt,
            );
            if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
          }
        }
      case 'workout_group_exercise':
        if (isDelete) {
          await client.from('workout_group_exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.workoutGroupExercises,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _ensureExerciseDependenciesMirrored(client, row.exerciseId);
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'workout_group_exercises',
            entityTypeForPull: 'workout_group_exercise',
            id: eid,
            map: supabaseWorkoutGroupExercise(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'week_schedule_block':
        if (isDelete) {
          await client.from('week_schedule_blocks').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.weekScheduleBlocks,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'week_schedule_blocks',
            entityTypeForPull: 'week_schedule_block',
            id: eid,
            map: supabaseWeekBlock(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'week_schedule':
        // Espelha bloco + itens sob LWW.
        await _mirrorWeekScheduleBlock(client, eid, auditLogId: auditLogId);
      case 'week_schedule_item':
        if (isDelete) {
          await client.from('week_schedule_items').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.weekScheduleItems,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          await _ensureExerciseDependenciesMirrored(client, row.exerciseId);
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'week_schedule_items',
            entityTypeForPull: 'week_schedule_item',
            id: eid,
            map: supabaseWeekItem(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      case 'day_workout':
        if (isDelete) {
          await client
              .from('day_workout_exercises')
              .delete()
              .eq('day_workout_id', eid);
          await client.from('day_workouts').delete().eq('id', eid);
        } else {
          await _mirrorDayWorkoutBundle(client, eid, auditLogId: auditLogId);
        }
      case 'day_workout_exercise':
        if (isDelete) {
          await client.from('day_workout_exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.dayWorkoutExercises,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          // Hot path de treino: não depender de reconcile de catálogo aqui.
          // Se a FK do exercício já existe na nuvem (cenário normal), o upsert da
          // linha deve seguir direto para reduzir latência e evitar falha em cascata
          // por chamadas adicionais (ex.: muscle_groups) durante instabilidade de rede.
          await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'day_workout_exercises',
            entityTypeForPull: 'day_workout_exercise',
            id: eid,
            map: supabaseDayWorkoutExercise(row),
            localUpdatedAt: row.updatedAt,
          );
        }
      default:
        break;
    }
  }

  Future<void> _mirrorWeekScheduleBlock(
    SupabaseClient client,
    String blockId, {
    String? auditLogId,
  }) async {
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;
    if (auditLogId != null) {
      final ok = await _lwwUpsertOrConflictPull(
        auditLogId: auditLogId,
        client: client,
        table: 'week_schedule_blocks',
        entityTypeForPull: 'week_schedule_block',
        id: blockId,
        map: supabaseWeekBlock(block),
        localUpdatedAt: block.updatedAt,
      );
      if (!ok) return;
    } else {
      await client
          .from('week_schedule_blocks')
          .upsert(supabaseWeekBlock(block));
    }
    final items = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.blockId.equals(blockId))).get();
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      await _ensureExerciseDependenciesMirrored(client, it.exerciseId);
      if (auditLogId != null) {
        await _lwwUpsertOrConflictPull(
          auditLogId: auditLogId,
          client: client,
          table: 'week_schedule_items',
          entityTypeForPull: 'week_schedule_item',
          id: it.id,
          map: supabaseWeekItem(it),
          localUpdatedAt: it.updatedAt,
        );
      } else {
        await client.from('week_schedule_items').upsert(supabaseWeekItem(it));
      }
      if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _mirrorDayWorkoutBundle(
    SupabaseClient client,
    String workoutId, {
    String? auditLogId,
  }) async {
    final w = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(workoutId))).getSingleOrNull();
    if (w == null) return;
    if (auditLogId != null) {
      final ok = await _lwwUpsertOrConflictPull(
        auditLogId: auditLogId,
        client: client,
        table: 'day_workouts',
        entityTypeForPull: 'day_workout',
        id: workoutId,
        map: supabaseDayWorkout(w),
        localUpdatedAt: w.updatedAt,
      );
      if (!ok) return;
    } else {
      await client.from('day_workouts').upsert(supabaseDayWorkout(w));
    }
    final lines = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.dayWorkoutId.equals(workoutId))).get();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Mesmo racional do hot path: evitar dependências de catálogo durante
      // sincronização de treino em execução.
      if (auditLogId != null) {
        await _lwwUpsertOrConflictPull(
          auditLogId: auditLogId,
          client: client,
          table: 'day_workout_exercises',
          entityTypeForPull: 'day_workout_exercise',
          id: line.id,
          map: supabaseDayWorkoutExercise(line),
          localUpdatedAt: line.updatedAt,
        );
      } else {
        await client
            .from('day_workout_exercises')
            .upsert(supabaseDayWorkoutExercise(line));
      }
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }
  }
}
