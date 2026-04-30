import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_auth_service.dart';
import '../supabase/supabase_bootstrap.dart';
import '../../data/local/app_database.dart';

class WorkoutSyncService extends ChangeNotifier {
  WorkoutSyncService(this._db);

  final AppDatabase _db;
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  bool _running = false;
  bool _syncing = false;
  String? _attachedWorkoutId;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _authSub = SupabaseAuthService.onAuthStateChange.listen((evt) {
      final authEvent = evt.event;
      if (authEvent == AuthChangeEvent.signedOut) {
        unawaited(stop(activeOnly: true));
        return;
      }
      if (authEvent == AuthChangeEvent.signedIn ||
          authEvent == AuthChangeEvent.tokenRefreshed) {
        _ensureTimer();
        unawaited(drainOutbox());
      }
    });
    if (SupabaseAuthService.currentSession == null) return;
    _ensureTimer();
    await drainOutbox();
  }

  Future<void> stop({bool activeOnly = false}) async {
    _timer?.cancel();
    _timer = null;
    if (!activeOnly) {
      await _authSub?.cancel();
      _authSub = null;
      _running = false;
    }
  }

  void attachWorkout(String dayWorkoutId) {
    _attachedWorkoutId = dayWorkoutId;
    _ensureTimer();
  }

  void detachWorkout() {
    _attachedWorkoutId = null;
    _ensureTimer();
  }

  void _ensureTimer() {
    _timer?.cancel();
    final hasAttached = _attachedWorkoutId != null;
    final interval = hasAttached
        ? const Duration(seconds: 3)
        : const Duration(seconds: 8);
    _timer = Timer.periodic(interval, (_) => unawaited(drainOutbox()));
  }

  Future<void> drainOutbox() async {
    if (_syncing) return;
    if (!supabaseAppEnabled || SupabaseAuthService.currentSession == null) {
      return;
    }
    final due = await _db.customSelect(
      'SELECT entity_id, op, payload_json, attempts '
      'FROM sync_outbox '
      "WHERE status IN ('pending','failed') "
      'AND (next_retry_at_ms IS NULL OR next_retry_at_ms <= ?) '
      'ORDER BY created_at_ms ASC LIMIT 20',
      variables: <Variable<Object>>[
        Variable<int>(DateTime.now().millisecondsSinceEpoch),
      ],
    ).get();
    if (due.isEmpty) return;
    _syncing = true;
    try {
      final client = Supabase.instance.client;
      for (final row in due) {
        final entityId = row.read<String>('entity_id');
        final op = row.read<String>('op');
        final payloadRaw = row.read<String>('payload_json');
        final attempts = row.read<int>('attempts');
        try {
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
          if (op == 'upsert_set_event') {
            await client.from('day_workout_set_events').upsert(
              payload,
              onConflict: 'event_id',
            );
          } else if (op == 'upsert_rest_event') {
            await client.from('day_workout_set_rest_events').upsert(
              payload,
              onConflict: 'rest_event_id',
            );
          } else if (op == 'insert_set_tombstone') {
            await client.from('day_workout_set_event_tombstones').upsert(
              payload,
              onConflict: 'tombstone_id',
            );
          }
          await _db.customStatement(
            "UPDATE sync_outbox SET status = 'acked', attempts = 0, "
            'next_retry_at_ms = NULL, last_error = NULL, updated_at_ms = ? '
            'WHERE entity_id = ?',
            <Object?>[
              DateTime.now().millisecondsSinceEpoch,
              entityId,
            ],
          );
        } catch (e) {
          final nextAttempts = attempts + 1;
          final backoffSec = min(120, (1 << min(nextAttempts, 6)));
          final jitterMs = Random().nextInt(1200);
          final nextRetry =
              DateTime.now().millisecondsSinceEpoch +
              (backoffSec * 1000) +
              jitterMs;
          await _db.customStatement(
            "UPDATE sync_outbox SET status = 'failed', attempts = ?, "
            'next_retry_at_ms = ?, last_error = ?, updated_at_ms = ? '
            'WHERE entity_id = ?',
            <Object?>[
              nextAttempts,
              nextRetry,
              e.toString(),
              DateTime.now().millisecondsSinceEpoch,
              entityId,
            ],
          );
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
