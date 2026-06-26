import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
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
  RealtimeChannel? _weekScheduleBlocksChannel;
  RealtimeChannel? _weekScheduleItemsChannel;
  RealtimeChannel? _workoutGroupsChannel;
  Timer? _flushTimer;
  Timer? _startedWorkoutPollTimer;
  DateTime? _lastRemoteRecentProbeAt;
  bool _started = false;
  bool _disposed = false;
  bool _flushing = false;

  final Set<String> _pendingDayWorkoutIds = <String>{};
  final Set<String> _pendingLineIds = <String>{};
  final Set<String> _pendingWeekScheduleBlockIds = <String>{};
  final Set<String> _pendingWeekScheduleItemIds = <String>{};
  final Set<String> _pendingWorkoutGroupIds = <String>{};
  final Map<String, DateTime> _lastActivityAtByKey = <String, DateTime>{};

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

    _weekScheduleBlocksChannel = c
        .channel('pg:week_schedule_blocks:$nonce')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'week_schedule_blocks',
          callback: (payload) => _onWeekScheduleBlockPayload(payload),
        )
        .subscribe();

    _weekScheduleItemsChannel = c
        .channel('pg:week_schedule_items:$nonce')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'week_schedule_items',
          callback: (payload) => _onWeekScheduleItemPayload(payload),
        )
        .subscribe();

    _workoutGroupsChannel = c
        .channel('pg:workout_groups:$nonce')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workout_groups',
          callback: (payload) => _onWorkoutGroupPayload(payload),
        )
        .subscribe();

    _startedWorkoutPollTimer?.cancel();
    // Fallback de convergência: se um evento realtime falhar/perder,
    // treinos locais em execução ainda serão reconciliados por pull pontual.
    _startedWorkoutPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_enqueueStartedWorkoutFallbackPulls()),
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
    _started = false;

    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    final w = _dayWorkoutsChannel;
    final l = _dayWorkoutExercisesChannel;
    final b = _weekScheduleBlocksChannel;
    final i = _weekScheduleItemsChannel;
    final g = _workoutGroupsChannel;
    _dayWorkoutsChannel = null;
    _dayWorkoutExercisesChannel = null;
    _weekScheduleBlocksChannel = null;
    _weekScheduleItemsChannel = null;
    _workoutGroupsChannel = null;

    if (w != null) {
      await c.removeChannel(w);
    }
    if (l != null) {
      await c.removeChannel(l);
    }
    if (b != null) {
      await c.removeChannel(b);
    }
    if (i != null) {
      await c.removeChannel(i);
    }
    if (g != null) {
      await c.removeChannel(g);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _pendingDayWorkoutIds.clear();
    _pendingLineIds.clear();
    _pendingWeekScheduleBlockIds.clear();
    _pendingWeekScheduleItemIds.clear();
    _pendingWorkoutGroupIds.clear();
    await _detachRealtimeChannels();
  }

  Future<void> _enqueueStartedWorkoutFallbackPulls() async {
    if (_disposed || !supabaseAppEnabled) return;
    if (_sync.isDayWorkoutPullMuted) return;
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
          ? const Duration(seconds: 60)
          : const Duration(seconds: 30);
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
            .limit(hasStartedLocal ? 20 : 12);
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

  void _onWeekScheduleBlockPayload(PostgresChangePayload payload) {
    final id = _idFromPayload(payload);
    if (id == null || id.isEmpty) return;
    _pendingWeekScheduleBlockIds.add(id);
    _scheduleFlush();
  }

  void _onWeekScheduleItemPayload(PostgresChangePayload payload) {
    final id = _idFromPayload(payload);
    if (id != null && id.isNotEmpty) {
      _pendingWeekScheduleItemIds.add(id);
    }
    final blockId = _blockIdFromPayload(payload);
    if (blockId != null && blockId.isNotEmpty) {
      _pendingWeekScheduleBlockIds.add(blockId);
    }
    _scheduleFlush();
  }

  void _onWorkoutGroupPayload(PostgresChangePayload payload) {
    final id = _idFromPayload(payload);
    if (id == null || id.isEmpty) return;
    _pendingWorkoutGroupIds.add(id);
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

  String? _blockIdFromPayload(PostgresChangePayload payload) {
    final next = payload.newRecord;
    if (next.containsKey('block_id')) {
      final id = next['block_id'];
      if (id is String && id.isNotEmpty) return id;
    }
    final old = payload.oldRecord;
    final id = old['block_id'];
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
    if (_sync.isDayWorkoutPullMuted &&
        _pendingLineIds.isEmpty &&
        _pendingWeekScheduleBlockIds.isEmpty &&
        _pendingWeekScheduleItemIds.isEmpty &&
        _pendingWorkoutGroupIds.isEmpty) {
      return;
    }
    if (_pendingDayWorkoutIds.isEmpty &&
        _pendingLineIds.isEmpty &&
        _pendingWeekScheduleBlockIds.isEmpty &&
        _pendingWeekScheduleItemIds.isEmpty &&
        _pendingWorkoutGroupIds.isEmpty) {
      return;
    }

    _flushing = true;
    try {
      final dayIds = _pendingDayWorkoutIds.toList(growable: false);
      final lineIds = _pendingLineIds.toList(growable: false);
      final weekBlockIds = _pendingWeekScheduleBlockIds.toList(growable: false);
      final weekItemIds = _pendingWeekScheduleItemIds.toList(growable: false);
      final workoutGroupIds = _pendingWorkoutGroupIds.toList(growable: false);
      _pendingDayWorkoutIds.clear();
      _pendingLineIds.clear();
      _pendingWeekScheduleBlockIds.clear();
      _pendingWeekScheduleItemIds.clear();
      _pendingWorkoutGroupIds.clear();

      final pull = SupabasePullSyncService(_db, _sync, session: _session);
      for (final id in workoutGroupIds) {
        await pull.pullWorkoutGroupById(id);
      }
      for (final id in weekBlockIds) {
        await pull.pullWeekScheduleBlockById(id);
      }
      for (final id in weekItemIds) {
        await pull.pullWeekScheduleItemById(id);
      }
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
      if (_pendingDayWorkoutIds.isNotEmpty ||
          _pendingLineIds.isNotEmpty ||
          _pendingWeekScheduleBlockIds.isNotEmpty ||
          _pendingWeekScheduleItemIds.isNotEmpty ||
          _pendingWorkoutGroupIds.isNotEmpty) {
        _scheduleFlush();
      }
    }
  }
}
