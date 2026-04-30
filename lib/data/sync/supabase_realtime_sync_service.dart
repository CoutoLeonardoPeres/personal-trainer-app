import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import '../models/day_workout_performed_set_composer.dart';
import '../models/day_workout_performed_set.dart';
import 'supabase_pull_sync_service.dart';

enum WorkoutActivityKind { started, exerciseLogged, completed }

class WorkoutActivityEvent {
  const WorkoutActivityEvent({
    required this.kind,
    required this.dayWorkoutId,
    this.studentId,
    required this.at,
  });

  final WorkoutActivityKind kind;
  final String dayWorkoutId;
  final String? studentId;
  final DateTime at;
}

/// Escuta alterações remotas em treinos e aplica pull pontual no SQLite local.
///
/// Isso mantém personal/admin atualizados quando o aluno conclui/preenche treino
/// em outro dispositivo sem depender apenas de "resume" do app.
class SupabaseRealtimeSyncService {
  SupabaseRealtimeSyncService({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    this.onWorkoutActivity,
  }) : _db = db,
       _sync = sync,
       _session = session;

  final AppDatabase _db;
  final SupabaseSyncController _sync;
  final AppSession _session;
  final Future<void> Function(WorkoutActivityEvent event)? onWorkoutActivity;

  RealtimeChannel? _dayWorkoutsChannel;
  RealtimeChannel? _dayWorkoutExercisesChannel;
  Timer? _flushTimer;
  Timer? _startedWorkoutPollTimer;
  Timer? _eventsPollTimer;
  DateTime? _lastRemoteRecentProbeAt;
  bool _started = false;
  bool _disposed = false;
  bool _flushing = false;

  final Set<String> _pendingDayWorkoutIds = <String>{};
  final Set<String> _pendingLineIds = <String>{};
  final Map<String, DateTime> _lastActivityAtByKey = <String, DateTime>{};
  final Map<String, int> _lastSetCursorByWorkout = <String, int>{};
  final Map<String, int> _lastRestCursorByWorkout = <String, int>{};
  final Map<String, int> _lastTombCursorByWorkout = <String, int>{};

  Future<void> start() async {
    if (_disposed || !supabaseAppEnabled) return;
    if (_started) return;
    _started = true;

    final c = Supabase.instance.client;
    final nonce = DateTime.now().microsecondsSinceEpoch;

    _dayWorkoutsChannel = c
        .channel('pg:day_workouts:$nonce')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'day_workouts',
          callback: (payload) => _onDayWorkoutPayload(payload),
        )
        .subscribe();

