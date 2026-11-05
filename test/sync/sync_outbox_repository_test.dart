import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_personal/data/local/app_database.dart';
import 'package:app_personal/data/sync/sync_outbox_repository.dart';
import 'package:app_personal/data/sync/sync_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('promove fila legada sem duplicar a chave de deduplicacao', () async {
    await db.into(db.syncStates).insert(
      SyncStatesCompanion.insert(
        id: 'default',
        deviceId: '12345678-1234-1234-1234-123456789abc',
      ),
    );
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: 'legacy-row',
            entityType: 'day_workouts',
            entityId: 'workout-1',
            operation: 'update',
            payloadJson: const Value('{"status":"started"}'),
            dedupeKey: const Value('day_workouts:workout-1:update'),
          ),
        );

    final repository = SyncOutboxRepository(db, SyncStateRepository(db));
    final operation = await repository.enqueue(
      entity: 'day_workouts',
      entityId: 'workout-1',
      opType: 'update',
      payload: const {'status': 'completed'},
    );

    final rows = await db.select(db.syncQueue).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'legacy-row');
    expect(rows.single.opId, operation.opId);
    expect(rows.single.deviceSeq, operation.deviceSeq);
    expect(jsonDecode(rows.single.payloadJson!), {'status': 'completed'});
  });
}
