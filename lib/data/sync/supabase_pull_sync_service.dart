import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/app_session.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../../core/utils/student_archive_display_utils.dart';
import '../exercise_name_similarity.dart';
import '../local/app_database.dart';

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
  return d.isAfter(remoteUpdatedAt.subtract(const Duration(seconds: 2)));
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

bool _hasRecentPendingLocalAudit({
  required String entityId,
  required DateTime remoteUpdatedAt,
  required Map<String, DateTime> latestPendingAuditAtById,
}) {
  final pendingAt = latestPendingAuditAtById[entityId];
  if (pendingAt == null) return false;
  // Só considera "pendente local vence" quando a auditoria local é realmente
  // contemporânea/mais nova que a remota.
  return pendingAt.isAfter(remoteUpdatedAt.subtract(const Duration(seconds: 2)));
}

Future<bool> _shouldSkipRemoteEntityUpsertById({
  required AppDatabase db,
  required String entityType,
  required String entityId,
  required DateTime remoteUpdatedAt,
  DateTime? localUpdatedAt,
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
  final latestPending =
      latestPendingAuditAtById ??
      await _pendingAuditLatestAtByEntity(db, entityType);
  if (!_hasRecentPendingLocalAudit(
    entityId: entityId,
    remoteUpdatedAt: remoteUpdatedAt,
    latestPendingAuditAtById: latestPending,
  )) {
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
      final part = _rows(await c.from(table).select().inFilter(column, chunk));
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

    _sync.beginDownload();
    try {
      await Supabase.instance.client
          .from('muscle_groups')
          .select('id')
          .limit(1);
    } catch (e) {
      _sync.endDownload();
      return SupabasePullReport(
        connectionOk: false,
        connectionMessage: e.toString(),
        tables: tables,
        startedAt: started,
        finishedAt: DateTime.now(),
      );
    }

    final client = Supabase.instance.client;

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

  Future<void> pullDayWorkoutById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c.from('day_workouts').select().eq('id', id).limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd = _ts(r['updated_at']);
      final remoteStatus = _str(r, 'status');

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
      if (local != null &&
          local.status == 'cancelled' &&
          remoteStatus != 'cancelled' &&
          !_remoteDayWorkoutStrictlyAfterTombstone(
            remoteUpdatedAt: remoteUpd,
            tombstone: local.updatedAt,
          )) {
        return;
      }

      final latestPendingDayWorkoutAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout',
      );
      if (local != null &&
          _hasRecentPendingLocalAudit(
            entityId: id,
            remoteUpdatedAt: remoteUpd,
            latestPendingAuditAtById: latestPendingDayWorkoutAtById,
          ) &&
          local.updatedAt.isAfter(remoteUpd)) {
        return;
      }
      final latestPendingDayWorkoutExerciseAtById =
          await _pendingAuditLatestAtByEntity(_db, 'day_workout_exercise');

      await _db
          .into(_db.dayWorkouts)
          .insertOnConflictUpdate(
            DayWorkoutsCompanion.insert(
              id: _str(r, 'id'),
              studentId: _str(r, 'student_id'),
              dayDate: weekScheduleLocalCalendarDate(_ts(r['day_date'])),
              status: remoteStatus,
              weekItemId: Value(_strOpt(r, 'week_item_id')),
              activeDurationSeconds: Value(
                _intOpt(r, 'active_duration_seconds', 0),
              ),
              workoutScore: Value(_dblOpt(r, 'workout_score')),
              startedAt: Value(
                r['started_at'] == null ? null : _ts(r['started_at']),
              ),
              completedAt: Value(
                r['completed_at'] == null ? null : _ts(r['completed_at']),
              ),
              timerResumeAt: Value(
                r['timer_resume_at'] == null ? null : _ts(r['timer_resume_at']),
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
        if (await _shouldSkipRemoteEntityUpsertById(
          db: _db,
          entityType: 'day_workout_exercise',
          entityId: lineId,
          remoteUpdatedAt: lineRemoteUpd,
          localUpdatedAt: localLine?.updatedAt,
          latestPendingAuditAtById: latestPendingDayWorkoutExerciseAtById,
        )) {
          continue;
        }
        final exId = _str(m, 'exercise_id');
        await pullExerciseById(exId);
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
                exerciseScore: Value(_dblOpt(m, 'exercise_score')),
                performedSetsJson: Value(_strOpt(m, 'performed_sets_json')),
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
      debugPrint('SupabasePullSyncService pullDayWorkoutById: $e\n$st');
      _sync.noteDisconnected();
      _sync.noteBackgroundPushError(e);
    } finally {
      _sync.endDownload();
    }
  }

  Future<void> pullDayWorkoutExerciseById(String id) async {
    if (!supabaseAppEnabled) return;
    final c = Supabase.instance.client;
    _sync.beginDownload();
    try {
      final res = await c
          .from('day_workout_exercises')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isEmpty) return;
      final r = Map<String, dynamic>.from(list.first as Map);
      final remoteUpd =
          _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

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
      final latestPendingLineAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout_exercise',
      );
      if (local != null &&
          _hasRecentPendingLocalAudit(
            entityId: id,
            remoteUpdatedAt: remoteUpd,
            latestPendingAuditAtById: latestPendingLineAtById,
          ) &&
          local.updatedAt.isAfter(remoteUpd)) {
        return;
      }

      final exId = _str(r, 'exercise_id');
      await pullExerciseById(exId);
      await _db
          .into(_db.dayWorkoutExercises)
          .insertOnConflictUpdate(
            DayWorkoutExercisesCompanion.insert(
              id: _str(r, 'id'),
              dayWorkoutId: _str(r, 'day_workout_id'),
              exerciseId: _resolvedExerciseId(exId),
              sortOrder: Value(_intOpt(r, 'sort_order', 0)),
              sets: _int(r, 'sets'),
              reps: _int(r, 'reps'),
              repsText: Value(_strOpt(r, 'reps_text')),
              loadKg: Value(_dblOpt(r, 'load_kg')),
              exerciseScore: Value(_dblOpt(r, 'exercise_score')),
              performedSetsJson: Value(_strOpt(r, 'performed_sets_json')),
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
      final rows = _rows(await c.from('muscle_groups').select());
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
        localList = await _db.select(_db.muscleGroups).get();
        localUpd = {for (final g in localList) g.id: g.updatedAt};
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
      final rows = _rows(await c.from('exercises').select());
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
        localList = await _db.select(_db.exercises).get();
        localUpd = {for (final e in localList) e.id: e.updatedAt};
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
      final rows = _rows(await c.from('gyms').select());
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
        rows = _rows(await c.from('personals').select());
      } else {
        final s = _session!;
        if (s.isPersonalTrainer) {
          final pid = s.personalId;
          if (pid == null) {
            rows = [];
          } else {
            rows = _rows(await c.from('personals').select().eq('id', pid));
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
              rows = _rows(await c.from('personals').select().eq('id', tid));
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
        rows = _rows(await c.from('students').select());
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
                  .eq('created_by_personal_id', pid),
            );
          }
        } else if (s.isStudent) {
          final sid = s.studentId;
          if (sid == null) {
            rows = [];
          } else {
            rows = _rows(await c.from('students').select().eq('id', sid));
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
        rows = _rows(await c.from('student_gyms').select());
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
      final rows = _rows(await c.from('training_methods').select());
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
      final List<Map<String, dynamic>> rows;
      if (_pullFullCloud) {
        rows = _rows(await c.from('workout_groups').select());
      } else if (_session?.isPersonalTrainer == true) {
        // Personal: todos os modelos de grupo (cadastro), não só os já agendados.
        rows = _rows(await c.from('workout_groups').select());
      } else if (_pullReferencedWorkoutGroupIds.isEmpty) {
        rows = [];
      } else {
        rows = await _selectInChunks(
          c,
          'workout_groups',
          'id',
          _pullReferencedWorkoutGroupIds.toList(),
        );
      }
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.workoutGroups).get())
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
            .into(_db.workoutGroups)
            .insertOnConflictUpdate(
              WorkoutGroupsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                description: _str(r, 'description'),
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
        rows = _rows(await c.from('workout_group_exercises').select());
      } else if (_session?.isPersonalTrainer == true) {
        rows = _rows(await c.from('workout_group_exercises').select());
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
        rows = _rows(await c.from('week_schedule_blocks').select());
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
        rows = _rows(await c.from('week_schedule_items').select());
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
        rows = _rows(await c.from('day_workouts').select());
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
        await _db
            .into(_db.dayWorkouts)
            .insertOnConflictUpdate(
              DayWorkoutsCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                // Mesmo critério do planejamento: dia civil local (evita treino “hoje” cair no dia seguinte).
                dayDate: weekScheduleLocalCalendarDate(_ts(r['day_date'])),
                status: remoteStatus,
                weekItemId: Value(_strOpt(r, 'week_item_id')),
                activeDurationSeconds: Value(
                  _intOpt(r, 'active_duration_seconds', 0),
                ),
                workoutScore: Value(_dblOpt(r, 'workout_score')),
                startedAt: Value(
                  r['started_at'] == null ? null : _ts(r['started_at']),
                ),
                completedAt: Value(
                  r['completed_at'] == null ? null : _ts(r['completed_at']),
                ),
                timerResumeAt: Value(
                  r['timer_resume_at'] == null
                      ? null
                      : _ts(r['timer_resume_at']),
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
        rows = _rows(await c.from('day_workout_exercises').select());
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
      final full = _pullFullCloud;
      final latestPendingLineAtById = await _pendingAuditLatestAtByEntity(
        _db,
        'day_workout_exercise',
      );
      final localUpd = {
        for (final x in await _db.select(_db.dayWorkoutExercises).get())
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
        if (_hasRecentPendingLocalAudit(
              entityId: id,
              remoteUpdatedAt: remoteUpd,
              latestPendingAuditAtById: latestPendingLineAtById,
            ) &&
            _adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          skippedNewer++;
          continue;
        }
        try {
          await _db
              .into(_db.dayWorkoutExercises)
              .insertOnConflictUpdate(
                DayWorkoutExercisesCompanion.insert(
                  id: id,
                  dayWorkoutId: _str(r, 'day_workout_id'),
                  exerciseId: _resolvedExerciseId(_str(r, 'exercise_id')),
                  sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                  sets: _int(r, 'sets'),
                  reps: _int(r, 'reps'),
                  repsText: Value(_strOpt(r, 'reps_text')),
                  loadKg: Value(_dblOpt(r, 'load_kg')),
                  exerciseScore: Value(_dblOpt(r, 'exercise_score')),
                  performedSetsJson: Value(_strOpt(r, 'performed_sets_json')),
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
      final rows = _rows(await c.from('audit_logs').select());
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