    _dayWorkoutExercisesChannel = c
        .channel('pg:day_workout_exercises:$nonce')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'day_workout_exercises',
          callback: (payload) => _onDayWorkoutExercisePayload(payload),
        )
        .subscribe();

    _startedWorkoutPollTimer?.cancel();
    // Fallback de convergência: se um evento realtime falhar/perder,
    // treinos locais em execução ainda serão reconciliados por pull pontual.
    _startedWorkoutPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_enqueueStartedWorkoutFallbackPulls()),
    );
    _eventsPollTimer?.cancel();
    _eventsPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_pollWorkoutEvents()),
    );
  }

  /// Volta a subscrever após pausa/rede (mantém o mesmo serviço; não altera [_disposed]).
  Future<void> reconnectAfterResume() async {
    if (_disposed || !supabaseAppEnabled) return;
    await _detachRealtimeChannels();
    await start();
  }

  Future<void> _detachRealtimeChannels() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _startedWorkoutPollTimer?.cancel();
    _startedWorkoutPollTimer = null;
    _eventsPollTimer?.cancel();
    _eventsPollTimer = null;
    _started = false;

    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    final w = _dayWorkoutsChannel;
    final l = _dayWorkoutExercisesChannel;
    _dayWorkoutsChannel = null;
    _dayWorkoutExercisesChannel = null;

    if (w != null) {
      await c.removeChannel(w);
    }
    if (l != null) {
      await c.removeChannel(l);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _pendingDayWorkoutIds.clear();
    _pendingLineIds.clear();
    await _detachRealtimeChannels();
  }

  Future<void> _enqueueStartedWorkoutFallbackPulls() async {
    if (_disposed || !supabaseAppEnabled) return;
    try {
      final started = await (_db.select(
        _db.dayWorkouts,
      )..where((w) => w.status.equals('started'))).get();
      for (final w in started) {
        _pendingDayWorkoutIds.add(w.id);
      }
      // Convergência adicional: busca remota de treinos recentes com limitação
      // para não competir com commits locais de séries (evita travas de SQLite).
      final now = DateTime.now();
      final hasStartedLocal = started.isNotEmpty;
      final lastProbe = _lastRemoteRecentProbeAt;
      // Se o realtime falhar/intermitir em um dispositivo, o fallback precisa
      // convergir rápido também quando este app ainda não marcou treino started
      // localmente (caso clássico: treino iniciado no outro dispositivo).
      final minGap = hasStartedLocal
          ? const Duration(seconds: 6)
          : const Duration(seconds: 6);
      final shouldProbeRemote =
          lastProbe == null || now.difference(lastProbe) >= minGap;
      if (shouldProbeRemote && !_flushing) {
        _lastRemoteRecentProbeAt = now;
        final cutoff = now
            .subtract(
              hasStartedLocal
                  ? const Duration(hours: 36)
                  : const Duration(hours: 24),
            )
            .toIso8601String();
        final remoteRows = await Supabase.instance.client
            .from('day_workouts')
            .select('id,status,updated_at')
            .inFilter('status', const ['programmed', 'started', 'completed'])
            .gte('updated_at', cutoff)
            .order('updated_at', ascending: false)
            .limit(hasStartedLocal ? 50 : 40);
        final list = remoteRows as List<dynamic>;
        for (final raw in list) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'] as String?;
          if (id == null || id.isEmpty) continue;
          _pendingDayWorkoutIds.add(id);
        }
      }
      if (_pendingDayWorkoutIds.isEmpty) return;
      _scheduleFlush();
    } catch (_) {
      // best effort
    }
  }

  void _onDayWorkoutPayload(PostgresChangePayload payload) {
    final id = _idFromPayload(payload);
    if (id == null || id.isEmpty) return;
    _pendingDayWorkoutIds.add(id);
    unawaited(_emitWorkoutActivityFromDayPayload(payload, id));
    _scheduleFlush();
  }

  void _onDayWorkoutExercisePayload(PostgresChangePayload payload) {
    final dayWorkoutId = _dayWorkoutIdFromPayload(payload);
    final id = _idFromPayload(payload);
    if (dayWorkoutId != null && dayWorkoutId.isNotEmpty) {
      // Fallback crítico de consistência: além do pull da linha pontual,
      // enfileira também o treino completo. Isso evita estado parcial
      // (só primeiros exercícios/séries) quando algum evento de linha
      // se perde ou chega fora de ordem entre dispositivos.
      _pendingDayWorkoutIds.add(dayWorkoutId);
      if (id != null && id.isNotEmpty) {
        _pendingLineIds.add(id);
      }
      unawaited(
        _emitWorkoutActivityFromLinePayload(
          payload,
          dayWorkoutId: dayWorkoutId,
        ),
      );
      _scheduleFlush();
      return;
    }
    if (id == null || id.isEmpty) return;
    _pendingLineIds.add(id);
    _scheduleFlush();
  }

  String? _idFromPayload(PostgresChangePayload payload) {
    final next = payload.newRecord;
    if (next.containsKey('id')) {
      final id = next['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    final old = payload.oldRecord;
    final id = old['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  String? _dayWorkoutIdFromPayload(PostgresChangePayload payload) {
    final next = payload.newRecord;
    if (next.containsKey('day_workout_id')) {
      final id = next['day_workout_id'];
      if (id is String && id.isNotEmpty) return id;
    }
    final old = payload.oldRecord;
    final id = old['day_workout_id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool _allowActivityEmit(
    String key, {
    Duration minGap = const Duration(seconds: 2),
  }) {
    final now = DateTime.now();
    final last = _lastActivityAtByKey[key];
    if (last != null && now.difference(last) < minGap) return false;
    _lastActivityAtByKey[key] = now;
    return true;
  }

  Future<void> _emitWorkoutActivityFromDayPayload(
    PostgresChangePayload payload,
    String dayWorkoutId,
  ) async {
    final cb = onWorkoutActivity;
    if (cb == null) return;
    final next = payload.newRecord;
    final prev = payload.oldRecord;
    final nextStatus = (next['status'] as String?)?.trim().toLowerCase();
    final prevStatus = (prev['status'] as String?)?.trim().toLowerCase();
    if (nextStatus == null || nextStatus.isEmpty) return;
    WorkoutActivityKind? kind;
    if (nextStatus == 'started' && prevStatus != 'started') {
      kind = WorkoutActivityKind.started;
    } else if (nextStatus == 'completed' && prevStatus != 'completed') {
      kind = WorkoutActivityKind.completed;
    }
    if (kind == null) return;
    final key = '$dayWorkoutId:${kind.name}';
    if (!_allowActivityEmit(key)) return;
    final sid = next['student_id'] as String?;
    await cb(
      WorkoutActivityEvent(
        kind: kind,
        dayWorkoutId: dayWorkoutId,
        studentId: sid,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> _emitWorkoutActivityFromLinePayload(
    PostgresChangePayload payload, {
    required String dayWorkoutId,
  }) async {
    final cb = onWorkoutActivity;
    if (cb == null) return;
    final next = payload.newRecord;
    final prev = payload.oldRecord;
    final nextSets = (next['performed_sets_json'] as String?) ?? '';
    final prevSets = (prev['performed_sets_json'] as String?) ?? '';
    if (nextSets.trim().isEmpty) return;
    if (nextSets == prevSets) return;
    final key = '$dayWorkoutId:exercise_logged';
    if (!_allowActivityEmit(key, minGap: const Duration(seconds: 1))) return;
    await cb(
      WorkoutActivityEvent(
        kind: WorkoutActivityKind.exerciseLogged,
        dayWorkoutId: dayWorkoutId,
        studentId: null,
        at: DateTime.now(),
      ),
    );
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    // Debounce maior: em iPhone/rede móvel chegam rajadas de eventos Postgres;
    // puxar o treino cedo demais repete snapshots ainda sem o push local.
    _flushTimer = Timer(const Duration(milliseconds: 550), () {
      _flushTimer = null;
      unawaited(_flushPendingPulls());
    });
  }

  Future<void> _flushPendingPulls() async {
    if (_flushing || _disposed || !supabaseAppEnabled) return;
    if (_pendingDayWorkoutIds.isEmpty && _pendingLineIds.isEmpty) {
      return;
    }

    _flushing = true;
    try {
      final dayIds = _pendingDayWorkoutIds.toList(growable: false);
      final lineIds = _pendingLineIds.toList(growable: false);
      _pendingDayWorkoutIds.clear();
      _pendingLineIds.clear();

      final pull = SupabasePullSyncService(_db, _sync, session: _session);
      for (final id in dayIds) {
        await pull.pullDayWorkoutById(id);
      }
      // Se já puxamos o treino completo, evitar pull pontual redundante das linhas
      // neste mesmo ciclo (reduz corrida/stale com snapshots intermediários).
      if (dayIds.isEmpty) {
        for (final id in lineIds) {
          await pull.pullDayWorkoutExerciseById(id);
        }
      }
      await _session.hydratePersonalAdminFlag(_db);
    } finally {
      _flushing = false;
      if (_pendingDayWorkoutIds.isNotEmpty || _pendingLineIds.isNotEmpty) {
        _scheduleFlush();
      }
    }
  }

  Future<void> _pollWorkoutEvents() async {
    if (_disposed || !supabaseAppEnabled) return;
    try {
      final workouts = await (_db.select(_db.dayWorkouts)
            ..where((w) => w.status.equals('started')))
          .get();
      if (workouts.isEmpty) return;
      for (final w in workouts) {
        await _pollWorkoutEventsById(w.id);
      }
    } catch (_) {
      // best effort
    }
  }

  Future<void> _pollWorkoutEventsById(String workoutId) async {
    final c = Supabase.instance.client;
    final setCursor = _lastSetCursorByWorkout[workoutId] ?? 0;
    final restCursor = _lastRestCursorByWorkout[workoutId] ?? 0;
    final tombCursor = _lastTombCursorByWorkout[workoutId] ?? 0;

    final setRows = await c
        .from('day_workout_set_events')
        .select(
          'event_id,day_workout_id,day_workout_exercise_id,student_id,reps,load_kg,logged_at_ms,created_by_user_id,created_by_role,created_at',
        )
        .eq('day_workout_id', workoutId)
        .gt('logged_at_ms', setCursor)
        .order('logged_at_ms', ascending: true)
        .limit(200);
    for (final raw in (setRows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final loggedAtMs = _numToInt(m['logged_at_ms']);
      await _db.customStatement(
        'INSERT OR REPLACE INTO day_workout_set_events_local '
        '(event_id, day_workout_id, day_workout_exercise_id, student_id, reps, load_kg, '
        'logged_at_ms, created_by_user_id, created_by_role, created_at_ms, sync_status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          m['event_id'],
          m['day_workout_id'],
          m['day_workout_exercise_id'],
          m['student_id'] ?? '',
          _numToInt(m['reps']),
          _numToDouble(m['load_kg']),
          loggedAtMs,
          m['created_by_user_id']?.toString(),
          (m['created_by_role'] ?? 'personal').toString(),
          DateTime.now().millisecondsSinceEpoch,
          'synced',
        ],
      );
      _lastSetCursorByWorkout[workoutId] =
          max(_lastSetCursorByWorkout[workoutId] ?? 0, loggedAtMs);
    }

    final restRows = await c
        .from('day_workout_set_rest_events')
        .select(
          'rest_event_id,set_event_id,day_workout_id,day_workout_exercise_id,rest_prescribed_sec,rest_countdown_elapsed_ms,post_rest_modal_ms,recorded_at_ms,recorded_by_user_id,recorded_by_role,created_at',
        )
        .eq('day_workout_id', workoutId)
        .gt('recorded_at_ms', restCursor)
        .order('recorded_at_ms', ascending: true)
        .limit(200);
    for (final raw in (restRows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final recordedAtMs = _numToInt(m['recorded_at_ms']);
      await _db.customStatement(
        'INSERT OR REPLACE INTO day_workout_set_rest_events_local '
        '(rest_event_id, set_event_id, day_workout_id, day_workout_exercise_id, '
        'rest_prescribed_sec, rest_countdown_elapsed_ms, post_rest_modal_ms, '
        'recorded_at_ms, recorded_by_user_id, recorded_by_role, created_at_ms, sync_status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          m['rest_event_id'],
          m['set_event_id'],
          m['day_workout_id'],
          m['day_workout_exercise_id'],
          _numOrNullToInt(m['rest_prescribed_sec']),
          _numOrNullToInt(m['rest_countdown_elapsed_ms']),
          _numOrNullToInt(m['post_rest_modal_ms']),
          recordedAtMs,
          m['recorded_by_user_id']?.toString(),
          (m['recorded_by_role'] ?? 'personal').toString(),
          DateTime.now().millisecondsSinceEpoch,
          'synced',
        ],
      );
      _lastRestCursorByWorkout[workoutId] =
          max(_lastRestCursorByWorkout[workoutId] ?? 0, recordedAtMs);
    }

    final tombRows = await c
        .from('day_workout_set_event_tombstones')
        .select(
          'tombstone_id,event_id,day_workout_id,day_workout_exercise_id,deleted_at_ms,deleted_by_user_id,deleted_by_role,deleted_at',
        )
        .eq('day_workout_id', workoutId)
        .gt('deleted_at_ms', tombCursor)
        .order('deleted_at_ms', ascending: true)
        .limit(200);
    for (final raw in (tombRows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final deletedAtMs = _numToInt(m['deleted_at_ms']);
      await _db.customStatement(
        'INSERT OR REPLACE INTO day_workout_set_event_tombstones_local '
        '(tombstone_id, event_id, day_workout_id, day_workout_exercise_id, '
        'deleted_at_ms, deleted_by_user_id, deleted_by_role, created_at_ms, sync_status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          m['tombstone_id'],
          m['event_id'],
          m['day_workout_id'],
          m['day_workout_exercise_id'],
          deletedAtMs,
          m['deleted_by_user_id']?.toString(),
          (m['deleted_by_role'] ?? 'personal').toString(),
          DateTime.now().millisecondsSinceEpoch,
          'synced',
        ],
      );
      _lastTombCursorByWorkout[workoutId] =
          max(_lastTombCursorByWorkout[workoutId] ?? 0, deletedAtMs);
    }

    final lines = await _db.customSelect(
      'SELECT DISTINCT day_workout_exercise_id '
      'FROM day_workout_set_events_local WHERE day_workout_id = ?',
      variables: <Variable<Object>>[Variable<String>(workoutId)],
    ).get();
    for (final line in lines) {
      final lineId = line.read<String>('day_workout_exercise_id');
      await _rebuildDerivedPerformedSets(workoutId: workoutId, lineId: lineId);
    }
  }

  Future<void> _rebuildDerivedPerformedSets({
    required String workoutId,
    required String lineId,
  }) async {
    final setRows = await _db.customSelect(
      'SELECT event_id, reps, load_kg, logged_at_ms '
      'FROM day_workout_set_events_local '
      'WHERE day_workout_id = ? AND day_workout_exercise_id = ? '
      'ORDER BY logged_at_ms ASC, created_at_ms ASC, event_id ASC',
      variables: <Variable<Object>>[
        Variable<String>(workoutId),
        Variable<String>(lineId),
      ],
    ).get();
    final restRows = await _db.customSelect(
      'SELECT set_event_id, rest_prescribed_sec, rest_countdown_elapsed_ms, post_rest_modal_ms '
      'FROM day_workout_set_rest_events_local '
      'WHERE day_workout_id = ? AND day_workout_exercise_id = ? '
      'ORDER BY recorded_at_ms ASC, created_at_ms ASC',
      variables: <Variable<Object>>[
        Variable<String>(workoutId),
        Variable<String>(lineId),
      ],
    ).get();
    final tombRows = await _db.customSelect(
      'SELECT event_id FROM day_workout_set_event_tombstones_local '
      'WHERE day_workout_id = ? AND day_workout_exercise_id = ?',
      variables: <Variable<Object>>[
        Variable<String>(workoutId),
        Variable<String>(lineId),
      ],
    ).get();
    final setEvents = setRows
        .map(
          (row) => (
            eventId: row.read<String>('event_id'),
            reps: _numToInt(row.data['reps']),
            loadKg: _numOrNullToDouble(row.data['load_kg']),
            loggedAtMs: _numToInt(row.data['logged_at_ms']),
            createdAtMs: _numToInt(row.data['created_at_ms']),
          ),
        )
        .toList();
    final restEvents = restRows
        .map(
          (row) => (
            restEventId: row.read<String>('rest_event_id'),
            setEventId: row.read<String>('set_event_id'),
            restPrescribedSec: _numOrNullToInt(row.data['rest_prescribed_sec']),
            restCountdownElapsedMs: _numOrNullToInt(
              row.data['rest_countdown_elapsed_ms'],
            ),
            postRestModalMs: _numOrNullToInt(row.data['post_rest_modal_ms']),
            recordedAtMs: _numToInt(row.data['recorded_at_ms']),
            createdAtMs: _numToInt(row.data['created_at_ms']),
          ),
        )
        .toList();
    final tombstones = tombRows
        .map(
          (row) => (
            tombstoneId: row.read<String>('tombstone_id'),
            eventId: row.read<String>('event_id'),
            deletedAtMs: _numToInt(row.data['deleted_at_ms']),
          ),
        )
        .toList();
    final currentRow = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.id.equals(lineId)))
        .getSingleOrNull();
    final composed = DayWorkoutPerformedSetComposer.compose(
      legacyJsonRaw: currentRow?.performedSetsJson,
      setEvents: setEvents,
      restEvents: restEvents,
      tombstones: tombstones,
    );
    final encoded = DayWorkoutPerformedSetCodec.encode(composed);
    final score = DayWorkoutPerformedSetCodec.totalExerciseScore(composed);
    final loadKg = composed.isEmpty ? null : composed.last.loadKg;
    await (_db.update(_db.dayWorkoutExercises)
          ..where((e) => e.id.equals(lineId)))
        .write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(encoded),
        exerciseScore: Value(score),
        loadKg: Value(loadKg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  int _numToInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  int? _numOrNullToInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double _numToDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  double? _numOrNullToDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
