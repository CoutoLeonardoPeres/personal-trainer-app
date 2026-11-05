import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../../core/sync/sync_device_identity.dart';
import 'hlc.dart';

/// Reserva sequência, HLC e cursor dentro do mesmo banco local.
class SyncStateRepository {
  SyncStateRepository(this._db);

  final AppDatabase _db;
  static const _stateId = 'default';

  Future<SyncStateEntity> loadOrCreate() async {
    final current = await (_db.select(
      _db.syncStates,
    )..where((row) => row.id.equals(_stateId))).getSingleOrNull();
    if (current != null) return current;
    final deviceId = await SyncDeviceIdentity.getOrCreate();
    await _db
        .into(_db.syncStates)
        .insert(SyncStatesCompanion.insert(id: _stateId, deviceId: deviceId));
    return (_db.select(
      _db.syncStates,
    )..where((row) => row.id.equals(_stateId))).getSingle();
  }

  Future<String> nextHlc() async {
    return _db.transaction(() async {
      final state = await loadOrCreate();
      final clock = HybridLogicalClock(
        deviceId: state.deviceId,
        wallMs: state.hlcWallMs,
        logical: state.hlcLogical,
      );
      final hlc = clock.tick();
      await _updateState(hlcWallMs: clock.wallMs, hlcLogical: clock.logical);
      return hlc;
    });
  }

  Future<({String opId, int deviceSeq, String hlc})> reserveOperation({
    required String opId,
  }) async {
    return _db.transaction(() async {
      final state = await loadOrCreate();
      final clock = HybridLogicalClock(
        deviceId: state.deviceId,
        wallMs: state.hlcWallMs,
        logical: state.hlcLogical,
      );
      final hlc = clock.tick();
      await _updateState(
        nextDeviceSeq: state.nextDeviceSeq + 1,
        hlcWallMs: clock.wallMs,
        hlcLogical: clock.logical,
      );
      return (opId: opId, deviceSeq: state.nextDeviceSeq, hlc: hlc);
    });
  }

  Future<void> observeHlc(String remoteHlc) async {
    await _db.transaction(() async {
      final state = await loadOrCreate();
      final clock = HybridLogicalClock(
        deviceId: state.deviceId,
        wallMs: state.hlcWallMs,
        logical: state.hlcLogical,
      )..observe(remoteHlc);
      await _updateState(hlcWallMs: clock.wallMs, hlcLogical: clock.logical);
    });
  }

  Future<void> setServerCursor(int cursor) async {
    await _db.transaction(() async {
      final current = await loadOrCreate();
      if (cursor <= current.serverCursor) return;
      await _updateState(serverCursor: cursor);
    });
  }

  Future<void> _updateState({
    int? nextDeviceSeq,
    int? serverCursor,
    int? hlcWallMs,
    int? hlcLogical,
  }) async {
    await (_db.update(
      _db.syncStates,
    )..where((row) => row.id.equals(_stateId))).write(
      SyncStatesCompanion(
        nextDeviceSeq: nextDeviceSeq == null
            ? const Value.absent()
            : Value(nextDeviceSeq),
        serverCursor: serverCursor == null
            ? const Value.absent()
            : Value(serverCursor),
        hlcWallMs: hlcWallMs == null ? const Value.absent() : Value(hlcWallMs),
        hlcLogical: hlcLogical == null
            ? const Value.absent()
            : Value(hlcLogical),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
