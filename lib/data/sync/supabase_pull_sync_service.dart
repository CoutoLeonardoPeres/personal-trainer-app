import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/app_session.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../exercise_name_similarity.dart';
import '../local/app_database.dart';

class SupabasePullTableResult {
  SupabasePullTableResult(this.tableName, this.rowCount, this.ok, [this.error]);

  final String tableName;
  final int rowCount;
  final bool ok;
  final String? error;
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
    b.writeln('Conexão: ${connectionOk ? "OK" : "FALHOU"} — $connectionMessage');
    b.writeln();
    for (final t in tables) {
      b.writeln('[${t.ok ? "OK" : "ERRO"}] ${t.tableName}: ${t.rowCount} linha(s)');
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

DateTime? _tsOpt(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.parse(v);
  return DateTime.parse(v.toString());
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
    return s == null || s.isAdminPersonal;
  }

  final Set<String> _pullReferencedWorkoutGroupIds = {};
  List<String> _pullScopeStudentIds = [];
  List<String> _pullScopeBlockIds = [];
  List<String> _pullScopeDayWorkoutIds = [];

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
      await Supabase.instance.client.from('muscle_groups').select('id').limit(1);
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
        tables.add(await _pullDayWorkouts(client, trackWorkoutGroupRefs: false));
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

  Future<SupabasePullTableResult> _pullMuscleGroups(SupabaseClient c) async {
    try {
      final rows = _rows(await c.from('muscle_groups').select());
      rows.sort((a, b) => _str(a, 'id').compareTo(_str(b, 'id')));
      var localList = await _db.select(_db.muscleGroups).get();
      var localUpd = {for (final g in localList) g.id: g.updatedAt};
      final full = _pullFullCloud;
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
          continue;
        }
        final remoteUpd = _ts(r['updated_at']);
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[remoteId])) {
          continue;
        }
        await _db.into(_db.muscleGroups).insertOnConflictUpdate(
              MuscleGroupsCompanion.insert(
                id: remoteId,
                name: name.isEmpty ? 'Sem nome' : name,
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
        localList = await _db.select(_db.muscleGroups).get();
        localUpd = {for (final g in localList) g.id: g.updatedAt};
      }
      return SupabasePullTableResult('muscle_groups', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('muscle_groups', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullExercises(SupabaseClient c) async {
    try {
      final rows = _rows(await c.from('exercises').select());
      rows.sort((a, b) => _str(a, 'id').compareTo(_str(b, 'id')));
      var localList = await _db.select(_db.exercises).get();
      var localUpd = {for (final e in localList) e.id: e.updatedAt};
      final full = _pullFullCloud;
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
          continue;
        }
        final remoteUpd = _ts(r['updated_at']);
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[remoteId])) {
          continue;
        }
        final rawMg = _str(r, 'muscle_group_id');
        final muscleGroupId = _pullMuscleGroupIdRedirect[rawMg] ?? rawMg;
        await _db.into(_db.exercises).insertOnConflictUpdate(
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
        localList = await _db.select(_db.exercises).get();
        localUpd = {for (final e in localList) e.id: e.updatedAt};
      }
      return SupabasePullTableResult('exercises', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('exercises', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullGyms(SupabaseClient c) async {
    try {
      final rows = _rows(await c.from('gyms').select());
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.gyms).get()) x.id: x.updatedAt,
      };
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), localUpd[id])) {
          continue;
        }
        await _db.into(_db.gyms).insertOnConflictUpdate(
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
      }
      return SupabasePullTableResult('gyms', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('gyms', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullPersonals(SupabaseClient c) async {
    try {
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
        for (final x in await _db.select(_db.personals).get()) x.id: x.updatedAt,
      };
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), personalUpd[id])) {
          continue;
        }
        await _db.into(_db.personals).insertOnConflictUpdate(
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
                mustChangePassword: Value(_bool(r, 'must_change_password', d: true)),
                passwordHash: Value(_strOpt(r, 'password_hash')),
                isAdmin: Value(_bool(r, 'is_admin')),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
      }
      return SupabasePullTableResult('personals', rows.length, true);
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
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), studentUpd[id])) {
          continue;
        }
        final bd = r['birth_date'];
        await _db.into(_db.students).insertOnConflictUpdate(
              StudentsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
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
                mustChangePassword: Value(_bool(r, 'must_change_password', d: true)),
                passwordHash: Value(_strOpt(r, 'password_hash')),
                createdByPersonalId: Value(_strOpt(r, 'created_by_personal_id')),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
      }
      return SupabasePullTableResult('students', rows.length, true);
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
      for (final r in rows) {
        await _db.into(_db.studentGyms).insertOnConflictUpdate(
              StudentGymsCompanion.insert(
                studentId: _str(r, 'student_id'),
                gymId: _str(r, 'gym_id'),
              ),
            );
      }
      return SupabasePullTableResult('student_gyms', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('student_gyms', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullTrainingMethods(SupabaseClient c) async {
    try {
      final rows = _rows(await c.from('training_methods').select());
      final full = _pullFullCloud;
      final localUpd = {
        for (final x in await _db.select(_db.trainingMethods).get())
          x.id: x.updatedAt,
      };
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), localUpd[id])) {
          continue;
        }
        await _db.into(_db.trainingMethods).insertOnConflictUpdate(
              TrainingMethodsCompanion.insert(
                id: id,
                method: _str(r, 'method'),
                description: _str(r, 'description'),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
      }
      return SupabasePullTableResult('training_methods', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('training_methods', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullWorkoutGroups(SupabaseClient c) async {
    try {
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
        for (final x in await _db.select(_db.workoutGroups).get()) x.id: x.updatedAt,
      };
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), localUpd[id])) {
          continue;
        }
        await _db.into(_db.workoutGroups).insertOnConflictUpdate(
              WorkoutGroupsCompanion.insert(
                id: id,
                name: _str(r, 'name'),
                description: _str(r, 'description'),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
      }
      return SupabasePullTableResult('workout_groups', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('workout_groups', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullWorkoutGroupExercises(SupabaseClient c) async {
    try {
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
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          continue;
        }
        await _db.into(_db.workoutGroupExercises).insertOnConflictUpdate(
              WorkoutGroupExercisesCompanion.insert(
                id: id,
                workoutGroupId: _str(r, 'workout_group_id'),
                exerciseId: _resolvedExerciseId(_str(r, 'exercise_id')),
                sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                lastLoadKg: Value(_dblOpt(r, 'last_load_kg')),
                lastReps: Value(r['last_reps'] == null ? null : _int(r, 'last_reps')),
                lastRepsText: Value(_strOpt(r, 'last_reps_text')),
                lastSets: Value(r['last_sets'] == null ? null : _int(r, 'last_sets')),
                restBetweenSetsSec: Value(_intOpt(r, 'rest_between_sets_sec', 60)),
                trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                comboId: Value(_strOpt(r, 'combo_id')),
                updatedAt: Value(remoteUpd),
              ),
            );
      }
      return SupabasePullTableResult('workout_group_exercises', rows.length, true);
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
      for (final r in rows) {
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), localUpd[id])) {
          continue;
        }
        await _db.into(_db.weekScheduleBlocks).insertOnConflictUpdate(
              WeekScheduleBlocksCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                weekStartMonday:
                    weekScheduleLocalCalendarDate(_ts(r['week_start_monday'])),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
              ),
            );
      }
      return SupabasePullTableResult('week_schedule_blocks', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('week_schedule_blocks', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullWeekItems(
    SupabaseClient c, {
    required bool trackWorkoutGroupRefs,
  }) async {
    try {
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
      for (final r in rows) {
        if (trackWorkoutGroupRefs) {
          _noteWorkoutGroupRef(_strOpt(r, 'source_workout_group_id'));
        }
        final id = _str(r, 'id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          continue;
        }
        await _db.into(_db.weekScheduleItems).insertOnConflictUpdate(
              WeekScheduleItemsCompanion.insert(
                id: id,
                blockId: _str(r, 'block_id'),
                exerciseId: _resolvedExerciseId(_str(r, 'exercise_id')),
                sourceWorkoutGroupId: Value(_strOpt(r, 'source_workout_group_id')),
                sortOrder: Value(_intOpt(r, 'sort_order', 0)),
                sets: Value(_intOpt(r, 'sets', 0)),
                reps: Value(_intOpt(r, 'reps', 0)),
                repsText: Value(_strOpt(r, 'reps_text')),
                loadKg: Value(_dblOpt(r, 'load_kg')),
                needsDetail: Value(_bool(r, 'needs_detail')),
                restBetweenSetsSec: Value(_intOpt(r, 'rest_between_sets_sec', 60)),
                trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                comboId: Value(_strOpt(r, 'combo_id')),
                updatedAt: Value(remoteUpd),
              ),
            );
      }
      return SupabasePullTableResult('week_schedule_items', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('week_schedule_items', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullDayWorkouts(
    SupabaseClient c, {
    required bool trackWorkoutGroupRefs,
  }) async {
    try {
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
      final dayWUpd = {
        for (final x in await _db.select(_db.dayWorkouts).get()) x.id: x.updatedAt,
      };
      for (final r in rows) {
        if (trackWorkoutGroupRefs) {
          _noteWorkoutGroupRef(_strOpt(r, 'source_workout_group_id'));
        }
        final id = _str(r, 'id');
        if (_adminKeepLocalNewer(full, _ts(r['updated_at']), dayWUpd[id])) {
          continue;
        }
        await _db.into(_db.dayWorkouts).insertOnConflictUpdate(
              DayWorkoutsCompanion.insert(
                id: id,
                studentId: _str(r, 'student_id'),
                // Mesmo critério do planejamento: dia civil local (evita treino “hoje” cair no dia seguinte).
                dayDate: weekScheduleLocalCalendarDate(_ts(r['day_date'])),
                status: _str(r, 'status'),
                weekItemId: Value(_strOpt(r, 'week_item_id')),
                activeDurationSeconds: Value(_intOpt(r, 'active_duration_seconds', 0)),
                workoutScore: Value(_dblOpt(r, 'workout_score')),
                startedAt: Value(r['started_at'] == null ? null : _ts(r['started_at'])),
                completedAt: Value(r['completed_at'] == null ? null : _ts(r['completed_at'])),
                timerResumeAt: Value(
                  r['timer_resume_at'] == null ? null : _ts(r['timer_resume_at']),
                ),
                createdAt: Value(_ts(r['created_at'])),
                updatedAt: Value(_ts(r['updated_at'])),
                sourceWorkoutGroupId: Value(_strOpt(r, 'source_workout_group_id')),
                watchCaloriesKcal: Value(_dblOpt(r, 'watch_calories_kcal')),
                watchAvgHeartRateBpm: Value(
                  r['watch_avg_heart_rate_bpm'] == null
                      ? null
                      : _int(r, 'watch_avg_heart_rate_bpm'),
                ),
              ),
            );
      }
      return SupabasePullTableResult('day_workouts', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('day_workouts', 0, false, e.toString());
    }
  }

  Future<SupabasePullTableResult> _pullDayWorkoutExercises(SupabaseClient c) async {
    try {
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
      final localUpd = {
        for (final x in await _db.select(_db.dayWorkoutExercises).get())
          x.id: x.updatedAt,
      };
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteUpd =
            _tsOpt(r['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (_adminKeepLocalNewer(full, remoteUpd, localUpd[id])) {
          continue;
        }
        await _db.into(_db.dayWorkoutExercises).insertOnConflictUpdate(
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
                restBetweenSetsSec: Value(_intOpt(r, 'rest_between_sets_sec', 60)),
                trainingMethodId: Value(_strOpt(r, 'training_method_id')),
                comboId: Value(_strOpt(r, 'combo_id')),
                updatedAt: Value(remoteUpd),
              ),
            );
      }
      return SupabasePullTableResult('day_workout_exercises', rows.length, true);
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
      for (final r in rows) {
        final id = _str(r, 'id');
        final remoteAt = _ts(r['at']);
        if (_adminKeepLocalNewer(full, remoteAt, localAt[id])) {
          continue;
        }
        await _db.into(_db.auditLogs).insertOnConflictUpdate(
              AuditLogsCompanion.insert(
                id: id,
                at: Value(remoteAt),
                action: _str(r, 'action'),
                entityType: _str(r, 'entity_type'),
                entityId: Value(_strOpt(r, 'entity_id')),
                payloadJson: Value(_strOpt(r, 'payload_json')),
              ),
            );
      }
      return SupabasePullTableResult('audit_logs', rows.length, true);
    } catch (e) {
      return SupabasePullTableResult('audit_logs', 0, false, e.toString());
    }
  }
}
