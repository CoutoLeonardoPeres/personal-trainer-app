import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/app_database.dart';

class WorkoutEventDao {
  WorkoutEventDao(this._db);

  final AppDatabase _db;

  Future<void> insertLocalSetEvent(Map<String, dynamic> payload) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO day_workout_set_events_local '
      '(event_id, day_workout_id, day_workout_exercise_id, student_id, reps, load_kg, '
      'logged_at_ms, created_by_user_id, created_by_role, created_at_ms, sync_status) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        payload['event_id'],
        payload['day_workout_id'],
        payload['day_workout_exercise_id'],
        payload['student_id'] ?? '',
        payload['reps'] ?? 0,
        payload['load_kg'],
        payload['logged_at_ms'] ?? 0,
        payload['created_by_user_id']?.toString(),
        payload['created_by_role'] ?? 'personal',
        payload['created_at_ms'] ?? DateTime.now().millisecondsSinceEpoch,
        payload['sync_status'] ?? 'pending',
      ],
    );
  }

  Future<void> insertLocalRestEvent(Map<String, dynamic> payload) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO day_workout_set_rest_events_local '
      '(rest_event_id, set_event_id, day_workout_id, day_workout_exercise_id, '
      'rest_prescribed_sec, rest_countdown_elapsed_ms, post_rest_modal_ms, '
      'recorded_at_ms, recorded_by_user_id, recorded_by_role, created_at_ms, sync_status) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        payload['rest_event_id'],
        payload['set_event_id'],
        payload['day_workout_id'],
        payload['day_workout_exercise_id'],
        payload['rest_prescribed_sec'],
        payload['rest_countdown_elapsed_ms'],
        payload['post_rest_modal_ms'],
        payload['recorded_at_ms'] ?? 0,
        payload['recorded_by_user_id']?.toString(),
        payload['recorded_by_role'] ?? 'personal',
        payload['created_at_ms'] ?? DateTime.now().millisecondsSinceEpoch,
        payload['sync_status'] ?? 'pending',
      ],
    );
  }

  Future<void> insertLocalTombstone(Map<String, dynamic> payload) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO day_workout_set_event_tombstones_local '
      '(tombstone_id, event_id, day_workout_id, day_workout_exercise_id, '
      'deleted_at_ms, deleted_by_user_id, deleted_by_role, created_at_ms, sync_status) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        payload['tombstone_id'],
        payload['event_id'],
        payload['day_workout_id'],
        payload['day_workout_exercise_id'],
        payload['deleted_at_ms'] ?? 0,
        payload['deleted_by_user_id']?.toString(),
        payload['deleted_by_role'] ?? 'personal',
        payload['created_at_ms'] ?? DateTime.now().millisecondsSinceEpoch,
        payload['sync_status'] ?? 'pending',
      ],
    );
  }

  Future<List<QueryRow>> getDueOutbox({int limit = 20}) {
    return _db.customSelect(
      'SELECT * FROM sync_outbox '
      "WHERE status IN ('pending','failed') "
      'AND (next_retry_at_ms IS NULL OR next_retry_at_ms <= ?) '
      'ORDER BY created_at_ms ASC LIMIT ?',
      variables: <Variable<Object>>[
        Variable<int>(DateTime.now().millisecondsSinceEpoch),
        Variable<int>(limit),
      ],
    ).get();
  }

  Future<void> enqueueOutbox({
    required String entityId,
    required String op,
    required String dayWorkoutId,
    required String lineId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT OR REPLACE INTO sync_outbox '
      '(entity_id, op, day_workout_id, day_workout_exercise_id, payload_json, status, attempts, next_retry_at_ms, last_error, created_at_ms, updated_at_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at_ms FROM sync_outbox WHERE entity_id = ?), ?), ?)',
      <Object?>[
        entityId,
        op,
        dayWorkoutId,
        lineId,
        jsonEncode(payload),
        'pending',
        0,
        null,
        null,
        entityId,
        now,
        now,
      ],
    );
  }

  Future<void> markOutboxAcked(String entityId) async {
    await _db.customStatement(
      "UPDATE sync_outbox SET status = 'acked', attempts = 0, next_retry_at_ms = NULL, last_error = NULL, updated_at_ms = ? WHERE entity_id = ?",
      <Object?>[DateTime.now().millisecondsSinceEpoch, entityId],
    );
  }

  Future<void> markOutboxFailed({
    required String entityId,
    required int attempts,
    required int nextRetryAtMs,
    required String error,
  }) async {
    await _db.customStatement(
      "UPDATE sync_outbox SET status = 'failed', attempts = ?, next_retry_at_ms = ?, last_error = ?, updated_at_ms = ? WHERE entity_id = ?",
      <Object?>[
        attempts,
        nextRetryAtMs,
        error,
        DateTime.now().millisecondsSinceEpoch,
        entityId,
      ],
    );
  }
}
