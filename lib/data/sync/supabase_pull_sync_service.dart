import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/app_session.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../../core/utils/student_archive_display_utils.dart';
import '../exercise_name_similarity.dart';
import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';

class SupabasePullTableResult {
  SupabasePullTableResult(
    this.tableName,
    this.rowCount,
    this.ok, [
    this.error,
    this.rowsWrittenToLocal,
    this.rowsSkippedLocalNewer,
    this.rowsSkippedRedirect,
  ]);

  final String tableName;

  /// Linhas lidas da nuvem (iteradas).
  final int rowCount;
  final bool ok;
  final String? error;

  /// Gravações em SQLite ([insertOnConflictUpdate]).
  final int? rowsWrittenToLocal;

  /// Admin: cópia local tinha [updated_at] mais recente.
  final int? rowsSkippedLocalNewer;

  /// Reconciliação por nome (muscle/exercise) — não grava esta linha remota.
  final int? rowsSkippedRedirect;
}

class SupabasePullReport {
  SupabasePullReport({
    required this.connectionOk,
    required this.connectionMessage,
    required this.tables,
    required this.startedAt,
    required this.finishedAt,
  });

  final bool connectionOk;
  final String connectionMessage;
  final List<SupabasePullTableResult> tables;
  final DateTime startedAt;
  final DateTime finishedAt;

  String toReportText() {
    final b = StringBuffer();
    b.writeln('=== Importar da nuvem → SQLite ===');
    b.writeln(
      'Conexão: ${connectionOk ? "OK" : "FALHOU"} — $connectionMessage',
    );
    b.writeln();
    for (final t in tables) {
      b.write(
        '[${t.ok ? "OK" : "ERRO"}] ${t.tableName}: ${t.rowCount} recebida(s) da nuvem',
      );
      final w = t.rowsWrittenToLocal;
      if (w != null) {
        b.write(' | $w gravada(s) no dispositivo');
        final sn = t.rowsSkippedLocalNewer ?? 0;
        if (sn > 0) {
          b.write(' | $sn ignorada(s) (cópia local mais recente)');
        }
        final rd = t.rowsSkippedRedirect ?? 0;
        if (rd > 0) {
          b.write(' | $rd ignorada(s) (reconciliação por nome / id)');
        }
      }
      b.writeln();
      if (t.error != null) b.writeln('  → ${t.error}');
    }
    b.writeln();
    b.writeln('Início: ${startedAt.toIso8601String()}');
    b.writeln('Fim: ${finishedAt.toIso8601String()}');
    return b.toString();
  }
}

DateTime _ts(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String) return DateTime.parse(v);
  return DateTime.parse(v.toString());
}

String _str(Map<String, dynamic> r, String k) => r[k] as String;

String? _strOpt(Map<String, dynamic> r, String k) => r[k] as String?;

int _int(Map<String, dynamic> r, String k) => (r[k] as num).toInt();

int _intOpt(Map<String, dynamic> r, String k, int d) {
  final v = r[k];
  if (v == null) return d;
  return (v as num).toInt();
}

double? _dblOpt(Map<String, dynamic> r, String k) {
  final v = r[k];
  if (v == null) return null;
  return (v as num).toDouble();
}

bool _bool(Map<String, dynamic> r, String k, {bool d = false}) {
  final v = r[k];
  if (v is bool) return v;
  if (v == null) return d;
  return v == true || v == 1 || v == 'true';
}

/// Evita «des-arquivar» após pull quando a nuvem ainda não tem [is_archived] coerente.
bool _pullStudentIsArchivedFromRow(Map<String, dynamic> r) {
  if (_bool(r, 'is_archived', d: false)) return true;
  final n = r['name'];
  if (n is! String) return false;
  return studentNameIndicatesArchivedStub(n);
}

DateTime? _pullStudentArchivedAtFromRow(
  Map<String, dynamic> r, {
  required bool effectiveArchived,
}) {
  if (!effectiveArchived) return _tsOpt(r['archived_at']);
  final explicit = _tsOpt(r['archived_at']);
  if (explicit != null) return explicit;
  return _tsOpt(r['updated_at']);
}

DateTime? _tsOpt(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.parse(v);
  return DateTime.parse(v.toString());
}

bool _localDeleteWinsOverRemote({
  required DateTime? localDeleteAt,
  required DateTime remoteUpdatedAt,
}) {
  final d = localDeleteAt;
  if (d == null) return false;
  // Tolerância para drift/truncagem de relógios (Postgres vs device).
  return d.isAfter(remoteUpdatedAt.subtract(const Duration(seconds: 3)));
}

/// Importação com nuvem completa (admin): não sobrescrever SQLite se a cópia local for **mais recente** que a remota.
bool _adminKeepLocalNewer(
  bool pullFullCloud,
  DateTime remoteUpdated,
  DateTime? localUpdated,
) {
  if (!pullFullCloud) return false;
  if (localUpdated == null) return false;
  return localUpdated.isAfter(remoteUpdated);
}

Future<Map<String, DateTime>> _pendingAuditLatestAtByEntity(
  AppDatabase db,
  String entityType,
) async {
  try {
    final rows = await (db.select(
      db.auditLogs,
    )..where((a) => a.entityType.equals(entityType))).get();
    final out = <String, DateTime>{};
    for (final row in rows) {
      final id = row.entityId;
      if (id == null || id.isEmpty) continue;
      final prev = out[id];
      if (prev == null || row.at.isAfter(prev)) out[id] = row.at;
    }
    return out;
  } catch (_) {
    return <String, DateTime>{};
  }
}

Future<bool> _hasPendingSyncQueueForEntity({
  required AppDatabase db,
  required String entityType,
  required String entityId,
}) async {
  try {
    final row =
        await (db.select(db.syncQueue)..where(
              (q) =>
                  q.entityType.equals(entityType) &
                  q.entityId.equals(entityId) &
                  q.status.isIn(const ['pending', 'syncing', 'failed']),
            ))
            .getSingleOrNull();
    return row != null;
  } catch (_) {
    return false;
  }
}

bool _hasRecentPendingLocalAudit({
  required String entityId,
  required DateTime remoteUpdatedAt,
  required Map<String, DateTime> latestPendingAuditAtById,
}) {
  final pendingAt = latestPendingAuditAtById[entityId];
  if (pendingAt == null) return false;
  // Só considera "pendente local vence" quando a auditoria local é realmente
  // contemporânea/mais nova que a remota.
  return pendingAt.isAfter(
    remoteUpdatedAt.subtract(const Duration(seconds: 3)),
  );
}

const _kPerformedSetAuditActions = {'append_set', 'remove_set', 'update_set'};
const _uuid = Uuid();

int _remoteRevision(Map<String, dynamic> row) => _intOpt(row, 'revision', 0);

String? _remoteDeviceId(Map<String, dynamic> row) =>
    (row['last_modified_by_device_id'] as String?)?.trim();

bool _localWinsConflictByVersion({
  required int localRevision,
  required int remoteRevision,
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
  required String? localDeviceId,
  required String? remoteDeviceId,
}) {
  if (localRevision != remoteRevision) {
    return localRevision > remoteRevision;
  }
  if (localUpdatedAt != remoteUpdatedAt) {
    return localUpdatedAt.isAfter(remoteUpdatedAt);
  }
  final ld = (localDeviceId ?? '').trim();
  final rd = (remoteDeviceId ?? '').trim();
  if (ld.isEmpty || rd.isEmpty) return false;
  return ld.compareTo(rd) >= 0;
}

