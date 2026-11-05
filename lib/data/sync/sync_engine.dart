import 'package:uuid/uuid.dart';

import 'supabase_sync_api.dart';
import 'sync_outbox_repository.dart';
import 'sync_state_repository.dart';

typedef SyncChangeApplier = Future<void> Function(Map<String, dynamic> change);

/// Orquestra o ciclo RPC sem conhecer telas ou regras de negócio.
class SyncEngine {
  SyncEngine({
    required this.api,
    required this.outbox,
    required this.state,
    required this.applyChange,
  });

  final SupabaseSyncApi api;
  final SyncOutboxRepository outbox;
  final SyncStateRepository state;
  final SyncChangeApplier applyChange;

  Future<void> runOnce() async {
    final current = await state.loadOrCreate();
    await api.registerDevice(deviceId: current.deviceId);

    final pending = await outbox.pending();
    if (pending.isNotEmpty) {
      final pushed = await api.push(
        deviceId: current.deviceId,
        operations: pending.map((op) => op.toRpcJson()).toList(growable: false),
      );
      if (pushed.gap) {
        throw StateError(
          'sync device sequence gap: expected ${pushed.expectedSeq}',
        );
      }
      for (final result in pushed.results) {
        final opId = result['op_id'] as String?;
        if (opId == null) continue;
        if (result['status'] == 'rejected') {
          await outbox.quarantine(opId, '${result['reason'] ?? 'rejected'}');
        } else {
          await outbox.acknowledge(opId);
        }
      }
    }

    var cursor = (await state.loadOrCreate()).serverCursor;
    var page = await api.pull(deviceId: current.deviceId, since: cursor);
    while (true) {
      if (page.reset) {
        await _applySnapshot();
        cursor = (await state.loadOrCreate()).serverCursor;
      } else {
        for (final change in page.changes) {
          final hlc = change['hlc'];
          if (hlc is String) await state.observeHlc(hlc);
          await applyChange(change);
        }
        await state.setServerCursor(page.nextCursor);
        cursor = page.nextCursor;
      }
      if (!page.hasMore) break;
      page = await api.pull(deviceId: current.deviceId, since: cursor);
    }
  }

  Future<void> _applySnapshot() async {
    Map<String, dynamic>? cursor;
    var lastSnapshotSeq = 0;
    do {
      final page = await api.snapshot(cursor: cursor);
      lastSnapshotSeq = page.snapshotSeq;
      for (final item in page.items) {
        await applyChange(item);
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    await state.setServerCursor(lastSnapshotSeq);
  }

  static String newOperationId() => const Uuid().v4();
}
