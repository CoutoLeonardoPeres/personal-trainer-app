import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import 'sync_state_repository.dart';

class SyncOperation {
  const SyncOperation({
    required this.opId,
    required this.deviceSeq,
    required this.entity,
    required this.entityId,
    required this.opType,
    required this.hlc,
    required this.payload,
  });

  final String opId;
  final int deviceSeq;
  final String entity;
  final String entityId;
  final String opType;
  final String hlc;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toRpcJson() => {
    'op_id': opId,
    'device_seq': deviceSeq,
    'entity': entity,
    'entity_id': entityId,
    'op_type': opType,
    'hlc': hlc,
    'payload': payload,
  };
}

/// Outbox compatível com o `sync_push`, preservando a fila antiga durante a migração.
class SyncOutboxRepository {
  SyncOutboxRepository(this._db, this._state);

  final AppDatabase _db;
  final SyncStateRepository _state;

  Future<SyncOperation> enqueue({
    required String entity,
    required String entityId,
    required String opType,
    required Map<String, dynamic> payload,
    bool coalescible = true,
  }) async {
    return _db.transaction(() async {
      if (coalescible) {
        final existing =
            await (_db.select(_db.syncQueue)
                  ..where(
                    (row) =>
                        row.entityType.equals(entity) &
                        row.entityId.equals(entityId) &
                        row.operation.equals(opType) &
                        row.status.equals('pending'),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing?.opId != null &&
            existing?.deviceSeq != null &&
            existing?.hlc != null) {
          return SyncOperation(
            opId: existing!.opId!,
            deviceSeq: existing.deviceSeq!,
            entity: entity,
            entityId: entityId,
            opType: opType,
            hlc: existing.hlc!,
            payload: _decodePayload(existing.payloadJson),
          );
        }

        // Filas criadas pela fila anterior podem ter a mesma chave de
        // deduplicacao, mas ainda nao possuir os metadados do RPC. Promover
        // essa linha evita uma colisao no indice UNIQUE e preserva a ordem
        // original da fila durante a migracao.
        if (existing != null) {
          final opId = const Uuid().v4();
          final reserved = await _state.reserveOperation(opId: opId);
          await (_db.update(
            _db.syncQueue,
          )..where((row) => row.id.equals(existing.id))).write(
            SyncQueueCompanion(
              opId: Value(opId),
              deviceSeq: Value(reserved.deviceSeq),
              hlc: Value(reserved.hlc),
              payloadJson: Value(jsonEncode(payload)),
              status: const Value('pending'),
              errorCode: const Value(null),
              quarantinedAt: const Value(null),
              updatedAt: Value(DateTime.now()),
            ),
          );
          return SyncOperation(
            opId: opId,
            deviceSeq: reserved.deviceSeq,
            entity: entity,
            entityId: entityId,
            opType: opType,
            hlc: reserved.hlc,
            payload: payload,
          );
        }
      }

      final opId = const Uuid().v4();
      final reserved = await _state.reserveOperation(opId: opId);
      final operation = SyncOperation(
        opId: opId,
        deviceSeq: reserved.deviceSeq,
        entity: entity,
        entityId: entityId,
        opType: opType,
        hlc: reserved.hlc,
        payload: payload,
      );
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: opId,
              opId: Value(opId),
              deviceSeq: Value(reserved.deviceSeq),
              hlc: Value(reserved.hlc),
              entityType: entity,
              entityId: entityId,
              operation: opType,
              payloadJson: Value(jsonEncode(payload)),
              status: const Value('pending'),
              dedupeKey: coalescible
                  ? Value('$entity:$entityId:$opType')
                  : const Value(null),
              updatedAt: Value(DateTime.now()),
              createdAt: Value(DateTime.now()),
            ),
          );
      return operation;
    });
  }

  Future<List<SyncOperation>> pending({int limit = 100}) async {
    final rows =
        await (_db.select(_db.syncQueue)
              ..where((row) => row.status.equals('pending'))
              ..orderBy([
                (row) => OrderingTerm.asc(row.deviceSeq),
                (row) => OrderingTerm.asc(row.createdAt),
              ])
              ..limit(limit))
            .get();
    return rows
        .where(
          (row) => row.opId != null && row.deviceSeq != null && row.hlc != null,
        )
        .map(
          (row) => SyncOperation(
            opId: row.opId!,
            deviceSeq: row.deviceSeq!,
            entity: row.entityType,
            entityId: row.entityId,
            opType: row.operation,
            hlc: row.hlc!,
            payload: _decodePayload(row.payloadJson),
          ),
        )
        .toList(growable: false);
  }

  Future<void> acknowledge(String opId) async {
    await (_db.update(
      _db.syncQueue,
    )..where((row) => row.opId.equals(opId))).write(
      SyncQueueCompanion(
        status: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> quarantine(String opId, String reason) async {
    await (_db.update(
      _db.syncQueue,
    )..where((row) => row.opId.equals(opId))).write(
      SyncQueueCompanion(
        status: const Value('quarantined'),
        errorCode: Value(reason),
        quarantinedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static Map<String, dynamic> _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }
}
