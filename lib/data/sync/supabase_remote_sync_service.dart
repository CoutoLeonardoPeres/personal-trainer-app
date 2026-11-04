import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';
import 'conflict_resolver.dart';
import 'performed_set_sync_service.dart';
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
    if (entityType == 'day_workout_exercise') {
      if (action == 'append_set' ||
          action == 'remove_set' ||
          action == 'update_set' ||
          action == 'patch_set_rest') {
        // Prioridade máxima: registro de série em treino ao vivo.
        return -2;
      }
      return -1;
    }
    if (entityType == 'day_workout') {
      if (action == 'start' ||
          action == 'pause' ||
          action == 'resume' ||
          action == 'complete') {
        // Estado de treino em tempo real deve chegar antes de programações/cancelamentos.
        return -1;
      }
      return 0;
    }
    if (_isHighPriorityAudit(entityType: entityType, action: action)) {
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
    if (entityType == 'workout_group' ||
        entityType == 'workout_group_exercise') {
      if (action == 'delete') return '$entityType::$entityId::delete';
      return '$entityType::$entityId::model';
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
      final existing = await (_db.select(
        _db.syncQueue,
      )..where((t) => t.dedupeKey.equals(nonNullDedupeKey))).getSingleOrNull();
      if (existing != null && existing.status != 'syncing') {
        if (entityType == 'day_workout_exercise' ||
            entityType == 'day_workout') {
          debugPrint(
            'SupabaseRemoteSyncService: queue upsert reuse '
            'id=${existing.id} dedupe=$nonNullDedupeKey '
            'status=${existing.status} action=$action '
            'entity=$entityType/$entityId',
          );
        }
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
        // Para eventos coalescíveis, não criar novo item enquanto já há envio ativo.
        // Isso evita tempestade de fila (ex.: centenas de "resync_local"/"touch")
        // que atrasava a propagação em tempo real entre dispositivos.
        if (action == 'resync_local' || action == 'touch') {
          if (entityType == 'day_workout_exercise' ||
              entityType == 'day_workout') {
            debugPrint(
              'SupabaseRemoteSyncService: queue coalesce while syncing '
              'existing=${existing.id} dedupe=$nonNullDedupeKey '
              'action=$action entity=$entityType/$entityId',
            );
          }
          return existing.id;
        }
        if (entityType == 'day_workout_exercise' ||
            entityType == 'day_workout') {
          debugPrint(
            'SupabaseRemoteSyncService: queue upsert while syncing '
            'existing=${existing.id} dedupe=$nonNullDedupeKey '
            'action=$action entity=$entityType/$entityId',
          );
        }
        // Evita violação de unicidade quando a mesma entidade recebe novo evento
        // durante um envio em progresso.
        dedupeKey = null;
      }
    }
    final id = const Uuid().v4();
    try {
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: id,
              entityType: entityType,
              entityId: entityId,
              operation: action,
              payloadJson: Value(encodedPayload),
              priority: Value(
                _priorityFor(entityType: entityType, action: action),
              ),
              status: const Value('pending'),
              retryCount: const Value(0),
              nextRetryAt: const Value(null),
              dedupeKey: Value(dedupeKey),
              auditLogId: Value(auditLogId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      if (entityType == 'day_workout_exercise' || entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: queue insert id=$id '
          'dedupe=${dedupeKey ?? '-'} action=$action '
          'entity=$entityType/$entityId',
        );
      }
    } catch (e) {
      // Corrida entre produtores concorrentes para a mesma dedupe_key:
      // em vez de falhar o enqueue (e perder sync), reaproveita o item existente.
      final isDedupeConflict =
          dedupeKey != null &&
          e.toString().contains(
            'UNIQUE constraint failed: sync_queue.dedupe_key',
          );
      if (!isDedupeConflict) rethrow;
      final existing = await (_db.select(
        _db.syncQueue,
      )..where((t) => t.dedupeKey.equals(dedupeKey!))).getSingleOrNull();
      if (existing == null) rethrow;
      if (entityType == 'day_workout_exercise' || entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: queue dedupe conflict recovered '
          'existing=${existing.id} dedupe=$dedupeKey '
          'action=$action entity=$entityType/$entityId',
        );
      }
      if (existing.status != 'syncing') {
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
      }
      return existing.id;
    }
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
    if (entityType == 'day_workout_exercise' || entityType == 'day_workout') {
      debugPrint(
        'SupabaseRemoteSyncService: enqueue action=$action '
        'entity=$entityType/$safeEntityId queueItem=$queueItemId audit=$auditLogId',
      );
    }
    _enqueueInternal(q);
  }

  void _enqueueInternal(_QueuedAudit q) {
    if (!_queuedItemIds.add(q.queueItemId)) {
      // Mesmo queueItemId já enfileirado: substitui pelo evento mais recente
      // e reposiciona para não perder "último write" (ex.: 1ª série some, 2ª fica).
      _priorityQueue.removeWhere((x) => x.queueItemId == q.queueItemId);
      _queue.removeWhere((x) => x.queueItemId == q.queueItemId);
      if (_isHighPriorityAudit(entityType: q.entityType, action: q.action)) {
        _priorityQueue.insert(0, q);
      } else {
        _queue.add(q);
      }
      if (q.entityType == 'day_workout_exercise' ||
          q.entityType == 'day_workout') {
        debugPrint(
          'SupabaseRemoteSyncService: enqueue replace '
          'queueItem=${q.queueItemId} action=${q.action} '
          'entity=${q.entityType}/${q.entityId ?? '-'} '
          'sizes(priority=${_priorityQueue.length},normal=${_queue.length})',
        );
      }
      return;
    }
    if (_isHighPriorityAudit(entityType: q.entityType, action: q.action)) {
      // Fluxo crítico (treino/séries): item mais recente deve sair primeiro,
      // evitando ficar atrás de backlog antigo após recover.
      _priorityQueue.insert(0, q);
    } else {
      _queue.add(q);
    }
    if (q.entityType == 'day_workout_exercise' ||
        q.entityType == 'day_workout') {
      debugPrint(
        'SupabaseRemoteSyncService: enqueue push '
        'queueItem=${q.queueItemId} action=${q.action} '
        'entity=${q.entityType}/${q.entityId ?? '-'} '
        'sizes(priority=${_priorityQueue.length},normal=${_queue.length})',
      );
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
            // Não bloquear a fila por causa de 1 item com falha:
            // agenda retry assíncrono e segue processando os demais jobs.
            unawaited(
              Future<void>.delayed(delay).then((_) {
                _enqueueInternal(retry);
              }),
            );
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
      final now = DateTime.now();
      final staleAuditCutoff = now.subtract(const Duration(hours: 24));
      final audits = await (_db.select(
        _db.auditLogs,
      )..orderBy([(t) => OrderingTerm.asc(t.at)])).get();
      for (final row in audits) {
        final existing = await (_db.select(
          _db.syncQueue,
        )..where((q) => q.auditLogId.equals(row.id))).getSingleOrNull();
        if (row.at.isBefore(staleAuditCutoff) && existing == null) {
          // Evita reprocessar backlog histórico importado da nuvem em todo boot,
          // o que atrasava eventos críticos atuais de séries/treino ao vivo.
          await _discardAuditLog(row.id);
          continue;
        }
        final entityId = row.entityId?.trim();
        if (entityId == null || entityId.isEmpty) continue;
        if (row.entityType == 'day_workout_exercise' &&
            await _isOrphanDayWorkoutExerciseEntity(entityId)) {
          await _discardAuditLog(row.id);
          continue;
        }
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

      final nowForPending = DateTime.now();
      final pending =
          await (_db.select(_db.syncQueue)
                ..where(
                  (q) =>
                      q.status.isIn(const ['pending', 'failed']) &
                      (q.nextRetryAt.isNull() |
                          q.nextRetryAt.isSmallerThanValue(nowForPending)),
                )
                ..orderBy([
                  (q) => OrderingTerm.asc(q.priority),
                  (q) => OrderingTerm.desc(q.updatedAt),
                ]))
              .get();
      // Mantém a ordenação efetiva "mais novo primeiro" mesmo usando
      // _enqueueInternal() com inserção no início da fila prioritária.
      for (final item in pending.reversed) {
        if (item.entityType == 'day_workout_exercise' &&
            await _isOrphanDayWorkoutExerciseEntity(item.entityId)) {
          await (_db.delete(
            _db.syncQueue,
          )..where((q) => q.id.equals(item.id))).go();
          final aid = item.auditLogId?.trim();
          if (aid != null && aid.isNotEmpty) {
            await _discardAuditLog(aid);
          }
          continue;
        }
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

  Future<bool> _isOrphanDayWorkoutExerciseEntity(String? entityId) async {
    final id = entityId?.trim();
    if (id == null || id.isEmpty) return true;
    final line = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (line == null) return true;
    final parent = await (_db.select(
      _db.dayWorkouts,
    )..where((w) => w.id.equals(line.dayWorkoutId))).getSingleOrNull();
    return parent == null;
  }

  Future<bool> _syncOneJob(_QueuedAudit job) async {
    if (!supabaseAppEnabled) return true;

    final client = Supabase.instance.client;
    final queueItem = await (_db.select(
      _db.syncQueue,
    )..where((q) => q.id.equals(job.queueItemId))).getSingleOrNull();
    if (queueItem == null) return true;
    await (_db.update(
      _db.syncQueue,
    )..where((q) => q.id.equals(queueItem.id))).write(
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
      if (job.entityType == 'day_workout_exercise' &&
          _isDayWorkoutParentFkError(e)) {
        final recovered = await _recoverDayWorkoutParentFkAndRetry(
          client: client,
          job: job,
        );
        if (recovered) {
          await _markQueueItemSynced(job.queueItemId);
          await _markLocalEntitySyncStatus(
            entityType: job.entityType,
            entityId: job.entityId,
            status: 'synced',
          );
          await _discardAuditLog(job.auditLogId);
          _controller.noteConnected();
          _controller.noteBackgroundPushSuccess();
          debugPrint(
            'SupabaseRemoteSyncService: recovered FK and synced '
            'entity=${job.entityType}/${job.entityId ?? '-'} '
            'audit=${job.auditLogId}',
          );
          return true;
        }
      }
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

  Future<bool> _recoverDayWorkoutParentFkAndRetry({
    required SupabaseClient client,
    required _QueuedAudit job,
  }) async {
    final lineId = job.entityId?.trim();
    if (lineId == null || lineId.isEmpty) return false;
    final line = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (line == null) {
      // Auditoria órfã/antiga não deve bloquear a fila crítica.
      return true;
    }
    final parentReady = await _ensureParentDayWorkoutMirrored(
      client,
      line.dayWorkoutId,
      auditLogId: job.auditLogId,
    );
    if (!parentReady) return false;
    try {
      await _mirrorAfterAudit(
        client,
        auditLogId: job.auditLogId,
        action: job.action,
        entityType: job.entityType,
        entityId: job.entityId,
        payload: job.payload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is String) return DateTime.parse(v);
    return DateTime.parse(v.toString());
  }

  int _parseIntOpt(Map<String, dynamic> row, String key, int fallback) {
    final v = row[key];
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  bool _localWinsConflictByVersion({
    required int localRevision,
    required int remoteRevision,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required String? localDeviceId,
    required String? remoteDeviceId,
  }) {
    if (localRevision != remoteRevision) {
      return ConflictResolver.localMayPush(
        localRevision: localRevision,
        serverRevision: remoteRevision,
      );
    }
    return false;
  }

  Future<void> _syncLocalRevisionFromServer({
    required String table,
    required String id,
    required SupabaseClient client,
  }) async {
    try {
      final res = await client
          .from(table)
          .select('revision')
          .eq('id', id)
          .maybeSingle();
      if (res == null) return;
      final rev = _parseIntOpt(
        Map<String, dynamic>.from(res as Map),
        'revision',
        0,
      );
      if (table == 'day_workouts') {
        await (_db.update(
          _db.dayWorkouts,
        )..where((w) => w.id.equals(id))).write(
          DayWorkoutsCompanion(
            revision: Value(rev),
            syncStatus: const Value('synced'),
          ),
        );
      } else if (table == 'day_workout_exercises') {
        await (_db.update(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(id))).write(
          DayWorkoutExercisesCompanion(
            revision: Value(rev),
            syncStatus: const Value('synced'),
          ),
        );
      } else if (table == 'workout_groups') {
        await (_db.update(_db.workoutGroups)..where((g) => g.id.equals(id)))
            .write(WorkoutGroupsCompanion(revision: Value(rev)));
      }
    } catch (_) {}
  }

  Future<bool> _pushPendingPerformedSetEvents(
    SupabaseClient client,
    String lineId,
  ) async {
    final pending = await (_db.select(
      _db.performedSetEvents,
    )..where((e) => e.lineId.equals(lineId) & e.synced.equals(false))).get();
    var ok = true;
    for (final ev in pending) {
      final pushed = await PerformedSetSyncService.pushEvent(client, ev);
      if (pushed) {
        await (_db.update(_db.performedSetEvents)
              ..where((e) => e.id.equals(ev.id)))
            .write(const PerformedSetEventsCompanion(synced: Value(true)));
      } else {
        ok = false;
      }
    }
    return ok;
  }

  Future<bool> _optimisticUpdateByRevision({
    required SupabaseClient client,
    required String table,
    required String id,
    required Map<String, dynamic> map,
    required int expectedRevision,
  }) async {
    Future<bool> runWithMap(Map<String, dynamic> data) async {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('revision');
      final res = await client
          .from(table)
          .update(payload)
          .eq('id', id)
          .eq('revision', expectedRevision)
          .select('id, revision');
      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        await _syncLocalRevisionFromServer(
          table: table,
          id: id,
          client: client,
        );
        return true;
      }
      return false;
    }

    try {
      return await runWithMap(map);
    } catch (e) {
      if (_isMissingSchemaColumn(e)) {
        final compat = _compatMapWithoutNewSyncColumns(map);
        if (compat.length != map.length) {
          return runWithMap(compat);
        }
      }
      rethrow;
    }
  }

  Future<bool> _lwwUpdateById({
    required SupabaseClient client,
    required String table,
    required String id,
    required Map<String, dynamic> map,
    required DateTime localUpdatedAt,
  }) async {
    // Tabelas legadas (incluindo planejamento semanal) ainda não possuem
    // `revision` no SQLite. Filtrar revision=0 fazia toda atualização após o
    // primeiro insert falhar e deixava itens presos em apenas um dispositivo.
    if (!map.containsKey('revision')) {
      final payload = Map<String, dynamic>.from(map);
      final res = await client
          .from(table)
          .update(payload)
          .eq('id', id)
          .lte('updated_at', supabaseTs(localUpdatedAt))
          .select('id');
      return (res as List<dynamic>).isNotEmpty;
    }
    final expectedRevision = _parseIntOpt(map, 'revision', 0);
    return _optimisticUpdateByRevision(
      client: client,
      table: table,
      id: id,
      map: map,
      expectedRevision: expectedRevision,
    );
  }

  Future<bool> _tryInsert({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> map,
  }) async {
    try {
      await client.from(table).insert(map);
      return true;
    } catch (e) {
      if (_isMissingSchemaColumn(e)) {
        final compat = _compatMapWithoutNewSyncColumns(map);
        if (compat.length != map.length) {
          await client.from(table).insert(compat);
          return true;
        }
      }
      rethrow;
    }
  }

  bool _looksLikeDuplicateKey(Object e) {
    final s = e.toString();
    return s.contains('23505') ||
        s.contains('duplicate key') ||
        s.contains('duplicate') ||
        s.contains('already exists');
  }

  bool _isMissingSchemaColumn(Object e) {
    final s = e.toString();
    final lower = s.toLowerCase();
    final isPgrstMissing =
        s.contains('PGRST204') && s.contains('Could not find the');
    final isPgMissing =
        (s.contains('42703') || lower.contains('undefined column')) &&
        lower.contains('column') &&
        lower.contains('does not exist');
    return isPgrstMissing || isPgMissing;
  }

  bool _isDayWorkoutParentFkError(Object e) {
    final s = e.toString();
    return s.contains('23503') &&
        s.contains('day_workout_exercises_day_workout_id_fkey');
  }

  Map<String, dynamic> _compatMapWithoutNewSyncColumns(
    Map<String, dynamic> map,
  ) {
    final out = Map<String, dynamic>.from(map);
    out.remove('revision');
    out.remove('last_modified_by_device_id');
    out.remove('sync_status');
    out.remove('deleted_at');
    return out;
  }

  int _maxLoggedAtMs(List<DayWorkoutPerformedSet> sets) {
    var max = 0;
    for (final s in sets) {
      final v = s.loggedAtMs ?? 0;
      if (v > max) max = v;
    }
    return max;
  }

  bool _localPerformedSetsAheadOfRemote({
    required List<DayWorkoutPerformedSet> local,
    required List<DayWorkoutPerformedSet> remote,
  }) {
    if (local.length != remote.length) {
      return local.length > remote.length;
    }
    if (local.isEmpty) return false;
    return _maxLoggedAtMs(local) > _maxLoggedAtMs(remote);
  }

  DateTime? _dateTimeFromMapValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return DateTime.tryParse(value.toString());
  }

  int _intFromMapValue(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  String? _stringFromMapValue(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<bool> _forceUpdateById({
    required SupabaseClient client,
    required String table,
    required String id,
    required Map<String, dynamic> map,
  }) async {
    Future<bool> runWithMap(Map<String, dynamic> data) async {
      final res = await client
          .from(table)
          .update(data)
          .eq('id', id)
          .select('id');
      final rows = res as List<dynamic>;
      return rows.isNotEmpty;
    }

    try {
      return await runWithMap(map);
    } catch (e) {
      if (_isMissingSchemaColumn(e)) {
        final compat = _compatMapWithoutNewSyncColumns(map);
        if (compat.length != map.length) {
          return runWithMap(compat);
        }
      }
      rethrow;
    }
  }

  Future<bool> _shouldForceCriticalConflictResolution({
    required SupabaseClient client,
    required String table,
    required String id,
    required Map<String, dynamic> map,
    required DateTime localUpdatedAt,
  }) async {
    if (table != 'day_workouts' && table != 'day_workout_exercises') {
      return false;
    }

    List<dynamic> rows;
    try {
      if (table == 'day_workout_exercises') {
        rows = await client
            .from(table)
            .select(
              'id,updated_at,revision,last_modified_by_device_id,performed_sets_json',
            )
            .eq('id', id)
            .limit(1);
      } else {
        rows = await client
            .from(table)
            .select(
              'id,updated_at,revision,last_modified_by_device_id,status,completed_at',
            )
            .eq('id', id)
            .limit(1);
      }
    } catch (e) {
      if (_isMissingSchemaColumn(e)) {
        rows = await client
            .from(table)
            .select('id,updated_at')
            .eq('id', id)
            .limit(1);
      } else {
        rethrow;
      }
    }
    if (rows.isEmpty) return false;

    final remote = Map<String, dynamic>.from(rows.first as Map);
    final remoteUpdatedAt =
        _dateTimeFromMapValue(remote['updated_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final remoteRevision = _intFromMapValue(remote['revision']);
    final remoteDeviceId = _stringFromMapValue(
      remote['last_modified_by_device_id'],
    );
    final localRevision = _intFromMapValue(map['revision']);
    final localDeviceId = _stringFromMapValue(
      map['last_modified_by_device_id'],
    );

    var localWins = _localWinsConflictByVersion(
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      localDeviceId: localDeviceId,
      remoteDeviceId: remoteDeviceId,
    );

    if (!localWins && table == 'day_workout_exercises') {
      final localSets = DayWorkoutPerformedSetCodec.decode(
        _stringFromMapValue(map['performed_sets_json']),
      );
      final remoteSets = DayWorkoutPerformedSetCodec.decode(
        _stringFromMapValue(remote['performed_sets_json']),
      );
      localWins = _localPerformedSetsAheadOfRemote(
        local: localSets,
        remote: remoteSets,
      );
      if (!localWins &&
          localSets.isNotEmpty &&
          localSets.length == remoteSets.length &&
          DayWorkoutPerformedSetCodec.encode(localSets) ==
              DayWorkoutPerformedSetCodec.encode(remoteSets)) {
        // Mesmas séries: permitir push de score/metadata corrigidos (ex.: escala ÷10).
        localWins = true;
      }
    }

    if (!localWins && table == 'day_workouts') {
      final localStatus =
          _stringFromMapValue(map['status'])?.toLowerCase() ?? '';
      final remoteStatus =
          _stringFromMapValue(remote['status'])?.toLowerCase() ?? '';
      if (localStatus == 'completed' && remoteStatus != 'completed') {
        final localCompleted =
            _dateTimeFromMapValue(map['completed_at']) ?? localUpdatedAt;
        final remoteCompleted = _dateTimeFromMapValue(remote['completed_at']);
        localWins =
            remoteCompleted == null ||
            localCompleted.isAfter(remoteCompleted) ||
            localUpdatedAt.isAfter(
              remoteUpdatedAt.subtract(const Duration(seconds: 2)),
            );
      }
    }

    if (!localWins) return false;
    final forced = await _forceUpdateById(
      client: client,
      table: table,
      id: id,
      map: map,
    );
    if (forced) {
      debugPrint(
        'SupabaseRemoteSyncService: forced critical conflict resolution '
        'table=$table id=$id local_updated=${localUpdatedAt.toIso8601String()} '
        'remote_updated=${remoteUpdatedAt.toIso8601String()} '
        'local_rev=$localRevision remote_rev=$remoteRevision',
      );
    }
    return forced;
  }

  /// Após conflito LWW em série ao vivo: re-lê local/nuvem e força push se o local
  /// ainda tiver progresso (ou as mesmas séries com metadata corrigida).
  Future<bool> _recoverHotPathLinePushAfterLwwConflict({
    required SupabaseClient client,
    required String lineId,
  }) async {
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((t) => t.id.equals(lineId))).getSingleOrNull();
    if (row == null) return true;

    List<dynamic> remoteRows;
    try {
      remoteRows = await client
          .from('day_workout_exercises')
          .select('performed_sets_json')
          .eq('id', lineId)
          .limit(1);
    } catch (_) {
      return false;
    }
    final map = supabaseDayWorkoutExercise(row);
    if (remoteRows.isEmpty) {
      try {
        await _tryInsert(
          client: client,
          table: 'day_workout_exercises',
          map: map,
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    final remote = Map<String, dynamic>.from(remoteRows.first as Map);
    final localSets = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    final remoteSets = DayWorkoutPerformedSetCodec.decode(
      _stringFromMapValue(remote['performed_sets_json']),
    );
    final localAhead = _localPerformedSetsAheadOfRemote(
      local: localSets,
      remote: remoteSets,
    );
    final sameSets =
        localSets.isNotEmpty &&
        localSets.length == remoteSets.length &&
        DayWorkoutPerformedSetCodec.encode(localSets) ==
            DayWorkoutPerformedSetCodec.encode(remoteSets);
    if (!localAhead && !sameSets) return false;

    return _forceUpdateById(
      client: client,
      table: 'day_workout_exercises',
      id: lineId,
      map: map,
    );
  }

  Future<bool> _recoverProgrammedLinePushAfterLwwConflict({
    required SupabaseClient client,
    required DayWorkoutExerciseEntity line,
  }) async {
    final workout = await (_db.select(
      _db.dayWorkouts,
    )..where((w) => w.id.equals(line.dayWorkoutId))).getSingleOrNull();
    if (workout == null) return true;
    if (workout.status == 'started' || workout.status == 'completed') {
      return false;
    }
    if ((workout.sourceWorkoutGroupId ?? '').trim().isEmpty) return false;
    final performed = DayWorkoutPerformedSetCodec.decode(
      line.performedSetsJson,
    );
    if (performed.isNotEmpty) return false;
    await _mirrorDayWorkoutBundle(
      client,
      workout.id,
      deleteStaleRemoteLines: true,
    );
    return true;
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
      await (_db.update(_db.dayWorkouts)..where((w) => w.id.equals(eid))).write(
        DayWorkoutsCompanion(syncStatus: Value(status)),
      );
      return;
    }
    if (entityType == 'day_workout_exercise') {
      await (_db.update(_db.dayWorkoutExercises)
            ..where((x) => x.id.equals(eid)))
          .write(DayWorkoutExercisesCompanion(syncStatus: Value(status)));
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
    final forcedCritical = await _shouldForceCriticalConflictResolution(
      client: client,
      table: table,
      id: id,
      map: map,
      localUpdatedAt: effectiveLocalUpdatedAt,
    );
    if (forcedCritical) return true;
    try {
      await _tryInsert(client: client, table: table, map: map);
      return true;
    } catch (e) {
      if (_looksLikeDuplicateKey(e)) {
        final forcedAfterDuplicate =
            await _shouldForceCriticalConflictResolution(
              client: client,
              table: table,
              id: id,
              map: map,
              localUpdatedAt: effectiveLocalUpdatedAt,
            );
        if (forcedAfterDuplicate) return true;
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
  Future<void> repairMissingStudentWeekScheduleItemsOnCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {
    if (!supabaseAppEnabled) return;
    final client = Supabase.instance.client;
    final monday = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);

    bool sameMonday(DateTime value) {
      final local = value.toLocal();
      return local.year == monday.year &&
          local.month == monday.month &&
          local.day == monday.day;
    }

    final localBlocks = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.studentId.equals(studentId))).get();
    final weekBlocks = localBlocks
        .where((b) => sameMonday(b.weekStartMonday))
        .toList(growable: false);
    if (weekBlocks.isEmpty) return;

    _controller.beginUpload();
    try {
      for (final block in weekBlocks) {
        final remoteBlock = await client
            .from('week_schedule_blocks')
            .select('id')
            .eq('id', block.id)
            .maybeSingle();
        if (remoteBlock == null) {
          try {
            await client
                .from('week_schedule_blocks')
                .insert(supabaseWeekBlock(block));
          } catch (e) {
            if (!_looksLikeDuplicateKey(e)) rethrow;
          }
        }

        final localItems = await (_db.select(
          _db.weekScheduleItems,
        )..where((i) => i.blockId.equals(block.id))).get();
        if (localItems.isEmpty) continue;

        final remoteRows = await client
            .from('week_schedule_items')
            .select('id')
            .eq('block_id', block.id);
        final remoteIds = (remoteRows as List<dynamic>)
            .map((row) => (row as Map)['id']?.toString())
            .whereType<String>()
            .toSet();

        for (final item in localItems) {
          if (remoteIds.contains(item.id)) continue;
          await _ensureExerciseDependenciesMirrored(client, item.exerciseId);
          try {
            await client
                .from('week_schedule_items')
                .insert(supabaseWeekItem(item));
          } catch (e) {
            if (!_looksLikeDuplicateKey(e)) rethrow;
          }
        }
      }
      _controller.noteConnected();
      _controller.noteBackgroundPushSuccess();
    } catch (e, st) {
      debugPrint(
        'SupabaseRemoteSyncService '
        'repairMissingStudentWeekScheduleItemsOnCloud: $e\n$st',
      );
      _controller.noteDisconnected();
      _controller.noteBackgroundPushError(e);
      rethrow;
    } finally {
      _controller.endUpload();
    }
  }

  @override
  Future<void> refreshExercisesCatalogFromCloud() async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullExercisesCatalog();
  }

  @override
  Future<void> refreshWorkoutGroupsCatalogFromCloud() async {
    if (!supabaseAppEnabled) return;
    final pull = SupabasePullSyncService(_db, _controller, session: null);
    await pull.pullWorkoutGroupsCatalog();
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
          // Remove na nuvem linhas que foram apagadas localmente (evita “ressuscitar”
          // exercícios em outros dispositivos quando o delete individual falhou na fila).
          try {
            final keepIds = lines.map((l) => l.id).toSet();
            final remoteLines = await client
                .from('workout_group_exercises')
                .select('id')
                .eq('workout_group_id', eid);
            for (final raw in remoteLines as List<dynamic>) {
              final rid = (raw as Map)['id'] as String?;
              if (rid == null || keepIds.contains(rid)) continue;
              await client
                  .from('workout_group_exercises')
                  .delete()
                  .eq('id', rid);
            }
          } catch (e, st) {
            debugPrint(
              'SupabaseRemoteSyncService prune workout_group_exercises '
              'group=$eid: $e\n$st',
            );
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
          if (action == 'touch' || action == 'resync_local') {
            await _mirrorDayWorkoutTouch(client, eid, auditLogId: auditLogId);
          } else {
            await _mirrorDayWorkoutBundle(
              client,
              eid,
              auditLogId: auditLogId,
              deleteStaleRemoteLines: action == 'replace_group_template',
            );
          }
        }
      case 'day_workout_exercise':
        if (isDelete) {
          await client.from('day_workout_exercises').delete().eq('id', eid);
        } else {
          final row = await (_db.select(
            _db.dayWorkoutExercises,
          )..where((t) => t.id.equals(eid))).getSingleOrNull();
          if (row == null) return;
          // Garantia de causalidade: a linha depende do treino pai no Supabase.
          // Em cenários com backlog/out-of-order, o push da linha podia chegar
          // antes do day_workout e falhar por FK (23503), quebrando sincronismo
          // tablet <-> iPhone. Forçamos upsert do pai primeiro.
          await _ensureParentDayWorkoutMirrored(
            client,
            row.dayWorkoutId,
            auditLogId: auditLogId,
          );
          if (action == 'append_set' ||
              action == 'update_set' ||
              action == 'patch_set_rest') {
            await _pushPendingPerformedSetEvents(client, eid);
          }
          final pushed = await _lwwUpsertOrConflictPull(
            auditLogId: auditLogId,
            client: client,
            table: 'day_workout_exercises',
            entityTypeForPull: 'day_workout_exercise',
            id: eid,
            map: supabaseDayWorkoutExercise(row),
            localUpdatedAt: row.updatedAt,
          );
          if (!pushed &&
              (action == 'append_set' ||
                  action == 'remove_set' ||
                  action == 'update_set' ||
                  action == 'patch_set_rest')) {
            final recovered = await _recoverHotPathLinePushAfterLwwConflict(
              client: client,
              lineId: eid,
            );
            if (recovered) return;
          }
          if (!pushed) {
            final recovered = await _recoverProgrammedLinePushAfterLwwConflict(
              client: client,
              line: row,
            );
            if (recovered) return;
          }
          if (!pushed) {
            throw StateError(
              'day_workout_exercise push not acknowledged by LWW '
              '(kept pending for retry) id=$eid',
            );
          }
        }
      default:
        break;
    }
  }

  Future<bool> _ensureParentDayWorkoutMirrored(
    SupabaseClient client,
    String workoutId, {
    String? auditLogId,
  }) async {
    final parent = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(workoutId))).getSingleOrNull();
    if (parent == null) return false;
    if (auditLogId != null) {
      final pushed = await _lwwUpsertOrConflictPull(
        auditLogId: auditLogId,
        client: client,
        table: 'day_workouts',
        entityTypeForPull: 'day_workout',
        id: workoutId,
        map: supabaseDayWorkout(parent),
        localUpdatedAt: parent.updatedAt,
      );
      if (pushed) return true;
      // Conflito/LWW sem update também pode significar que o pai já existe na nuvem.
      // Para a FK da linha, basta garantir existência.
      try {
        final probe = await client
            .from('day_workouts')
            .select('id')
            .eq('id', workoutId)
            .limit(1);
        final rows = probe as List<dynamic>;
        if (rows.isNotEmpty) return true;
      } catch (_) {}
      return false;
    }
    await client.from('day_workouts').upsert(supabaseDayWorkout(parent));
    return true;
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
      // Um conflito no metadado do bloco-pai não deve impedir o envio de
      // filhos com IDs próprios. O pai remoto já existe nesse cenário e os
      // itens abaixo convergem individualmente.
      if (!ok) {
        debugPrint(
          'SupabaseRemoteSyncService: bloco semanal $blockId manteve versão '
          'remota; continuando sincronização aditiva dos itens.',
        );
      }
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
    bool deleteStaleRemoteLines = false,
  }) async {
    final w = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(workoutId))).getSingleOrNull();
    if (w == null) return;

    // Guard rail de convergência multi-dispositivo:
    // se a nuvem já está "completed" e este snapshot local está em estado anterior,
    // não permitir downgrade remoto para started/programmed/cancelled por push atrasado.
    if (w.status != 'completed') {
      try {
        final probe = await client
            .from('day_workouts')
            .select(
              'id,status,updated_at,revision,last_modified_by_device_id,completed_at',
            )
            .eq('id', workoutId)
            .limit(1);
        final rows = probe as List<dynamic>;
        if (rows.isNotEmpty) {
          final rr = Map<String, dynamic>.from(rows.first as Map);
          final remoteStatus = (rr['status'] as String?)?.trim().toLowerCase();
          if (remoteStatus == 'completed') {
            final remoteUpdatedAt = rr['updated_at'] == null
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : _parseTs(rr['updated_at']);
            final remoteRevision = _parseIntOpt(rr, 'revision', 0);
            final remoteDeviceId = (rr['last_modified_by_device_id'] as String?)
                ?.trim();
            final localWins = _localWinsConflictByVersion(
              localRevision: w.revision,
              remoteRevision: remoteRevision,
              localUpdatedAt: w.updatedAt,
              remoteUpdatedAt: remoteUpdatedAt,
              localDeviceId: w.lastModifiedByDeviceId,
              remoteDeviceId: remoteDeviceId,
            );
            if (!localWins) {
              debugPrint(
                'SupabaseRemoteSyncService: skip stale day_workout push '
                'id=$workoutId localStatus=${w.status} remoteStatus=completed '
                'localRev=${w.revision} remoteRev=$remoteRevision',
              );
              await _pullAfterConflict(
                entityType: 'day_workout',
                entityId: workoutId,
              );
              return;
            }
          }
        }
      } catch (_) {
        // Best effort: se falhar o probe, segue fluxo normal LWW.
      }
    }

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
    final replaceRemoteTemplateLines =
        deleteStaleRemoteLines &&
        w.status != 'started' &&
        w.status != 'completed';
    if (deleteStaleRemoteLines &&
        w.status != 'started' &&
        w.status != 'completed') {
      final keepIds = lines.map((line) => line.id).toSet();
      final remoteLines = await client
          .from('day_workout_exercises')
          .select('id')
          .eq('day_workout_id', workoutId);
      for (final raw in remoteLines as List<dynamic>) {
        final id = (raw as Map)['id'] as String?;
        if (id == null || keepIds.contains(id)) continue;
        await client.from('day_workout_exercises').delete().eq('id', id);
      }
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Mesmo racional do hot path: evitar dependências de catálogo durante
      // sincronização de treino em execução.
      if (replaceRemoteTemplateLines) {
        await client
            .from('day_workout_exercises')
            .upsert(supabaseDayWorkoutExercise(line));
      } else if (auditLogId != null) {
        final pushed = await _lwwUpsertOrConflictPull(
          auditLogId: auditLogId,
          client: client,
          table: 'day_workout_exercises',
          entityTypeForPull: 'day_workout_exercise',
          id: line.id,
          map: supabaseDayWorkoutExercise(line),
          localUpdatedAt: line.updatedAt,
        );
        if (!pushed) {
          throw StateError(
            'day_workout_exercises bundle push not acknowledged by LWW '
            '(kept pending for retry) id=${line.id}',
          );
        }
      } else {
        await client
            .from('day_workout_exercises')
            .upsert(supabaseDayWorkoutExercise(line));
      }
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _mirrorDayWorkoutTouch(
    SupabaseClient client,
    String workoutId, {
    String? auditLogId,
  }) async {
    final w = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(workoutId))).getSingleOrNull();
    if (w == null) return;
    if (auditLogId != null) {
      await _lwwUpsertOrConflictPull(
        auditLogId: auditLogId,
        client: client,
        table: 'day_workouts',
        entityTypeForPull: 'day_workout',
        id: workoutId,
        map: supabaseDayWorkout(w),
        localUpdatedAt: w.updatedAt,
      );
      return;
    }
    await client.from('day_workouts').upsert(supabaseDayWorkout(w));
  }
}