Future<void> _enqueueLocalRepush(
  AppDatabase db, {
  required String entityType,
  required String entityId,
  required String reason,
}) async {
  final now = DateTime.now();
  final auditId = _uuid.v4();
  final payload = <String, Object?>{'reason': reason, 'from': 'pull_conflict'};
  await db
      .into(db.auditLogs)
      .insert(
        AuditLogsCompanion.insert(
          id: auditId,
          action: 'resync_local',
          entityType: entityType,
          entityId: Value(entityId),
          payloadJson: Value(jsonEncode(payload)),
          at: Value(now),
        ),
      );
  final queueId = _uuid.v4();
  await db
      .into(db.syncQueue)
      .insertOnConflictUpdate(
        SyncQueueCompanion.insert(
          id: queueId,
          entityType: entityType,
          entityId: entityId,
          operation: 'resync_local',
          payloadJson: Value(jsonEncode(payload)),
          priority: const Value(0),
          status: const Value('pending'),
          retryCount: const Value(0),
          nextRetryAt: const Value(null),
          dedupeKey: const Value(null),
          auditLogId: Value(auditId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Só bloqueia fusão de séries quando há **auditoria recente** da mesma linha —
/// auditorias antigas (fila presa, sync falhou há dias) não podem impedir que
/// outro dispositivo (ex.: iPhone) apareça no tablet.
Future<bool> _hasRecentBlockingPerformedSetAuditForLine({
  required AppDatabase db,
  required String lineId,
  required DateTime remoteRowUpdatedAt,
}) async {
  try {
    // iPhone/rede lenta: o push pode chegar segundos depois. Usamos o instante
    // **mais recente** entre (remoto−90s) e (agora−3min) para não bloquear merges
    // legítimos quando o updated_at remoto é muito antigo.
    final tRemote = remoteRowUpdatedAt.subtract(const Duration(seconds: 90));
    final tClock = DateTime.now().subtract(const Duration(minutes: 3));
    final threshold = tRemote.isAfter(tClock) ? tRemote : tClock;
    final rows =
        await (db.select(db.auditLogs)..where(
              (a) =>
                  a.entityType.equals('day_workout_exercise') &
                  a.entityId.equals(lineId),
            ))
            .get();
    for (final row in rows) {
      if (!_kPerformedSetAuditActions.contains(row.action)) continue;
      if (row.at.isAfter(threshold)) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

int? _maxLoggedAtMs(Iterable<DayWorkoutPerformedSet> sets) {
  int? m;
  for (final s in sets) {
    final t = s.loggedAtMs;
    if (t != null && (m == null || t > m)) m = t;
  }
  return m;
}

/// A nuvem tem registo de séries «mais recente» que o local (mais séries ou
/// mesmo número mas com [loggedAtMs] posterior no último registo).
bool _remotePerformedSetsAheadOfLocal({
  required List<DayWorkoutPerformedSet> remote,
  required List<DayWorkoutPerformedSet> local,
}) {
  if (remote.length > local.length) return true;
  if (remote.length < local.length) return false;
  if (remote.isEmpty) return false;
  final rm = _maxLoggedAtMs(remote);
  final lm = _maxLoggedAtMs(local);
  if (rm == null) return false;
  if (lm == null) return true;
  return rm > lm;
}

bool _remoteLineProgressAheadOfLocal({
  required DayWorkoutExerciseEntity local,
  required Map<String, dynamic> remoteRow,
}) {
  final remoteSets = DayWorkoutPerformedSetCodec.decode(
    (_strOpt(remoteRow, 'performed_sets_json') ?? '').trim().isEmpty
        ? null
        : _strOpt(remoteRow, 'performed_sets_json'),
  );
  final localSets = DayWorkoutPerformedSetCodec.decode(local.performedSetsJson);
  if (_remotePerformedSetsAheadOfLocal(remote: remoteSets, local: localSets)) {
    return true;
  }

  // Score prescrito na nuvem não pode “ganhar” de séries já registradas localmente.
  if (remoteSets.length >= localSets.length) {
    final remoteScore = _dblOpt(remoteRow, 'exercise_score');
    final localScore = local.exerciseScore;
    if (remoteScore != null &&
        (localScore == null || remoteScore > localScore)) {
      return true;
    }
  }
  return false;
}

/// Nunca regredir séries executadas ao aplicar snapshot remoto na linha.
String? _performedSetsJsonForPullUpsert({
  required DayWorkoutExerciseEntity? local,
  required Map<String, dynamic> remoteRow,
}) {
  final remoteRaw = _strOpt(remoteRow, 'performed_sets_json');
  if (local == null) return remoteRaw;
  final localSets = DayWorkoutPerformedSetCodec.decode(local.performedSetsJson);
  final remoteSets = DayWorkoutPerformedSetCodec.decode(
    (remoteRaw ?? '').trim().isEmpty ? null : remoteRaw,
  );
  if (localSets.length > remoteSets.length) {
    return local.performedSetsJson;
  }
  final remoteUpd =
      _tsOpt(remoteRow['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (localSets.isNotEmpty &&
      local.updatedAt.isAfter(remoteUpd.add(const Duration(seconds: 1))) &&
      localSets.length >= remoteSets.length) {
    return local.performedSetsJson;
  }
  if (localSets.length == remoteSets.length && localSets.isNotEmpty) {
    final lm = _maxLoggedAtMs(localSets);
    final rm = _maxLoggedAtMs(remoteSets);
    if (lm != null && (rm == null || lm > rm)) {
      return local.performedSetsJson;
    }
    if (lm != null &&
        rm != null &&
        lm == rm &&
        DayWorkoutPerformedSetCodec.encode(localSets) !=
            DayWorkoutPerformedSetCodec.encode(remoteSets) &&
        local.updatedAt.isAfter(remoteUpd)) {
      return local.performedSetsJson;
    }
  }
  return remoteRaw;
}

double? _exerciseScoreForPullUpsert({
  required DayWorkoutExerciseEntity? local,
  required Map<String, dynamic> remoteRow,
  required String? performedSetsJson,
}) {
  if (local != null &&
      performedSetsJson != null &&
      performedSetsJson.trim() == (local.performedSetsJson ?? '').trim()) {
    final sets = DayWorkoutPerformedSetCodec.decode(performedSetsJson);
    if (sets.isNotEmpty) {
      return DayWorkoutPerformedSetCodec.totalExerciseScore(sets);
    }
    if (local.exerciseScore != null) return local.exerciseScore;
  }
  return _dblOpt(remoteRow, 'exercise_score');
}

/// Evita downgrade de treino concluído/cancelado por snapshot remoto atrasado.
String _dayWorkoutStatusForPullUpsert({
  required DayWorkoutEntity? local,
  required String remoteStatus,
}) {
  if (local == null) return remoteStatus;
  if (local.status == 'completed' && remoteStatus != 'completed') {
    return 'completed';
  }
  if (local.status == 'cancelled' && remoteStatus != 'cancelled') {
    return 'cancelled';
  }
  return remoteStatus;
}

bool _preserveLocalDayWorkoutCompletionFields({
  required DayWorkoutEntity? local,
  required String remoteStatus,
}) {
  if (local == null) return false;
  if (local.status == 'completed' && remoteStatus != 'completed') return true;
  if (local.status == 'cancelled' && remoteStatus != 'cancelled') return true;
  return false;
}

/// Evita regressão visual ("sumiu e voltou") quando o pull remoto chega com
/// snapshot antigo de séries logo após edição/registro local recente.
bool _shouldPreserveLocalPerformedSetsSnapshot({
  required DayWorkoutExerciseEntity local,
  required Map<String, dynamic> remoteRow,
  required DateTime remoteUpdatedAt,
  Duration recentLocalWindow = const Duration(minutes: 15),
}) {
  if (_remoteLineProgressAheadOfLocal(local: local, remoteRow: remoteRow)) {
    return false;
  }
  final remoteSets = DayWorkoutPerformedSetCodec.decode(
    (_strOpt(remoteRow, 'performed_sets_json') ?? '').trim().isEmpty
        ? null
        : _strOpt(remoteRow, 'performed_sets_json'),
  );
  final localSets = DayWorkoutPerformedSetCodec.decode(local.performedSetsJson);
  if (localSets.isEmpty) return false;
  if (_remotePerformedSetsAheadOfLocal(remote: remoteSets, local: localSets)) {
    return false;
  }
  // Nunca regredir o nº de séries executadas por um JSON remoto com menos entradas
  // (push atrasado / pull intermédio / realtime fora de ordem).
  if (localSets.length > remoteSets.length) {
    return true;
  }
  // Mesmo nº de séries: último registo local mais recente ⇒ snapshot remoto velho.
  if (localSets.length == remoteSets.length && localSets.isNotEmpty) {
    final lm = _maxLoggedAtMs(localSets);
    final rm = _maxLoggedAtMs(remoteSets);
    if (lm != null && (rm == null || lm > rm)) {
      return true;
    }
  }
  final now = DateTime.now();
  final localIsRecent = local.updatedAt.isAfter(
    now.subtract(recentLocalWindow),
  );
  if (!localIsRecent) return false;
  // Se o remoto não está claramente mais novo E não está à frente nas séries,
  // preserva o local para impedir regressão temporária.
  return !remoteUpdatedAt.isAfter(
    local.updatedAt.add(const Duration(seconds: 1)),
  );
}

/// Quando o LWW por [updated_at] faria skip total, ainda aplica só séries
/// executadas vindas da nuvem se outro dispositivo está à frente no registo
/// e não há mutações de série pendentes de envio **recentes** neste aparelho.
Future<bool> _tryMergeRemotePerformedSetsWhenLocalLooksNewer({
  required AppDatabase db,
  required DayWorkoutExerciseEntity local,
  required Map<String, dynamic> remoteRow,
  required DateTime remoteUpd,
}) async {
  if (await _hasRecentBlockingPerformedSetAuditForLine(
    db: db,
    lineId: local.id,
    remoteRowUpdatedAt: remoteUpd,
  )) {
    return false;
  }

  final rawRemote = _strOpt(remoteRow, 'performed_sets_json');
  final remoteJson = (rawRemote ?? '').trim();
  final localJson = (local.performedSetsJson ?? '').trim();

  final remoteSets = DayWorkoutPerformedSetCodec.decode(
    remoteJson.isEmpty ? null : remoteJson,
  );
  final localSets = DayWorkoutPerformedSetCodec.decode(
    localJson.isEmpty ? null : localJson,
  );
  final remoteSetsAhead = _remotePerformedSetsAheadOfLocal(
    remote: remoteSets,
    local: localSets,
  );
  if (!remoteSetsAhead) {
    return false;
  }

  try {
    await (db.update(
      db.dayWorkoutExercises,
    )..where((x) => x.id.equals(local.id))).write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(
          DayWorkoutPerformedSetCodec.encode(remoteSets),
        ),
        exerciseScore: Value(_dblOpt(remoteRow, 'exercise_score')),
        loadKg: Value(_dblOpt(remoteRow, 'load_kg')),
        updatedAt: Value(
          remoteUpd.isAfter(local.updatedAt) ? remoteUpd : local.updatedAt,
        ),
      ),
    );
  } catch (e, st) {
    debugPrint(
      'SupabasePullSyncService merge performed_sets line=${local.id}: $e\n$st',
    );
    return false;
  }
  return true;
}

bool _hotLocalWorkoutEditCooldownWins({
  required String entityType,
  required DateTime localUpdatedAt,
}) {
  const hotWorkoutEntities = {'day_workout', 'day_workout_exercise'};
  if (!hotWorkoutEntities.contains(entityType)) return false;
  final now = DateTime.now();
  // Janela anti-ioiô (iPhone/rede instável): evita pull/realtime a reescrever
  // linhas de treino logo após registo local de séries.
  return localUpdatedAt.isAfter(now.subtract(const Duration(seconds: 120)));
}

Future<bool> _shouldSkipRemoteEntityUpsertById({
  required AppDatabase db,
  required String entityType,
  required String entityId,
  required DateTime remoteUpdatedAt,
  DateTime? localUpdatedAt,
  int? localRevision,
  int? remoteRevision,
  Map<String, DateTime>? latestPendingAuditAtById,
}) async {
  final localDeletes = await _localDeletesByIdFor(db, entityType);
  final delAt = localDeletes[entityId];
  if (_localDeleteWinsOverRemote(
    localDeleteAt: delAt,
    remoteUpdatedAt: remoteUpdatedAt,
  )) {
    return true;
  }

  if (localUpdatedAt == null) return false;

  // Regra forte de convergência: revisão remota maior sempre deve entrar.
  // Evita bloqueio por cooldown/relógio local quando o outro dispositivo
  // acabou de registrar série/concluir treino.
  if (remoteRevision != null &&
      localRevision != null &&
      remoteRevision > localRevision) {
    return false;
  }

  final latestPending =
      latestPendingAuditAtById ??
      await _pendingAuditLatestAtByEntity(db, entityType);
  final hasRecentPendingLocalAudit = _hasRecentPendingLocalAudit(
    entityId: entityId,
    remoteUpdatedAt: remoteUpdatedAt,
    latestPendingAuditAtById: latestPending,
  );

  // Cooldown anti-ioiô deve valer apenas quando há edição local pendente para
  // a mesma entidade. Sem pendência local, não bloquear atualização remota nova.
  if (_hotLocalWorkoutEditCooldownWins(
        entityType: entityType,
        localUpdatedAt: localUpdatedAt,
      ) &&
      hasRecentPendingLocalAudit &&
      !remoteUpdatedAt.isAfter(
        localUpdatedAt.add(const Duration(seconds: 1)),
      )) {
    return true;
  }

  // Evita "efeito ioiô" (volta e some) quando o pull lê um snapshot remoto
  // ainda atrasado logo após uma edição local já confirmada na UI.
  // Para entidades de treino em execução, preferimos o local quando está
  // claramente mais novo que o remoto (LWW com tolerância de relógio).
  const hotWorkoutEntities = {'day_workout', 'day_workout_exercise'};
  if (hotWorkoutEntities.contains(entityType) &&
      localUpdatedAt.isAfter(remoteUpdatedAt.add(const Duration(seconds: 3)))) {
    return true;
  }

  if (!hasRecentPendingLocalAudit) {
    return false;
  }
  return localUpdatedAt.isAfter(remoteUpdatedAt);
}

Future<Map<String, DateTime>> _localDeletesByIdFor(
  AppDatabase db,
  String entityType,
) async {
  try {
    final rows =
        await (db.select(db.auditLogs)..where(
              (a) =>
                  a.entityType.equals(entityType) & a.action.equals('delete'),
            ))
            .get();
    final out = <String, DateTime>{};
    for (final r in rows) {
      final id = r.entityId;
      if (id == null || id.isEmpty) continue;
      final prev = out[id];
      if (prev == null || r.at.isAfter(prev)) out[id] = r.at;
    }
    return out;
  } catch (_) {
    return <String, DateTime>{};
  }
}

List<Map<String, dynamic>> _rows(dynamic response) {
  if (response == null) return [];
  final list = response as List<dynamic>;
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// Admin / nuvem completa: várias páginas em vez de um único `.select()` (timeout,
/// limite PostgREST e rede lenta em tablets).
Future<List<Map<String, dynamic>>> _pullTableRowsPaged(
  SupabaseClient c,
  String table, {
  int pageSize = 1000,
  Duration perRequestTimeout = const Duration(seconds: 90),
}) async {
  final out = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final end = offset + pageSize - 1;
    final resp = await c
        .from(table)
        .select()
        .range(offset, end)
        .timeout(perRequestTimeout);
    final part = _rows(resp);
    if (part.isEmpty) break;
    out.addAll(part);
    if (part.length < pageSize) break;
    offset += pageSize;
  }
  return out;
}

/// Baixa dados do Postgres e faz upsert no Drift (sem disparar auditoria → evita loop de push).
class SupabasePullSyncService {
  SupabasePullSyncService(this._db, this._sync, {AppSession? session})
    : _session = session;

  final AppDatabase _db;
  final SupabaseSyncController _sync;
  final AppSession? _session;

  /// IDs remotos de `muscle_groups` que foram ignorados no pull porque o nome
  /// já existia localmente com outro id — [exercises] devem usar o id canônico local.
  final Map<String, String> _pullMuscleGroupIdRedirect = {};

  /// IDs remotos de `exercises` ignorados quando o nome normalizado já existia localmente.
  final Map<String, String> _pullExerciseIdRedirect = {};

  String _resolvedExerciseId(String raw) => _pullExerciseIdRedirect[raw] ?? raw;

  /// Admin (ou sessão nula): nuvem inteira. Personal: alunos/cadastros ligados a ele.
  /// Aluno: só o próprio cadastro e treinos.
  bool get _pullFullCloud {
    final s = _session;
    return s == null || s.hasFullOrgAccess;
  }

  final Set<String> _pullReferencedWorkoutGroupIds = {};
  List<String> _pullScopeStudentIds = [];
  List<String> _pullScopeBlockIds = [];
  List<String> _pullScopeDayWorkoutIds = [];

  bool _canAccessRemoteWorkoutGroupRow(Map<String, dynamic> row) {
    if (_pullFullCloud) return true;
    final s = _session;
    if (s == null) return true;
    if (_bool(row, 'is_shared', d: false)) return true;
    if (s.isPersonalTrainer) {
      final pid = s.personalId;
      final ownerId = _strOpt(row, 'created_by_personal_id');
      return ownerId == null || (pid != null && ownerId == pid);
    }
    return _pullReferencedWorkoutGroupIds.contains(_str(row, 'id'));
  }

  Future<List<Map<String, dynamic>>> _pullWorkoutGroupRowsForSession(
    SupabaseClient c,
  ) async {
    if (_pullFullCloud) {
      return _pullTableRowsPaged(c, 'workout_groups');
    }
    final s = _session;
    if (s?.isPersonalTrainer == true) {
      final pid = s!.personalId;
      final legacyRows = _rows(
        await c
            .from('workout_groups')
            .select()
            .isFilter('created_by_personal_id', null)
            .timeout(const Duration(seconds: 90)),
      );
      if (pid == null) return legacyRows;
      final ownRows = await _selectInChunks(
        c,
        'workout_groups',
        'created_by_personal_id',
        [pid],
      );
      return {
        for (final row in [...legacyRows, ...ownRows]) _str(row, 'id'): row,
      }.values.toList(growable: false);
    }
    if (_pullReferencedWorkoutGroupIds.isEmpty) return [];
    return _selectInChunks(
      c,
      'workout_groups',
      'id',
      _pullReferencedWorkoutGroupIds.toList(),
    );
  }

  Future<bool> _ensureLocalDayWorkoutExists(String dayWorkoutId) async {
    final local = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(dayWorkoutId))).getSingleOrNull();
    if (local != null) return true;
    try {
      await pullDayWorkoutById(dayWorkoutId);
    } catch (_) {
      // best effort
    }
    final after = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.id.equals(dayWorkoutId))).getSingleOrNull();
    return after != null;
  }

  Future<String?> _ensureLocalExerciseExists(
    String rawExerciseId, {
    Set<String>? localExerciseIds,
  }) async {
    Future<bool> hasLocal(String id) async {
      if (localExerciseIds != null) return localExerciseIds.contains(id);
      final row = await (_db.select(
        _db.exercises,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      return row != null;
    }

    Future<bool> refreshLocal(String id) async {
      final row = await (_db.select(
        _db.exercises,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (row == null) return false;
      localExerciseIds?.add(row.id);
      return true;
    }

    var resolvedId = _resolvedExerciseId(rawExerciseId);
    if (await hasLocal(resolvedId)) {
      localExerciseIds?.add(resolvedId);
      return resolvedId;
    }

    try {
      await pullExerciseById(rawExerciseId);
    } catch (_) {
      // best effort
    }

    resolvedId = _resolvedExerciseId(rawExerciseId);
    if (await hasLocal(resolvedId)) {
      localExerciseIds?.add(resolvedId);
      return resolvedId;
    }
    if (await refreshLocal(resolvedId)) return resolvedId;
    return null;
  }

  Future<Map<String, DateTime>> _localDeletesById(String entityType) async {
    try {
      final rows =
          await (_db.select(_db.auditLogs)..where(
                (a) =>
                    a.entityType.equals(entityType) & a.action.equals('delete'),
              ))
              .get();
      final out = <String, DateTime>{};
      for (final r in rows) {
        final id = r.entityId;
        if (id == null || id.isEmpty) continue;
        final prev = out[id];
        if (prev == null || r.at.isAfter(prev)) out[id] = r.at;
      }
      return out;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  /// `delete` + `cancel` em [day_workout]: o pull não pode trazer de volta treino que o utilizador
  /// já removeu/cancelou localmente enquanto o `updated_at` remoto não for **posterior** ao túmulo.
  Future<Map<String, DateTime>> _localDayWorkoutPullTombstones() async {
    final out = await _localDeletesById('day_workout');
    try {
      final rows =
          await (_db.select(_db.auditLogs)..where(
                (a) =>
                    a.entityType.equals('day_workout') &
                    a.action.equals('cancel'),
              ))
              .get();
      for (final r in rows) {
        final id = r.entityId;
        if (id == null || id.isEmpty) continue;
        final prev = out[id];
        if (prev == null || r.at.isAfter(prev)) out[id] = r.at;
      }
    } catch (_) {}
    return out;
  }

  /// Só aceitar linha remota se for claramente mais recente que o túmulo local (evita “ressuscitar”).
  bool _remoteDayWorkoutStrictlyAfterTombstone({
    required DateTime remoteUpdatedAt,
    required DateTime? tombstone,
  }) {
    if (tombstone == null) return true;
    return remoteUpdatedAt.isAfter(tombstone);
  }

  void _noteWorkoutGroupRef(String? id) {
    if (id == null || id.isEmpty) return;
    _pullReferencedWorkoutGroupIds.add(id);
  }

  Future<List<Map<String, dynamic>>> _selectInChunks(
    SupabaseClient c,
    String table,
    String column,
    List<String> ids, {
    int chunkSize = 80,
  }) async {
    if (ids.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = min(i + chunkSize, ids.length);
      final chunk = ids.sublist(i, end);
      final part = _rows(
        await c
            .from(table)
            .select()
            .inFilter(column, chunk)
            .timeout(const Duration(seconds: 90)),
      );
      out.addAll(part);
    }
    return out;
  }

  Future<String?> _remoteStudentTrainerId(
    SupabaseClient c,
    String studentId,
  ) async {
    try {
      final row = await c
          .from('students')
          .select('created_by_personal_id')
          .eq('id', studentId)
          .maybeSingle();
      final v = row?['created_by_personal_id'];
      if (v is String && v.isNotEmpty) return v;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SupabasePullReport> pullAllFromRemote() async {
    final started = DateTime.now();
    final tables = <SupabasePullTableResult>[];

    if (!supabaseAppEnabled) {
      return SupabasePullReport(
        connectionOk: false,
        connectionMessage: 'Supabase não configurado (sem chave no build).',
        tables: tables,
        startedAt: started,
        finishedAt: DateTime.now(),
      );
    }

    // Ping **antes** de [beginDownload]: se a rede ficar pendente, não deixamos
    // o indicador de download preso nem o import sem [endDownload] correspondente.
    try {
      await Supabase.instance.client
          .from('muscle_groups')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      return SupabasePullReport(
        connectionOk: false,
        connectionMessage: e.toString(),
        tables: tables,
        startedAt: started,
        finishedAt: DateTime.now(),
      );
    }

    final client = Supabase.instance.client;

    _sync.beginDownload();
    try {
      _pullMuscleGroupIdRedirect.clear();
      _pullExerciseIdRedirect.clear();
      _pullReferencedWorkoutGroupIds.clear();
      _pullScopeStudentIds = [];
      _pullScopeBlockIds = [];
      _pullScopeDayWorkoutIds = [];

      tables.add(await _pullMuscleGroups(client));
      tables.add(await _pullExercises(client));
      tables.add(await _pullGyms(client));
      tables.add(await _pullPersonals(client));
      tables.add(await _pullStudents(client));
      tables.add(await _pullStudentGyms(client));
      tables.add(await _pullTrainingMethods(client));

      if (_pullFullCloud) {
        tables.add(await _pullWorkoutGroups(client));
        tables.add(await _pullWorkoutGroupExercises(client));
        tables.add(await _pullWeekBlocks(client));
        tables.add(await _pullWeekItems(client, trackWorkoutGroupRefs: false));
        tables.add(
          await _pullDayWorkouts(client, trackWorkoutGroupRefs: false),
        );
        tables.add(await _pullDayWorkoutExercises(client));
        tables.add(await _pullAuditLogs(client));
      } else {
        tables.add(await _pullWeekBlocks(client));
        tables.add(await _pullWeekItems(client, trackWorkoutGroupRefs: true));
        tables.add(await _pullDayWorkouts(client, trackWorkoutGroupRefs: true));
        tables.add(await _pullDayWorkoutExercises(client));
        tables.add(await _pullWorkoutGroups(client));
        tables.add(await _pullWorkoutGroupExercises(client));
        tables.add(SupabasePullTableResult('audit_logs', 0, true));
      }

      final ok = tables.every((t) => t.ok);
      if (ok) {
        _sync.noteConnected();
        _sync.noteBackgroundPushSuccess();
      } else {
        _sync.noteDisconnected();
        _sync.noteBackgroundPushError(
          'Importação: uma ou mais tabelas falharam (veja relatório).',
        );
      }
    } catch (e, st) {
      debugPrint('SupabasePullSyncService: $e\n$st');
      tables.add(SupabasePullTableResult('(fatal)', 0, false, e.toString()));
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }

    return SupabasePullReport(
      connectionOk: true,
      connectionMessage: 'API OK',
      tables: tables,
      startedAt: started,
      finishedAt: DateTime.now(),
    );
  }

  /// Pull pontual: atualiza um `personal` específico a partir da nuvem (LWW: nuvem vence quando chamada por conflito).
  Future<void> pullPersonalById(String personalId) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('personals')
          .select()
          .eq('id', personalId)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(_str(r, 'updated_at'));
      final local = await (_db.select(
        _db.personals,
      )..where((x) => x.id.equals(personalId))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'personal',
        entityId: personalId,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.personals)
          .insertOnConflictUpdate(
            PersonalsCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name'),
              cpf: _str(r, 'cpf'),
              professionalRegistry: _str(r, 'professional_registry'),
              street: _str(r, 'street'),
              number: _str(r, 'number'),
              complement: Value(_strOpt(r, 'complement')),
              city: _str(r, 'city'),
              stateUf: _str(r, 'state_uf'),
              cep: Value(_strOpt(r, 'cep')),
              phoneCommercial: Value(_strOpt(r, 'phone_commercial')),
              phoneMobile: Value(_strOpt(r, 'phone_mobile')),
              email: _str(r, 'email'),
              mustChangePassword: Value(
                _bool(r, 'must_change_password', d: true),
              ),
              passwordHash: Value(_strOpt(r, 'password_hash')),
              isAdmin: Value(_bool(r, 'is_admin', d: false)),
              accessTier: Value(_strOpt(r, 'access_tier') ?? 'legacy'),
              maxStudentsCap: Value(
                r['max_students_cap'] == null
                    ? null
                    : (r['max_students_cap'] as num).toInt(),
              ),
              createdAt: Value(_ts(_str(r, 'created_at'))),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullPersonalById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  /// Pull pontual: atualiza um `student` específico e seus vínculos `student_gyms` a partir da nuvem.
  Future<void> pullStudentById(String studentId) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('students')
          .select()
          .eq('id', studentId)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(_str(r, 'updated_at'));
      final local = await (_db.select(
        _db.students,
      )..where((x) => x.id.equals(studentId))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'student',
        entityId: studentId,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      final effArchived = _pullStudentIsArchivedFromRow(r);
      await _db
          .into(_db.students)
          .insertOnConflictUpdate(
            StudentsCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name'),
              isArchived: Value(effArchived),
              archivedAt: Value(
                _pullStudentArchivedAtFromRow(
                  r,
                  effectiveArchived: effArchived,
                ),
              ),
              email: Value(_strOpt(r, 'email')),
              goal: Value(_strOpt(r, 'goal')),
              cpf: Value(_strOpt(r, 'cpf')),
              birthDate: Value(_tsOpt(r['birth_date'])),
              street: Value(_strOpt(r, 'street')),
              number: Value(_strOpt(r, 'number')),
              complement: Value(_strOpt(r, 'complement')),
              district: Value(_strOpt(r, 'district')),
              city: Value(_strOpt(r, 'city')),
              stateUf: Value(_strOpt(r, 'state_uf')),
              cep: Value(_strOpt(r, 'cep')),
              phoneCommercial: Value(_strOpt(r, 'phone_commercial')),
              phoneMobile: Value(_strOpt(r, 'phone_mobile')),
              mustChangePassword: Value(
                _bool(r, 'must_change_password', d: true),
              ),
              passwordHash: Value(_strOpt(r, 'password_hash')),
              createdByPersonalId: Value(_strOpt(r, 'created_by_personal_id')),
              anamneseCompleted: Value(
                _bool(r, 'anamnese_completed', d: false),
              ),
              accessTier: Value(_strOpt(r, 'access_tier') ?? 'student_free'),
              premiumPlanExpiresAt: Value(_tsOpt(r['premium_plan_expires_at'])),
              createdAt: Value(_ts(_str(r, 'created_at'))),
              updatedAt: Value(remoteUpd),
            ),
          );

      // Vínculos academias — substitui a cópia local pelo espelho da nuvem para este aluno.
      await (_db.delete(
        _db.studentGyms,
      )..where((t) => t.studentId.equals(studentId))).go();
      final linkRes = await c
          .from('student_gyms')
          .select()
          .eq('student_id', studentId);
      final links = linkRes as List<dynamic>;
      for (final e in links) {
        final m = Map<String, dynamic>.from(e as Map);
        final sid = m['student_id'] as String?;
        final gid = m['gym_id'] as String?;
        if (sid == null || gid == null) continue;
        await _db
            .into(_db.studentGyms)
            .insert(
              StudentGymsCompanion.insert(studentId: sid, gymId: gid),
              mode: InsertMode.insertOrIgnore,
            );
      }
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullStudentById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullMuscleGroupById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('muscle_groups').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.muscleGroups,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'muscle_group',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.muscleGroups)
          .insertOnConflictUpdate(
            MuscleGroupsCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name').trim().isEmpty
                  ? 'Sem nome'
                  : _str(r, 'name').trim(),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullMuscleGroupById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullExerciseById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('exercises').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.exercises,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'exercise',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      final mgId = _str(r, 'muscle_group_id');
      await pullMuscleGroupById(mgId);
      await _db
          .into(_db.exercises)
          .insertOnConflictUpdate(
            ExercisesCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name').trim().isEmpty
                  ? 'Sem nome'
                  : _str(r, 'name').trim(),
              muscleGroupId: mgId,
              videoUrl: Value(_strOpt(r, 'video_url')),
              alternativeNote: Value(_strOpt(r, 'alternative_note')),
              alternativeVideoUrl: Value(_strOpt(r, 'alternative_video_url')),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullExerciseById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullGymById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('gyms').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.gyms,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'gym',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.gyms)
          .insertOnConflictUpdate(
            GymsCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name'),
              cnpj: _str(r, 'cnpj'),
              street: _str(r, 'street'),
              number: _str(r, 'number'),
              complement: Value(_strOpt(r, 'complement')),
              district: _str(r, 'district'),
              city: _str(r, 'city'),
              stateUf: _str(r, 'state_uf'),
              cep: _str(r, 'cep'),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullGymById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullTrainingMethodById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('training_methods')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.trainingMethods,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'training_method',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.trainingMethods)
          .insertOnConflictUpdate(
            TrainingMethodsCompanion.insert(
              id: _str(r, 'id'),
              method: _str(r, 'method'),
              description: _str(r, 'description'),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullTrainingMethodById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullWorkoutGroupById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('workout_groups').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      if (!_canAccessRemoteWorkoutGroupRow(r)) return;
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.workoutGroups,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'workout_group',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.workoutGroups)
          .insertOnConflictUpdate(
            WorkoutGroupsCompanion.insert(
              id: _str(r, 'id'),
              name: _str(r, 'name'),
              description: _str(r, 'description'),
              createdByPersonalId: Value(_strOpt(r, 'created_by_personal_id')),
              isShared: Value(_bool(r, 'is_shared', d: false)),
              revision: Value(_intOpt(r, 'revision', 0)),
              lastModifiedByDeviceId: Value(
                _strOpt(r, 'last_modified_by_device_id'),
              ),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
              deletedAt: Value(_tsOpt(r['deleted_at'])),
            ),
          );

      // Linhas do grupo
      final linesRes = await c
          .from('workout_group_exercises')
          .select()
          .eq('workout_group_id', id);
      final lines = linesRes as List<dynamic>;
      for (final e in lines) {
        final m = Map<String, dynamic>.from(e as Map);
        final lineId = _str(m, 'id');
        final lineRemoteUpd =
            _tsOpt(m['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final localLine = await (_db.select(
          _db.workoutGroupExercises,
        )..where((x) => x.id.equals(lineId))).getSingleOrNull();
        if (await _shouldSkipRemoteEntityUpsertById(
          db: _db,
          entityType: 'workout_group_exercise',
          entityId: lineId,
          remoteUpdatedAt: lineRemoteUpd,
          localUpdatedAt: localLine?.updatedAt,
        )) {
          continue;
        }
        final exId = _str(m, 'exercise_id');
        await pullExerciseById(exId);
        await _db
            .into(_db.workoutGroupExercises)
            .insertOnConflictUpdate(
              WorkoutGroupExercisesCompanion.insert(
                id: lineId,
                workoutGroupId: _str(m, 'workout_group_id'),
                exerciseId: _resolvedExerciseId(exId),
                sortOrder: Value(_intOpt(m, 'sort_order', 0)),
                lastLoadKg: Value(_dblOpt(m, 'last_load_kg')),
                lastReps: Value(
                  m['last_reps'] == null ? null : _int(m, 'last_reps'),
                ),
                lastRepsText: Value(_strOpt(m, 'last_reps_text')),
                lastSets: Value(
                  m['last_sets'] == null ? null : _int(m, 'last_sets'),
                ),
                restBetweenSetsSec: Value(
                  _intOpt(m, 'rest_between_sets_sec', 60),
                ),
                trainingMethodId: Value(_strOpt(m, 'training_method_id')),
                comboId: Value(_strOpt(m, 'combo_id')),
                updatedAt: Value(lineRemoteUpd),
              ),
            );
      }
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullWorkoutGroupById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullWorkoutGroupExerciseById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('workout_group_exercises')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd =
          _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final local = await (_db.select(
        _db.workoutGroupExercises,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'workout_group_exercise',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      final exId = _str(r, 'exercise_id');
      await pullExerciseById(exId);
      await _db
          .into(_db.workoutGroupExercises)
          .insertOnConflictUpdate(
            WorkoutGroupExercisesCompanion.insert(
              id: _str(r, 'id'),
              workoutGroupId: _str(r, 'workout_group_id'),
              exerciseId: _resolvedExerciseId(exId),
              sortOrder: Value(_intOpt(r, 'sort_order', 0)),
              lastLoadKg: Value(_dblOpt(r, 'last_load_kg')),
              lastReps: Value(
                r['last_reps'] == null ? null : _int(r, 'last_reps'),
              ),
              lastRepsText: Value(_strOpt(r, 'last_reps_text')),
              lastSets: Value(
                r['last_sets'] == null ? null : _int(r, 'last_sets'),
              ),
              restBetweenSetsSec: Value(
                _intOpt(r, 'rest_between_sets_sec', 60),
              ),
              trainingMethodId: Value(_strOpt(r, 'training_method_id')),
              comboId: Value(_strOpt(r, 'combo_id')),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint(
        'SupabasePullSyncService pullWorkoutGroupExerciseById: $e\n$st',
      );
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullWeekScheduleBlockById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('week_schedule_blocks')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final local = await (_db.select(
        _db.weekScheduleBlocks,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'week_schedule_block',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      await _db
          .into(_db.weekScheduleBlocks)
          .insertOnConflictUpdate(
            WeekScheduleBlocksCompanion.insert(
              id: _str(r, 'id'),
              studentId: _str(r, 'student_id'),
              weekStartMonday: weekScheduleLocalCalendarDate(
                _ts(r['week_start_monday']),
              ),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
            ),
          );

      final itemsRes = await c
          .from('week_schedule_items')
          .select()
          .eq('block_id', id);
      final items = itemsRes as List<dynamic>;
      for (final e in items) {
        final m = Map<String, dynamic>.from(e as Map);
        final itemId = _str(m, 'id');
        final itemRemoteUpd =
            _tsOpt(m['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final localItem = await (_db.select(
          _db.weekScheduleItems,
        )..where((x) => x.id.equals(itemId))).getSingleOrNull();
        if (await _shouldSkipRemoteEntityUpsertById(
          db: _db,
          entityType: 'week_schedule_item',
          entityId: itemId,
          remoteUpdatedAt: itemRemoteUpd,
          localUpdatedAt: localItem?.updatedAt,
        )) {
          continue;
        }
        final exId = _str(m, 'exercise_id');
        await pullExerciseById(exId);
        await _db
            .into(_db.weekScheduleItems)
            .insertOnConflictUpdate(
              WeekScheduleItemsCompanion.insert(
                id: itemId,
                blockId: _str(m, 'block_id'),
                exerciseId: _resolvedExerciseId(exId),
                sourceWorkoutGroupId: Value(
                  _strOpt(m, 'source_workout_group_id'),
                ),
                sortOrder: Value(_intOpt(m, 'sort_order', 0)),
                sets: Value(_intOpt(m, 'sets', 0)),
                reps: Value(_intOpt(m, 'reps', 0)),
                repsText: Value(_strOpt(m, 'reps_text')),
                loadKg: Value(_dblOpt(m, 'load_kg')),
                needsDetail: Value(_bool(m, 'needs_detail')),
                restBetweenSetsSec: Value(
                  _intOpt(m, 'rest_between_sets_sec', 60),
                ),
                trainingMethodId: Value(_strOpt(m, 'training_method_id')),
                comboId: Value(_strOpt(m, 'combo_id')),
                updatedAt: Value(itemRemoteUpd),
              ),
            );
      }
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullWeekScheduleBlockById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullWeekScheduleItemById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('week_schedule_items')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd =
          _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final local = await (_db.select(
        _db.weekScheduleItems,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (await _shouldSkipRemoteEntityUpsertById(
        db: _db,
        entityType: 'week_schedule_item',
        entityId: id,
        remoteUpdatedAt: remoteUpd,
        localUpdatedAt: local?.updatedAt,
      )) {
        return;
      }
      final exId = _str(r, 'exercise_id');
      await pullExerciseById(exId);
      await _db
          .into(_db.weekScheduleItems)
          .insertOnConflictUpdate(
            WeekScheduleItemsCompanion.insert(
              id: _str(r, 'id'),
              blockId: _str(r, 'block_id'),
              exerciseId: _resolvedExerciseId(exId),
              sourceWorkoutGroupId: Value(
                _strOpt(r, 'source_workout_group_id'),
              ),
              sortOrder: Value(_intOpt(r, 'sort_order', 0)),
              sets: Value(_intOpt(r, 'sets', 0)),
              reps: Value(_intOpt(r, 'reps', 0)),
              repsText: Value(_strOpt(r, 'reps_text')),
              loadKg: Value(_dblOpt(r, 'load_kg')),
              needsDetail: Value(_bool(r, 'needs_detail')),
              restBetweenSetsSec: Value(
                _intOpt(r, 'rest_between_sets_sec', 60),
              ),
              trainingMethodId: Value(_strOpt(r, 'training_method_id')),
              comboId: Value(_strOpt(r, 'combo_id')),
              updatedAt: Value(remoteUpd),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullWeekScheduleItemById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  /// Pull pontual do planejamento semanal de um aluno para uma segunda-feira.
  /// Usado para reduzir divergência entre dispositivos quando o cache local está incompleto.
  Future<void> pullWeekScheduleForStudentWeek(
    String studentId, {
    required DateTime weekMonday,
  }) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    final mon = normalizeStoredWeekStartMonday(
      weekScheduleLocalCalendarDate(
        DateTime(weekMonday.year, weekMonday.month, weekMonday.day),
      ),
    );
    bool sameMonday(DateTime d) =>
        d.year == mon.year && d.month == mon.month && d.day == mon.day;

    _sync.beginDownload();
    try {
      final blocksRes = await c
          .from('week_schedule_blocks')
          .select()
          .eq('student_id', studentId);
      final allBlocks = (blocksRes as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final blocks = allBlocks.where((r) {
        final remoteMon = weekScheduleLocalCalendarDate(
          _ts(r['week_start_monday']),
        );
        return sameMonday(remoteMon);
      }).toList();

      final blockIds = <String>[];
      for (final r in blocks) {
        final id = _str(r, 'id');
        blockIds.add(id);
        final remoteUpd = _ts(r['updated_at']);
        final local = await (_db.select(
          _db.weekScheduleBlocks,
        )..where((x) => x.id.equals(id))).getSingleOrNull();
        if (await _shouldSkipRemoteEntityUpsertById(
          db: _db,
          entityType: 'week_schedule_block',
          entityId: id,
          remoteUpdatedAt: remoteUpd,
          localUpdatedAt: local?.updatedAt,
        )) {
          continue;
        }
        await _db
            .into(_db.weekScheduleBlocks)
            .insertOnConflictUpdate(
              WeekScheduleBlocksCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                weekStartMonday: weekScheduleLocalCalendarDate(
                  _ts(r['week_start_monday']),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(remoteUpd),
              ),
            );
      }

      for (final blockId in blockIds) {
        final itemsRes = await c
            .from('week_schedule_items')
            .select()
            .eq('block_id', blockId);
        final items = (itemsRes as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final r in items) {
          final id = _str(r, 'id');
          final remoteUpd =
              _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final local = await (_db.select(
            _db.weekScheduleItems,
          )..where((x) => x.id.equals(id))).getSingleOrNull();
          if (await _shouldSkipRemoteEntityUpsertById(
            db: _db,
            entityType: 'week_schedule_item',
            entityId: id,
            remoteUpdatedAt: remoteUpd,
            localUpdatedAt: local?.updatedAt,
          )) {
            continue;
          }
          final exId = _str(r, 'exercise_id');
          await pullExerciseById(exId);
          await _db
              .into(_db.weekScheduleItems)
              .insertOnConflictUpdate(
                WeekScheduleItemsCompanion.insert(
                  id: id,
                  blockId: _str(r, 'block_id'),
                  exerciseId: _resolvedExerciseId(exId),
                  sourceWorkoutGroupId: Value(
                    _strOpt(r, 'source_workout_group_id'),
                  ),
                  sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                  sets: Value(_intOpt(r, 'sets', 0)),
                  reps: Value(_intOpt(r, 'reps', 0)),
                  repsText: Value(_strOpt(r, 'reps_text')),
                  loadKg: Value(_dblOpt(r, 'load_kg')),
                  needsDetail: Value(_bool(r, 'needs_detail')),
                  restBetweenSetsSec: Value(
                    _intOpt(r, 'rest_between_sets_sec', 60),
                  ),
                  trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                  comboId: Value(_strOpt(r, 'combo_id')),
                  updatedAt: Value(remoteUpd),
                ),
              );
        }
      }

      // Além do planejamento, sincroniza também os treinos da semana visível.
      // Sem isso, um treino concluído em outro dispositivo podia ficar "aberto"
      // neste aparelho até algum evento realtime específico acontecer.
      final workoutsRes = await c
          .from('day_workouts')
          .select('id,status,day_date')
          .eq('student_id', studentId);
      final allWeekWorkouts = (workoutsRes as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((r) {
            final day = weekScheduleLocalCalendarDate(_ts(r['day_date']));
            return !day.isBefore(mon) &&
                day.isBefore(mon.add(const Duration(days: 7)));
          })
          .toList(growable: false);
      var cloudCompleted = 0;
      var cloudStarted = 0;
      var cloudProgrammed = 0;
      for (final r in allWeekWorkouts) {
        final st = (_strOpt(r, 'status') ?? '').trim().toLowerCase();
        if (st == 'completed') cloudCompleted++;
        if (st == 'started') cloudStarted++;
        if (st == 'programmed') cloudProgrammed++;
      }
      debugPrint(
        'SupabasePullSyncService week_pull student=$studentId '
        'week=${mon.toIso8601String()} cloud_workouts=${allWeekWorkouts.length} '
        'completed=$cloudCompleted started=$cloudStarted programmed=$cloudProgrammed',
      );
      for (final r in allWeekWorkouts) {
        final id = _str(r, 'id');
        await pullDayWorkoutById(id);
      }
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint(
        'SupabasePullSyncService pullWeekScheduleForStudentWeek: $e\n$st',
      );
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  /// Pull pontual do catálogo base (grupos musculares + exercícios).
  Future<void> pullExercisesCatalog() async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      await _pullMuscleGroups(c);
      await _pullExercises(c);
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullExercisesCatalog: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  /// Pull pontual do catálogo de grupos de treino (cabeçalho + linhas).
  Future<void> pullWorkoutGroupsCatalog() async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      _pullReferencedWorkoutGroupIds.clear();
      await _pullWorkoutGroups(c);
      await _pullWorkoutGroupExercises(c);
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullWorkoutGroupsCatalog: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullDayWorkoutById(String id) async {
    if (!supabaseAppEnabled) return;
    if (_sync.isDayWorkoutPullMuted) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('day_workouts').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final remoteStatus = _str(r, 'status');
      final remoteRevision = _remoteRevision(r);
      final remoteDeviceId = _remoteDeviceId(r);

      final tombstones = await _localDayWorkoutPullTombstones();
      final tomb = tombstones[id];
      if (!_remoteDayWorkoutStrictlyAfterTombstone(
        remoteUpdatedAt: remoteUpd,
        tombstone: tomb,
      )) {
        return;
      }

      final local = await (_db.select(
        _db.dayWorkouts,
      )..where((d) => d.id.equals(id))).getSingleOrNull();
      if (local != null && local.updatedAt.isAtSameMomentAs(remoteUpd)) {
        final remoteStatus = _str(r, 'status');
        final remoteStartedAt = r['started_at'] == null
            ? null
            : _ts(r['started_at']);
        final remoteCompletedAt = r['completed_at'] == null
            ? null
            : _ts(r['completed_at']);
        final remoteTimerResumeAt = r['timer_resume_at'] == null
            ? null
            : _ts(r['timer_resume_at']);
        final remoteWorkoutScore = _dblOpt(r, 'workout_score');
        final sameSnapshot =
            local.status == remoteStatus &&
            local.startedAt == remoteStartedAt &&
            local.completedAt == remoteCompletedAt &&
            local.timerResumeAt == remoteTimerResumeAt &&
            local.workoutScore == remoteWorkoutScore;
        if (sameSnapshot) {
          _sync.noteConnected();
          return;
        }
      }
      if (local != null &&
          local.status == 'cancelled' &&
          remoteStatus != 'cancelled' &&
          !_remoteDayWorkoutStrictlyAfterTombstone(
            remoteUpdatedAt: remoteUpd,
            tombstone: local.updatedAt,
          )) {
        return;
      }

      if (local != null) {
        final forceRemoteCompletion =
            remoteStatus == 'completed' && local.status != 'completed';
        final localWins = _localWinsConflictByVersion(
          localRevision: local.revision,
          remoteRevision: remoteRevision,
          localUpdatedAt: local.updatedAt,
          remoteUpdatedAt: remoteUpd,
          localDeviceId: local.lastModifiedByDeviceId,
          remoteDeviceId: remoteDeviceId,
        );
        if (localWins && !forceRemoteCompletion) {
          await _enqueueLocalRepush(
            _db,
            entityType: 'day_workout',
            entityId: id,
            reason: 'local_revision_wins_pull_day_workout',
          );
          return;
        }
        if (local.status == 'completed' && remoteStatus != 'completed') {
          final remoteCompletedAt = r['completed_at'] == null
              ? null
              : _ts(r['completed_at']);
          final localCompletedAt = local.completedAt;
          if (localCompletedAt != null &&
              (remoteCompletedAt == null ||
                  localCompletedAt.isAfter(
                    remoteCompletedAt.add(const Duration(seconds: 1)),
                  ))) {
            await _enqueueLocalRepush(
              _db,
              entityType: 'day_workout',
              entityId: id,
              reason: 'completed_local_wins_pull_day_workout',
            );
            return;
          }
        }
      }

      final preserveCompletion = _preserveLocalDayWorkoutCompletionFields(
        local: local,
        remoteStatus: remoteStatus,
      );
      final effectiveStatus = _dayWorkoutStatusForPullUpsert(
        local: local,
        remoteStatus: remoteStatus,
      );

      if (local != null &&
          local.updatedAt.isAfter(remoteUpd.add(const Duration(seconds: 3)))) {
        if (!preserveCompletion) {
          return;
        }
      }
      final latestPendingDayWorkoutAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout',
      );
      final latestPendingDayWorkoutExerciseAtById =
          await _pendingAuditLatestAtByEntity(_db, 'day_workout_exercise');
      if (local != null &&
          !(remoteStatus == 'completed' && local.status != 'completed')) {
        if (await _shouldSkipRemoteEntityUpsertById(
          db: _db,
          entityType: 'day_workout',
          entityId: id,
          remoteUpdatedAt: remoteUpd,
          localUpdatedAt: local.updatedAt,
          localRevision: local.revision,
          remoteRevision: remoteRevision,
          latestPendingAuditAtById: latestPendingDayWorkoutAtById,
        )) {
          return;
        }
      }

      await _db
          .into(_db.dayWorkouts)
          .insertOnConflictUpdate(
            DayWorkoutsCompanion.insert(
              id: _str(r, 'id'),
              studentId: _str(r, 'student_id'),
              dayDate: weekScheduleLocalCalendarDate(_ts(r['day_date'])),
              status: effectiveStatus,
              weekItemId: Value(_strOpt(r, 'week_item_id')),
              activeDurationSeconds: Value(
                preserveCompletion && local != null
                    ? local.activeDurationSeconds
                    : _intOpt(r, 'active_duration_seconds', 0),
              ),
              workoutScore: Value(
                preserveCompletion && local != null
                    ? local.workoutScore
                    : _dblOpt(r, 'workout_score'),
              ),
              startedAt: Value(
                preserveCompletion && local?.startedAt != null
                    ? local!.startedAt
                    : (r['started_at'] == null ? null : _ts(r['started_at'])),
              ),
              completedAt: Value(
                preserveCompletion && local != null
                    ? local.completedAt
                    : (r['completed_at'] == null
                          ? null
                          : _ts(r['completed_at'])),
              ),
              timerResumeAt: Value(
                preserveCompletion
                    ? null
                    : (r['timer_resume_at'] == null
                          ? null
                          : _ts(r['timer_resume_at'])),
              ),
              createdAt: Value(_ts(r['created_at'])),
              updatedAt: Value(remoteUpd),
              sourceWorkoutGroupId: Value(
                _strOpt(r, 'source_workout_group_id'),
              ),
              watchCaloriesKcal: Value(_dblOpt(r, 'watch_calories_kcal')),
              watchAvgHeartRateBpm: Value(
                r['watch_avg_heart_rate_bpm'] == null
                    ? null
                    : _int(r, 'watch_avg_heart_rate_bpm'),
              ),
              revision: Value(remoteRevision),
              lastModifiedByDeviceId: Value(remoteDeviceId),
              syncStatus: const Value('synced'),
              deletedAt: Value(
                r['deleted_at'] == null ? null : _ts(r['deleted_at']),
              ),
            ),
          );

      final linesRes = await c
          .from('day_workout_exercises')
          .select()
          .eq('day_workout_id', id);
      final lines = linesRes as List<dynamic>;
      for (final e in lines) {
        final m = Map<String, dynamic>.from(e as Map);
        final lineId = _str(m, 'id');
        final lineRemoteUpd =
            _tsOpt(m['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final localLine = await (_db.select(
          _db.dayWorkoutExercises,
        )..where((x) => x.id.equals(lineId))).getSingleOrNull();
        if (localLine != null &&
            localLine.updatedAt.isAtSameMomentAs(lineRemoteUpd)) {
          continue;
        }
        if (localLine != null &&
            localLine.updatedAt.isAfter(
              lineRemoteUpd.add(const Duration(seconds: 3)),
            )) {
          final remoteProgressAhead = _remoteLineProgressAheadOfLocal(
            local: localLine,
            remoteRow: m,
          );
          if (_localWinsConflictByVersion(
                localRevision: localLine.revision,
                remoteRevision: _remoteRevision(m),
                localUpdatedAt: localLine.updatedAt,
                remoteUpdatedAt: lineRemoteUpd,
                localDeviceId: localLine.lastModifiedByDeviceId,
                remoteDeviceId: _remoteDeviceId(m),
              ) &&
              !remoteProgressAhead) {
            await _enqueueLocalRepush(
              _db,
              entityType: 'day_workout_exercise',
              entityId: lineId,
              reason: 'local_revision_wins_pull_line',
            );
            continue;
          }
          await _tryMergeRemotePerformedSetsWhenLocalLooksNewer(
            db: _db,
            local: localLine,
            remoteRow: m,
            remoteUpd: lineRemoteUpd,
          );
          continue;
        }
        if (localLine != null &&
            _shouldPreserveLocalPerformedSetsSnapshot(
              local: localLine,
              remoteRow: m,
              remoteUpdatedAt: lineRemoteUpd,
            )) {
          continue;
        }
        final remoteProgressAhead = localLine != null
            ? _remoteLineProgressAheadOfLocal(local: localLine, remoteRow: m)
            : false;
        final hasPendingLineQueue = await _hasPendingSyncQueueForEntity(
          db: _db,
          entityType: 'day_workout_exercise',
          entityId: lineId,
        );
        if (localLine != null && hasPendingLineQueue && !remoteProgressAhead) {
          continue;
        }
        if (localLine != null &&
            !remoteProgressAhead &&
            await _shouldSkipRemoteEntityUpsertById(
              db: _db,
              entityType: 'day_workout_exercise',
              entityId: lineId,
              remoteUpdatedAt: lineRemoteUpd,
              localUpdatedAt: localLine.updatedAt,
              localRevision: localLine.revision,
              remoteRevision: _remoteRevision(m),
              latestPendingAuditAtById: latestPendingDayWorkoutExerciseAtById,
            )) {
          continue;
        }
        final exId = _str(m, 'exercise_id');
        await pullExerciseById(exId);
        final performedJson = _performedSetsJsonForPullUpsert(
          local: localLine,
          remoteRow: m,
        );
        final exerciseScore = _exerciseScoreForPullUpsert(
          local: localLine,
          remoteRow: m,
          performedSetsJson: performedJson,
        );
        await _db
            .into(_db.dayWorkoutExercises)
            .insertOnConflictUpdate(
              DayWorkoutExercisesCompanion.insert(
                id: lineId,
                dayWorkoutId: _str(m, 'day_workout_id'),
                exerciseId: _resolvedExerciseId(exId),
                sortOrder: Value(_intOpt(m, 'sort_order', 0)),
                sets: _int(m, 'sets'),
                reps: _int(m, 'reps'),
                repsText: Value(_strOpt(m, 'reps_text')),
                loadKg: Value(_dblOpt(m, 'load_kg')),
                exerciseScore: Value(exerciseScore),
                performedSetsJson: Value(performedJson),
                restBetweenSetsSec: Value(
                  _intOpt(m, 'rest_between_sets_sec', 60),
                ),
                trainingMethodId: Value(_strOpt(m, 'training_method_id')),
                comboId: Value(_strOpt(m, 'combo_id')),
                updatedAt: Value(lineRemoteUpd),
                revision: Value(_remoteRevision(m)),
                lastModifiedByDeviceId: Value(_remoteDeviceId(m)),
                syncStatus: const Value('synced'),
                deletedAt: Value(
                  m['deleted_at'] == null ? null : _ts(m['deleted_at']),
                ),
              ),
            );
      }
      // Não remova linhas locais por "diferença de snapshot" neste pull.
      // Em dispositivos reais, pulls parciais/intermitentes podiam chegar sem
      // todas as linhas e causar sumiço temporário de exercícios/séries na UI.
      //
      // Exclusão efetiva continua sendo tratada por:
      // - auditoria local + push; e
      // - pull pontual por id (quando linha realmente não existe).
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullDayWorkoutById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullRecentCompletedDayWorkoutsForStudent(
    String studentId, {
    int limit = 40,
  }) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final normalizedLimit = limit < 1 ? 1 : (limit > 120 ? 120 : limit);
      final res = await c
          .from('day_workouts')
          .select('id')
          .eq('student_id', studentId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .order('updated_at', ascending: false)
          .limit(normalizedLimit);
      final rows = res as List<dynamic>;
      final ids = <String>[];
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = _strOpt(m, 'id');
        if (id == null || id.isEmpty) continue;
        ids.add(id);
      }
      _sync.noteConnected();
      for (final id in ids) {
        await pullDayWorkoutById(id);
      }
    } catch (e, st) {
      debugPrint(
        'SupabasePullSyncService pullRecentCompletedDayWorkoutsForStudent: $e\n$st',
      );
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullDayWorkoutExerciseById(String id) async {
    if (!supabaseAppEnabled) return;
    if (_sync.isDayWorkoutPullMuted) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('day_workout_exercises')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) {
        final local = await (_db.select(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(id))).getSingleOrNull();
        if (local != null) {
          final latestPendingLineAtById = await _pendingAuditLatestAtByEntity(
            _db,
            'day_workout_exercise',
          );
          // Se não há pendência local, remoção remota vence.
          if (!latestPendingLineAtById.containsKey(id)) {
            await (_db.delete(
              _db.dayWorkoutExercises,
            )..where((e) => e.id.equals(id))).go();
          }
        }
        _sync.noteConnected();
        return;
      }
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd =
          _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final remoteRevision = _remoteRevision(r);
      final remoteDeviceId = _remoteDeviceId(r);

      final localDeletes = await _localDeletesById('day_workout_exercise');
      final delAt = localDeletes[id];
      if (_localDeleteWinsOverRemote(
        localDeleteAt: delAt,
        remoteUpdatedAt: remoteUpd,
      )) {
        return;
      }

      final local = await (_db.select(
        _db.dayWorkoutExercises,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (local != null && local.updatedAt.isAtSameMomentAs(remoteUpd)) {
        final remotePerformed = (_strOpt(r, 'performed_sets_json') ?? '')
            .trim();
        final localPerformed = (local.performedSetsJson ?? '').trim();
        final remoteLoad = _dblOpt(r, 'load_kg');
        final remoteScore = _dblOpt(r, 'exercise_score');
        final sameSnapshot =
            localPerformed == remotePerformed &&
            local.loadKg == remoteLoad &&
            local.exerciseScore == remoteScore;
        if (sameSnapshot) {
          _sync.noteConnected();
          return;
        }
      }
      if (local != null &&
          local.updatedAt.isAfter(remoteUpd.add(const Duration(seconds: 3)))) {
        final remoteProgressAhead = _remoteLineProgressAheadOfLocal(
          local: local,
          remoteRow: r,
        );
        if (_localWinsConflictByVersion(
              localRevision: local.revision,
              remoteRevision: remoteRevision,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remoteUpd,
              localDeviceId: local.lastModifiedByDeviceId,
              remoteDeviceId: remoteDeviceId,
            ) &&
            !remoteProgressAhead) {
          await _enqueueLocalRepush(
            _db,
            entityType: 'day_workout_exercise',
            entityId: id,
            reason: 'local_revision_wins_pull_line_by_id',
          );
          _sync.noteConnected();
          return;
        }
        final merged = await _tryMergeRemotePerformedSetsWhenLocalLooksNewer(
          db: _db,
          local: local,
          remoteRow: r,
          remoteUpd: remoteUpd,
        );
        if (merged) {
          _sync.noteConnected();
        }
        return;
      }
      if (local != null &&
          _shouldPreserveLocalPerformedSetsSnapshot(
            local: local,
            remoteRow: r,
            remoteUpdatedAt: remoteUpd,
          )) {
        _sync.noteConnected();
        return;
      }
      final remoteProgressAhead = local != null
          ? _remoteLineProgressAheadOfLocal(local: local, remoteRow: r)
          : false;
      final hasPendingLineQueue = await _hasPendingSyncQueueForEntity(
        db: _db,
        entityType: 'day_workout_exercise',
        entityId: id,
      );
      if (local != null && hasPendingLineQueue && !remoteProgressAhead) {
        _sync.noteConnected();
        return;
      }
      final latestPendingLineAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout_exercise',
      );
      if (local != null &&
          !remoteProgressAhead &&
          await _shouldSkipRemoteEntityUpsertById(
            db: _db,
            entityType: 'day_workout_exercise',
            entityId: id,
            remoteUpdatedAt: remoteUpd,
            localUpdatedAt: local.updatedAt,
            localRevision: local.revision,
            remoteRevision: remoteRevision,
            latestPendingAuditAtById: latestPendingLineAtById,
          )) {
        _sync.noteConnected();
        return;
      }

      final rawExId = _str(r, 'exercise_id');
      final dayWorkoutId = _str(r, 'day_workout_id');
      final hasParent = await _ensureLocalDayWorkoutExists(dayWorkoutId);
      if (!hasParent) {
        debugPrint(
          'SupabasePullSyncService pullDayWorkoutExerciseById: '
          'day_workout ausente id=$dayWorkoutId; linha id=$id ignorada.',
        );
        return;
      }
      final resolvedExId = await _ensureLocalExerciseExists(rawExId);
      if (resolvedExId == null) {
        debugPrint(
          'SupabasePullSyncService pullDayWorkoutExerciseById: '
          'exercise ausente raw=$rawExId; linha id=$id ignorada.',
        );
        return;
      }
      final performedJson = _performedSetsJsonForPullUpsert(
        local: local,
        remoteRow: r,
      );
      final exerciseScore = _exerciseScoreForPullUpsert(
        local: local,
        remoteRow: r,
        performedSetsJson: performedJson,
      );
      await _db
          .into(_db.dayWorkoutExercises)
          .insertOnConflictUpdate(
            DayWorkoutExercisesCompanion.insert(
              id: _str(r, 'id'),
              dayWorkoutId: dayWorkoutId,
              exerciseId: resolvedExId,
              sortOrder: Value(_intOpt(r, 'sort_order', 0)),
              sets: _int(r, 'sets'),
              reps: _int(r, 'reps'),
              repsText: Value(_strOpt(r, 'reps_text')),
              loadKg: Value(_dblOpt(r, 'load_kg')),
              exerciseScore: Value(exerciseScore),
              performedSetsJson: Value(performedJson),
              restBetweenSetsSec: Value(
                _intOpt(r, 'rest_between_sets_sec', 60),
              ),
              trainingMethodId: Value(_strOpt(r, 'training_method_id')),
              comboId: Value(_strOpt(r, 'combo_id')),
              updatedAt: Value(remoteUpd),
              revision: Value(remoteRevision),
              lastModifiedByDeviceId: Value(remoteDeviceId),
              syncStatus: const Value('synced'),
              deletedAt: Value(
                r['deleted_at'] == null ? null : _ts(r['deleted_at']),
              ),
            ),
          );
      _sync.noteConnected();
    } catch (e, st) {
      debugPrint('SupabasePullSyncService pullDayWorkoutExerciseById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<SupabasePullTableResult> _pullMuscleGroups(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('muscle_group');
      final rows = await _pullTableRowsPaged(c, 'muscle_groups');
      rows.sort((a, b) => _str(a, 'id').compareTo(_str(b, 'id')));
      var localList = await _db.select(_db.muscleGroups).get();
      var localUpd = {for (final g in localList) g.id: g.updatedAt};
      final full = _pullFullCloud;
      var written = 0;
      var skippedNewer = 0;
      var skippedRedirect = 0;
      for (final r in rows) {
        final remoteId = _str(r, 'id');
        final name = _str(r, 'name').trim();
        final norm = normalizeMuscleGroupName(name);
        MuscleGroupEntity? sameNameLocal;
        for (final g in localList) {
          if (normalizeMuscleGroupName(g.name) == norm) {
            sameNameLocal = g;
            break;
          }
        }
        if (sameNameLocal != null && sameNameLocal.id != remoteId) {
          _pullMuscleGroupIdRedirect[remoteId] = sameNameLocal.id;
          skippedRedirect++;
          continue;
        }
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[remoteId];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[remoteId])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.muscleGroups)
            .insertOnConflictUpdate(
              MuscleGroupsCompanion.insert(
                id: remoteId,
                name: name.isEmpty ? 'Sem nome' : name,
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
        final ins = await (_db.select(
          _db.muscleGroups,
        )..where((g) => g.id.equals(remoteId))).getSingle();
        localUpd[ins.id] = ins.updatedAt;
        localList.removeWhere((g) => g.id == ins.id);
        localList.add(ins);
      }
      return SupabasePullTableResult(
        'muscle_groups',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        skippedRedirect,
      );
    } catch (e) {
      return SupabasePullTableResult('muscle_groups', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullExercises(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('exercise');
      final rows = await _pullTableRowsPaged(c, 'exercises');
      rows.sort((a, b) => _str(a, 'id').compareTo(_str(b, 'id')));
      var localList = await _db.select(_db.exercises).get();
      var localUpd = {for (final e in localList) e.id: e.updatedAt};
      final full = _pullFullCloud;
      var written = 0;
      var skippedNewer = 0;
      var skippedRedirect = 0;
      for (final r in rows) {
        final remoteId = _str(r, 'id');
        final name = _str(r, 'name').trim();
        final norm = normalizeExerciseName(name);
        ExerciseEntity? sameNameLocal;
        for (final e in localList) {
          if (normalizeExerciseName(e.name) == norm) {
            sameNameLocal = e;
            break;
          }
        }
        if (sameNameLocal != null && sameNameLocal.id != remoteId) {
          _pullExerciseIdRedirect[remoteId] = sameNameLocal.id;
          skippedRedirect++;
          continue;
        }
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[remoteId];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[remoteId])) {
          skippedNewer++;
          continue;
        }
        final rawMg = _str(r, 'muscle_group_id');
        final muscleGroupId = _pullMuscleGroupIdRedirect[rawMg] ?? rawMg;
        await _db
            .into(_db.exercises)
            .insertOnConflictUpdate(
              ExercisesCompanion.insert(
                id: remoteId,
                name: name.isEmpty ? 'Sem nome' : name,
                muscleGroupId: muscleGroupId,
                videoUrl: Value(_strOpt(r, 'video_url')),
                alternativeNote: Value(_strOpt(r, 'alternative_note')),
                alternativeVideoUrl: Value(_strOpt(r, 'alternative_video_url')),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
        final ins = await (_db.select(
          _db.exercises,
        )..where((e) => e.id.equals(remoteId))).getSingle();
        localUpd[ins.id] = ins.updatedAt;
        localList.removeWhere((e) => e.id == ins.id);
        localList.add(ins);
      }
      return SupabasePullTableResult(
        'exercises',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        skippedRedirect,
      );
    } catch (e) {
      return SupabasePullTableResult('exercises', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullGyms(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('gym');
      final rows = await _pullTableRowsPaged(c, 'gyms');
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.gyms).get()) x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.gyms)
            .insertOnConflictUpdate(
              GymsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                cnpj: _str(r, 'cnpj'),
                street: _str(r, 'street'),
                number: _str(r, 'number'),
                complement: Value(_strOpt(r, 'complement')),
                district: _str(r, 'district'),
                city: _str(r, 'city'),
                stateUf: _str(r, 'state_uf'),
                cep: _str(r, 'cep'),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'gyms',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('gyms', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullPersonals(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” personais apagados localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('personal');
      List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'personals');
      } else {
        final s = _session!;
        if (s.isPersonalTrainer) {
          final pid = s.personalId;
          if (pid == null) {
            rows = [];
          } else {
            rows = _rows(
              await c
                  .from('personals')
                  .select()
                  .eq('id', pid)
                  .timeout(const Duration(seconds: 90)),
            );
          }
        } else if (s.isStudent) {
          final sid = s.studentId;
          if (sid == null) {
            rows = [];
          } else {
            final tid = await _remoteStudentTrainerId(c, sid);
            if (tid == null) {
              rows = [];
            } else {
              rows = _rows(
                await c
                    .from('personals')
                    .select()
                    .eq('id', tid)
                    .timeout(const Duration(seconds: 90)),
              );
            }
          }
        } else {
          rows = [];
        }
      }
      final full = _pullFullCloud;
      final personalUpd = {
        for (final x in await _db.select(_db.personals).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, personalUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.personals)
            .insertOnConflictUpdate(
              PersonalsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                cpf: _str(r, 'cpf'),
                professionalRegistry: _str(r, 'professional_registry'),
                street: _str(r, 'street'),
                number: _str(r, 'number'),
                complement: Value(_strOpt(r, 'complement')),
                city: _str(r, 'city'),
                stateUf: _str(r, 'state_uf'),
                cep: Value(_strOpt(r, 'cep')),
                email: _str(r, 'email'),
                phoneCommercial: Value(_strOpt(r, 'phone_commercial')),
                phoneMobile: Value(_strOpt(r, 'phone_mobile')),
                mustChangePassword: Value(
                  _bool(r, 'must_change_password', d: true),
                ),
                passwordHash: Value(_strOpt(r, 'password_hash')),
                isAdmin: Value(_bool(r, 'is_admin')),
                accessTier: Value(_strOpt(r, 'access_tier') ?? 'legacy'),
                maxStudentsCap: Value(
                  r['max_students_cap'] == null
                      ? null
                      : (r['max_students_cap'] as num).toInt(),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'personals',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('personals', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullStudents(SupabaseClient c) async {
    try {
      List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'students');
      } else {
        final s = _session!;
        if (s.isPersonalTrainer) {
          final pid = s.personalId;
          if (pid == null) {
            rows = [];
          } else {
            rows = _rows(
              await c
                  .from('students')
                  .select()
                  .eq('created_by_personal_id', pid)
                  .timeout(const Duration(seconds: 90)),
            );
          }
        } else if (s.isStudent) {
          final sid = s.studentId;
          if (sid == null) {
            rows = [];
          } else {
            rows = _rows(
              await c
                  .from('students')
                  .select()
                  .eq('id', sid)
                  .timeout(const Duration(seconds: 90)),
            );
          }
        } else {
          rows = [];
        }
      }
      _pullScopeStudentIds = [for (final r in rows) _str(r, 'id')];
      final full = _pullFullCloud;
      final studentUpd = {
        for (final x in await _db.select(_db.students).get()) x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), studentUpd[id])) {
          skippedNewer++;
          continue;
        }
        final bd = r['birth_date'];
        final effArchived = _pullStudentIsArchivedFromRow(r);
        await _db
            .into(_db.students)
            .insertOnConflictUpdate(
              StudentsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                isArchived: Value(effArchived),
                archivedAt: Value(
                  _pullStudentArchivedAtFromRow(
                    r,
                    effectiveArchived: effArchived,
                  ),
                ),
                email: Value(_strOpt(r, 'email')),
                goal: Value(_strOpt(r, 'goal')),
                cpf: Value(_strOpt(r, 'cpf')),
                birthDate: Value(bd == null ? null : _ts(bd)),
                street: Value(_strOpt(r, 'street')),
                number: Value(_strOpt(r, 'number')),
                complement: Value(_strOpt(r, 'complement')),
                district: Value(_strOpt(r, 'district')),
                city: Value(_strOpt(r, 'city')),
                stateUf: Value(_strOpt(r, 'state_uf')),
                cep: Value(_strOpt(r, 'cep')),
                phoneCommercial: Value(_strOpt(r, 'phone_commercial')),
                phoneMobile: Value(_strOpt(r, 'phone_mobile')),
                mustChangePassword: Value(
                  _bool(r, 'must_change_password', d: true),
                ),
                passwordHash: Value(_strOpt(r, 'password_hash')),
                createdByPersonalId: Value(
                  _strOpt(r, 'created_by_personal_id'),
                ),
                anamneseCompleted: Value(
                  _bool(r, 'anamnese_completed', d: true),
                ),
                accessTier: Value(_strOpt(r, 'access_tier') ?? 'legacy'),
                premiumPlanExpiresAt: Value(
                  _tsOpt(r['premium_plan_expires_at']),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'students',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('students', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullStudentGyms(SupabaseClient c) async {
    try {
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'student_gyms');
      } else if (_pullScopeStudentIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'student_gyms',
          'student_id',
          _pullScopeStudentIds,
        );
      }
      var written = 0;
      for (final r in rows) {
        await _db
            .into(_db.studentGyms)
            .insertOnConflictUpdate(
              StudentGymsCompanion.insert(
                studentId: _str(r, 'student_id'),
                gymId: _str(r, 'gym_id'),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'student_gyms',
        rows.length,
        true,
        null,
        written,
        0,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('student_gyms', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullTrainingMethods(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('training_method');
      final rows = await _pullTableRowsPaged(c, 'training_methods');
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.trainingMethods).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.trainingMethods)
            .insertOnConflictUpdate(
              TrainingMethodsCompanion.insert(
                id: id,
                method: _str(r, 'method'),
                description: _str(r, 'description'),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'training_methods',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult(
        'training_methods',
        0,
        false,
        e.toString(),
      );
    }
  }

  Future<SupabasePullTableResult> _pullWorkoutGroups(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('workout_group');
      final rows = await _pullWorkoutGroupRowsForSession(c);
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.workoutGroups).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        _pullReferencedWorkoutGroupIds.add(id);
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.workoutGroups)
            .insertOnConflictUpdate(
              WorkoutGroupsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                description: _str(r, 'description'),
                createdByPersonalId: Value(
                  _strOpt(r, 'created_by_personal_id'),
                ),
                isShared: Value(_bool(r, 'is_shared', d: false)),
                revision: Value(_intOpt(r, 'revision', 0)),
                lastModifiedByDeviceId: Value(
                  _strOpt(r, 'last_modified_by_device_id'),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
                deletedAt: Value(_tsOpt(r['deleted_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'workout_groups',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('workout_groups', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullWorkoutGroupExercises(
    SupabaseClient c,
  ) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('workout_group_exercise');
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'workout_group_exercises');
      } else if (_session?.isPersonalTrainer == true) {
        rows = _pullReferencedWorkoutGroupIds.isEmpty
            ? []
            : await _selectInChunks(
                c,
                'workout_group_exercises',
                'workout_group_id',
                _pullReferencedWorkoutGroupIds.toList(),
              );
      } else if (_pullReferencedWorkoutGroupIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'workout_group_exercises',
          'workout_group_id',
          _pullReferencedWorkoutGroupIds.toList(),
        );
      }
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.workoutGroupExercises).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      var rowWriteErrors = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        try {
          await _db
              .into(_db.workoutGroupExercises)
              .insertOnConflictUpdate(
                WorkoutGroupExercisesCompanion.insert(
                  id: id,
                  workoutGroupId: _str(r, 'workout_group_id'),
                  exerciseId: _resolvedExerciseId(_str(r, 'exercise_id')),
                  sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                  lastLoadKg: Value(_dblOpt(r, 'last_load_kg')),
                  lastReps: Value(
                    r['last_reps'] == null ? null : _int(r, 'last_reps'),
                  ),
                  lastRepsText: Value(_strOpt(r, 'last_reps_text')),
                  lastSets: Value(
                    r['last_sets'] == null ? null : _int(r, 'last_sets'),
                  ),
                  restBetweenSetsSec: Value(
                    _intOpt(r, 'rest_between_sets_sec', 60),
                  ),
                  trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                  comboId: Value(_strOpt(r, 'combo_id')),
                  updatedAt: Value(remoteUpd),
                ),
              );
          written++;
        } catch (e, st) {
          rowWriteErrors++;
          debugPrint(
            'SupabasePullSyncService workout_group_exercises id=$id: $e\n$st',
          );
        }
      }
      return SupabasePullTableResult(
        'workout_group_exercises',
        rows.length,
        true,
        rowWriteErrors > 0
            ? '$rowWriteErrors linha(s) não gravadas (ex.: exercício ou grupo ausente no SQLite).'
            : null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult(
        'workout_group_exercises',
        0,
        false,
        e.toString(),
      );
    }
  }

  Future<SupabasePullTableResult> _pullWeekBlocks(SupabaseClient c) async {
    try {
      // Evita “ressuscitar” blocos apagados localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('week_schedule_block');
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'week_schedule_blocks');
      } else if (_pullScopeStudentIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'week_schedule_blocks',
          'student_id',
          _pullScopeStudentIds,
        );
      }
      _pullScopeBlockIds = [for (final r in rows) _str(r, 'id')];
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.weekScheduleBlocks).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd = _ts(r['updated_at']);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.weekScheduleBlocks)
            .insertOnConflictUpdate(
              WeekScheduleBlocksCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                weekStartMonday: weekScheduleLocalCalendarDate(
                  _ts(r['week_start_monday']),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'week_schedule_blocks',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult(
        'week_schedule_blocks',
        0,
        false,
        e.toString(),
      );
    }
  }

  Future<SupabasePullTableResult> _pullWeekItems(
    SupabaseClient c, {
    required bool trackWorkoutGroupRefs,
  }) async {
    try {
      // Evita “ressuscitar” itens apagados localmente quando o delete ainda não chegou à nuvem.
      // (tombstone = último audit delete).
      final localDeletes = await _localDeletesById('week_schedule_item');
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'week_schedule_items');
      } else if (_pullScopeBlockIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'week_schedule_items',
          'block_id',
          _pullScopeBlockIds,
        );
      }
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.weekScheduleItems).get())
          x.id: x.updatedAt,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        if (trackWorkoutGroupRefs) {
          _noteWorkoutGroupRef(_strOpt(r, 'source_workout_group_id'));
        }
        final id = _str(r, 'id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.weekScheduleItems)
            .insertOnConflictUpdate(
              WeekScheduleItemsCompanion.insert(
                id: id,
                blockId: _str(r, 'block_id'),
                exerciseId: _resolvedExerciseId(_str(r, 'exercise_id')),
                sourceWorkoutGroupId: Value(
                  _strOpt(r, 'source_workout_group_id'),
                ),
                sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                sets: Value(_intOpt(r, 'sets', 0)),
                reps: Value(_intOpt(r, 'reps', 0)),
                repsText: Value(_strOpt(r, 'reps_text')),
                loadKg: Value(_dblOpt(r, 'load_kg')),
                needsDetail: Value(_bool(r, 'needs_detail')),
                restBetweenSetsSec: Value(
                  _intOpt(r, 'rest_between_sets_sec', 60),
                ),
                trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                comboId: Value(_strOpt(r, 'combo_id')),
                updatedAt: Value(remoteUpd),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'week_schedule_items',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult(
        'week_schedule_items',
        0,
        false,
        e.toString(),
      );
    }
  }

  Future<SupabasePullTableResult> _pullDayWorkouts(
    SupabaseClient c, {
    required bool trackWorkoutGroupRefs,
  }) async {
    try {
      // Evita “ressuscitar” treinos apagados/cancelados localmente (audit delete+cancel).
      final dayWorkoutTombstones = await _localDayWorkoutPullTombstones();
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'day_workouts');
      } else if (_pullScopeStudentIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'day_workouts',
          'student_id',
          _pullScopeStudentIds,
        );
      }
      if (!_pullFullCloud) {
        _pullScopeDayWorkoutIds = [for (final r in rows) _str(r, 'id')];
      }
      final full = _pullFullCloud;
      final latestPendingDayWorkoutAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout',
      );
      final localDayWorkouts = await _db.select(_db.dayWorkouts).get();
      final localDayWorkoutById = {for (final x in localDayWorkouts) x.id: x};
      final dayWUpd = {for (final x in localDayWorkouts) x.id: x.updatedAt};
      final localCancelledAt = <String, DateTime>{};
      for (final x in localDayWorkouts) {
        if (x.status == 'cancelled') {
          localCancelledAt[x.id] = x.updatedAt;
        }
      }
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        if (trackWorkoutGroupRefs) {
          _noteWorkoutGroupRef(_strOpt(r, 'source_workout_group_id'));
        }
        final id = _str(r, 'id');
        final remoteUpd = _ts(r['updated_at']);
        final remoteRevision = _remoteRevision(r);
        final tomb = dayWorkoutTombstones[id];
        if (!_remoteDayWorkoutStrictlyAfterTombstone(
          remoteUpdatedAt: remoteUpd,
          tombstone: tomb,
        )) {
          skippedNewer++;
          continue;
        }
        // “Cancelado” localmente também não pode ser “ressuscitado” por pull.
        // Se o aparelho cancelou (deleteProgrammedDayWorkout / deleteWeekScheduleItem),
        // o Supabase pode ainda estar com status antigo; não sobrepor enquanto o cancel local for mais novo.
        final localCancelAt = localCancelledAt[id];
        final remoteStatus = _str(r, 'status');
        if (localCancelAt != null &&
            remoteStatus != 'cancelled' &&
            !_remoteDayWorkoutStrictlyAfterTombstone(
              remoteUpdatedAt: remoteUpd,
              tombstone: localCancelAt,
            )) {
          skippedNewer++;
          continue;
        }
        if (_hasRecentPendingLocalAudit(
              entityId: id,
              remoteUpdatedAt: remoteUpd,
              latestPendingAuditAtById: latestPendingDayWorkoutAtById,
            ) &&
            _adminKeepLocalNewer(full, remoteUpd, dayWUpd[id])) {
          skippedNewer++;
          continue;
        }
        final localRow = localDayWorkoutById[id];
        final forceRemoteCompletion =
            remoteStatus == 'completed' &&
            localRow != null &&
            localRow.status != 'completed';
        if (localRow != null &&
            _localWinsConflictByVersion(
              localRevision: localRow.revision,
              remoteRevision: remoteRevision,
              localUpdatedAt: localRow.updatedAt,
              remoteUpdatedAt: remoteUpd,
              localDeviceId: localRow.lastModifiedByDeviceId,
              remoteDeviceId: _remoteDeviceId(r),
            ) &&
            !forceRemoteCompletion) {
          await _enqueueLocalRepush(
            _db,
            entityType: 'day_workout',
            entityId: id,
            reason: 'local_revision_wins_bulk_pull_day_workout',
          );
          skippedNewer++;
          continue;
        }
        final preserveCompletion = _preserveLocalDayWorkoutCompletionFields(
          local: localRow,
          remoteStatus: remoteStatus,
        );
        final effectiveStatus = _dayWorkoutStatusForPullUpsert(
          local: localRow,
          remoteStatus: remoteStatus,
        );
        await _db
            .into(_db.dayWorkouts)
            .insertOnConflictUpdate(
              DayWorkoutsCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                // Mesmo critério do planejamento: dia civil local (evita treino “hoje” cair no dia seguinte).
                dayDate: weekScheduleLocalCalendarDate(_ts(r['day_date'])),
                status: effectiveStatus,
                weekItemId: Value(_strOpt(r, 'week_item_id')),
                activeDurationSeconds: Value(
                  preserveCompletion && localRow != null
                      ? localRow.activeDurationSeconds
                      : _intOpt(r, 'active_duration_seconds', 0),
                ),
                workoutScore: Value(
                  preserveCompletion && localRow != null
                      ? localRow.workoutScore
                      : _dblOpt(r, 'workout_score'),
                ),
                startedAt: Value(
                  preserveCompletion && localRow?.startedAt != null
                      ? localRow!.startedAt
                      : (r['started_at'] == null
                            ? null
                            : _ts(r['started_at'])),
                ),
                completedAt: Value(
                  preserveCompletion && localRow != null
                      ? localRow.completedAt
                      : (r['completed_at'] == null
                            ? null
                            : _ts(r['completed_at'])),
                ),
                timerResumeAt: Value(
                  preserveCompletion
                      ? null
                      : (r['timer_resume_at'] == null
                            ? null
                            : _ts(r['timer_resume_at'])),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
                sourceWorkoutGroupId: Value(
                  _strOpt(r, 'source_workout_group_id'),
                ),
                watchCaloriesKcal: Value(_dblOpt(r, 'watch_calories_kcal')),
                watchAvgHeartRateBpm: Value(
                  r['watch_avg_heart_rate_bpm'] == null
                      ? null
                      : _int(r, 'watch_avg_heart_rate_bpm'),
                ),
                revision: Value(remoteRevision),
                lastModifiedByDeviceId: Value(_remoteDeviceId(r)),
                syncStatus: const Value('synced'),
                deletedAt: Value(
                  r['deleted_at'] == null ? null : _ts(r['deleted_at']),
                ),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'day_workouts',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('day_workouts', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullDayWorkoutExercises(
    SupabaseClient c,
  ) async {
    try {
      // Evita “ressuscitar” linhas apagadas localmente quando o delete ainda não chegou à nuvem.
      final localDeletes = await _localDeletesById('day_workout_exercise');
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = await _pullTableRowsPaged(c, 'day_workout_exercises');
      } else if (_pullScopeDayWorkoutIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'day_workout_exercises',
          'day_workout_id',
          _pullScopeDayWorkoutIds,
        );
      }
      final localLinesById = {
        for (final x in await _db.select(_db.dayWorkoutExercises).get())
          x.id: x,
      };
      final localExerciseIds = {
        for (final x in await _db.select(_db.exercises).get()) x.id,
      };
      var written = 0;
      var skippedNewer = 0;
      var rowWriteErrors = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final dayWorkoutId = _str(r, 'day_workout_id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final delAt = localDeletes[id];
        if (_localDeleteWinsOverRemote(
          localDeleteAt: delAt,
          remoteUpdatedAt: remoteUpd,
        )) {
          skippedNewer++;
          continue;
        }
        final localLine = localLinesById[id];
        if (localLine != null &&
            _shouldPreserveLocalPerformedSetsSnapshot(
              local: localLine,
              remoteRow: r,
              remoteUpdatedAt: remoteUpd,
            )) {
          skippedNewer++;
          continue;
        }
        final remoteProgressAhead = localLine != null
            ? _remoteLineProgressAheadOfLocal(local: localLine, remoteRow: r)
            : false;
        final hasPendingLineQueue = localLine != null
            ? await _hasPendingSyncQueueForEntity(
                db: _db,
                entityType: 'day_workout_exercise',
                entityId: id,
              )
            : false;
        if (localLine != null && hasPendingLineQueue && !remoteProgressAhead) {
          skippedNewer++;
          continue;
        }
        if (localLine != null &&
            localLine.updatedAt.isAfter(
              remoteUpd.add(const Duration(seconds: 3)),
            )) {
          if (_localWinsConflictByVersion(
                localRevision: localLine.revision,
                remoteRevision: _remoteRevision(r),
                localUpdatedAt: localLine.updatedAt,
                remoteUpdatedAt: remoteUpd,
                localDeviceId: localLine.lastModifiedByDeviceId,
                remoteDeviceId: _remoteDeviceId(r),
              ) &&
              !remoteProgressAhead) {
            await _enqueueLocalRepush(
              _db,
              entityType: 'day_workout_exercise',
              entityId: id,
              reason: 'local_revision_wins_bulk_pull_line',
            );
            skippedNewer++;
            continue;
          }
          final merged = await _tryMergeRemotePerformedSetsWhenLocalLooksNewer(
            db: _db,
            local: localLine,
            remoteRow: r,
            remoteUpd: remoteUpd,
          );
          if (merged) {
            written++;
          } else {
            skippedNewer++;
          }
          continue;
        }
        if (localLine != null &&
            !remoteProgressAhead &&
            await _shouldSkipRemoteEntityUpsertById(
              db: _db,
              entityType: 'day_workout_exercise',
              entityId: id,
              remoteUpdatedAt: remoteUpd,
              localUpdatedAt: localLine.updatedAt,
              localRevision: localLine.revision,
              remoteRevision: _remoteRevision(r),
            )) {
          skippedNewer++;
          continue;
        }
        final hasParent = await _ensureLocalDayWorkoutExists(dayWorkoutId);
        if (!hasParent) {
          rowWriteErrors++;
          continue;
        }
        final rawExId = _str(r, 'exercise_id');
        final resolvedExId = await _ensureLocalExerciseExists(
          rawExId,
          localExerciseIds: localExerciseIds,
        );
        if (resolvedExId == null) {
          rowWriteErrors++;
          continue;
        }
        final performedJson = _performedSetsJsonForPullUpsert(
          local: localLine,
          remoteRow: r,
        );
        final exerciseScore = _exerciseScoreForPullUpsert(
          local: localLine,
          remoteRow: r,
          performedSetsJson: performedJson,
        );
        try {
          await _db
              .into(_db.dayWorkoutExercises)
              .insertOnConflictUpdate(
                DayWorkoutExercisesCompanion.insert(
                  id: id,
                  dayWorkoutId: dayWorkoutId,
                  exerciseId: resolvedExId,
                  sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                  sets: _int(r, 'sets'),
                  reps: _int(r, 'reps'),
                  repsText: Value(_strOpt(r, 'reps_text')),
                  loadKg: Value(_dblOpt(r, 'load_kg')),
                  exerciseScore: Value(exerciseScore),
                  performedSetsJson: Value(performedJson),
                  restBetweenSetsSec: Value(
                    _intOpt(r, 'rest_between_sets_sec', 60),
                  ),
                  trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                  comboId: Value(_strOpt(r, 'combo_id')),
                  updatedAt: Value(remoteUpd),
                  revision: Value(_remoteRevision(r)),
                  lastModifiedByDeviceId: Value(_remoteDeviceId(r)),
                  syncStatus: const Value('synced'),
                  deletedAt: Value(
                    r['deleted_at'] == null ? null : _ts(r['deleted_at']),
                  ),
                ),
              );
          written++;
        } catch (e, st) {
          rowWriteErrors++;
          debugPrint(
            'SupabasePullSyncService day_workout_exercises id=$id: $e\n$st',
          );
        }
      }
      return SupabasePullTableResult(
        'day_workout_exercises',
        rows.length,
        true,
        rowWriteErrors > 0
            ? '$rowWriteErrors linha(s) não gravadas (ex.: exercício ou treino do dia ausente no SQLite).'
            : null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult(
        'day_workout_exercises',
        0,
        false,
        e.toString(),
      );
    }
  }

  Future<SupabasePullTableResult> _pullAuditLogs(SupabaseClient c) async {
    try {
      // Só é chamado com [_pullFullCloud] a partir de [pullAllFromRemote].
      final rows = await _pullTableRowsPaged(c, 'audit_logs');
      final full = _pullFullCloud;
      final localAt = {
        for (final x in await _db.select(_db.auditLogs).get()) x.id: x.at,
      };
      var written = 0;
      var skippedNewer = 0;
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteAt = _ts(r['at']);
        if (_adminKeepLocalNewer(full, remoteAt, localAt[id])) {
          skippedNewer++;
          continue;
        }
        await _db
            .into(_db.auditLogs)
            .insertOnConflictUpdate(
              AuditLogsCompanion.insert(
                id: id,
                at: Value(remoteAt),
                action: _str(r, 'action'),
                entityType: _str(r, 'entity_type'),
                entityId: Value(_strOpt(r, 'entity_id')),
                payloadJson: Value(_strOpt(r, 'payload_json')),
                deviceId: Value(_strOpt(r, 'device_id')),
                personalId: Value(_strOpt(r, 'personal_id')),
                studentId: Value(_strOpt(r, 'student_id')),
              ),
            );
        written++;
      }
      return SupabasePullTableResult(
        'audit_logs',
        rows.length,
        true,
        null,
        written,
        skippedNewer,
        0,
      );
    } catch (e) {
      return SupabasePullTableResult('audit_logs', 0, false, e.toString());
    }
  }
}
