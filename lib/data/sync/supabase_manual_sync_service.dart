import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/access/permission_service.dart';
import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'supabase_catalog_cloud_reconcile.dart';
import 'supabase_push_diff.dart';
import 'supabase_table_mappers.dart';

/// Resultado do ping REST.
class SupabaseConnectionTestResult {
  SupabaseConnectionTestResult({
    required this.ok,
    required this.message,
    this.elapsedMs,
  });

  final bool ok;
  final String message;
  final int? elapsedMs;
}

/// Uma linha do relatório por tabela.
class SupabaseTablePushResult {
  SupabaseTablePushResult({
    required this.tableName,
    required this.rowCount,
    required this.ok,
    this.errorMessage,
    this.pushLikelyChangedOnCloud,
    this.pushLikelyAlreadyAligned,
  });

  final String tableName;
  final int rowCount;
  final bool ok;
  final String? errorMessage;

  /// Estimativa antes do upsert: linhas que parecem novas ou com `updated_at` local mais recente que a nuvem.
  final int? pushLikelyChangedOnCloud;

  /// Estimativa: já alinhadas (mesmo ts ou par student_gyms existente).
  final int? pushLikelyAlreadyAligned;
}

/// Relatório completo: teste + cada tabela.
class SupabaseManualSyncReport {
  SupabaseManualSyncReport({
    required this.connectionTest,
    required this.tables,
    required this.startedAt,
    required this.finishedAt,
  });

  final SupabaseConnectionTestResult connectionTest;
  final List<SupabaseTablePushResult> tables;
  final DateTime startedAt;
  final DateTime finishedAt;

  int get successTableCount => tables.where((t) => t.ok).length;
  int get totalRows => tables.fold(0, (a, t) => a + t.rowCount);

  String toReportText() {
    final buf = StringBuffer();
    buf.writeln('=== Supabase ===');
    buf.writeln(
      'Teste de conexão: ${connectionTest.ok ? "OK" : "FALHOU"} — ${connectionTest.message}',
    );
    if (connectionTest.elapsedMs != null) {
      buf.writeln('Latência: ${connectionTest.elapsedMs} ms');
    }
    buf.writeln();
    buf.writeln('Tabelas (${tables.length}):');
    for (final t in tables) {
      final status = t.ok ? 'OK' : 'ERRO';
      buf.write(
        '  [$status] ${t.tableName}: ${t.rowCount} linha(s) enviada(s) (upsert)',
      );
      final ch = t.pushLikelyChangedOnCloud;
      final al = t.pushLikelyAlreadyAligned;
      if (ch != null && al != null) {
        buf.write(
          ' — ~$ch provável(is) alteração(ões) na nuvem, ~$al já alinhada(s)',
        );
      }
      buf.writeln();
      if (t.errorMessage != null && t.errorMessage!.isNotEmpty) {
        buf.writeln('      → ${t.errorMessage}');
      }
    }
    buf.writeln();
    buf.writeln(
      'Resumo: $successTableCount/${tables.length} tabelas sem erro, $totalRows linhas enviadas (upsert).',
    );
    if (successTableCount < tables.length) {
      buf.writeln(
        'Aviso: há tabelas em erro — a contagem de linhas pode ser parcial (chunks interrompidos).',
      );
    }
    buf.writeln('Início: ${startedAt.toIso8601String()}');
    buf.writeln('Fim: ${finishedAt.toIso8601String()}');
    return buf.toString();
  }
}

/// Teste de conexão + envio forçado de todo o SQLite para o Postgres (ordem FK).
class SupabaseManualSyncService {
  SupabaseManualSyncService(this._db, this._sync);

  final AppDatabase _db;
  final SupabaseSyncController _sync;

  Future<bool> _studentMayPushCatalog(AppSession? session) async {
    final s = session;
    if (s == null || !s.isStudent) return false;
    final sid = s.studentId;
    if (sid == null) return false;
    final row = await (_db.select(
      _db.students,
    )..where((x) => x.id.equals(sid))).getSingleOrNull();
    if (row == null) return false;
    final perms = PermissionService(session: s, student: row);
    return perms.studentCadastroMuscleExerciseGymGroup;
  }

  static const int _chunkSize = 350;

  /// Mensagem extra quando a API responde 401 / JWT inválido (chave ou URL erradas).
  static String explainHttpAuthFailure(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    final looks401 =
        lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('pgrst301');
    if (!looks401) return rawMessage;
    return '$rawMessage\n\n'
        '—\n'
        'Dicas para 401 / não autorizado:\n'
        '• Use --dart-define=SUPABASE_ANON_KEY=<JWT anon> (começa com eyJ…). '
        'Painel: Settings → API → aba Legacy API keys → anon public.\n'
        '• A chave sb_publishable_… pode falhar neste cliente: o SDK envia o mesmo '
        'valor em Authorization: Bearer, e o PostgREST espera um JWT nesse header.\n'
        '• Confirme a URL: --dart-define=SUPABASE_URL=https://<ref>.supabase.co '
        '(o mesmo projeto da chave).\n'
        '• Não use chave secret (sb_secret_…) nem service_role no Personal Gym.';
  }

  static Future<SupabaseConnectionTestResult> testConnectionOnly() async {
    if (!supabaseAppEnabled) {
      return SupabaseConnectionTestResult(
        ok: false,
        message:
            'Personal Gym sem Supabase ativo. Opções: (1) --dart-define=SUPABASE_ANON_KEY=<JWT eyJ…> '
            'e opcionalmente SUPABASE_URL; (2) Configurações → Nuvem → guardar anon JWT + URL e '
            'reiniciar o Personal Gym por completo. Não use sb_publishable_… como se fosse anon — use o JWT '
            'em Settings → API → Legacy API keys.',
      );
    }
    final sw = Stopwatch()..start();
    try {
      await Supabase.instance.client
          .from('muscle_groups')
          .select('id')
          .limit(1);
      sw.stop();
      return SupabaseConnectionTestResult(
        ok: true,
        message: 'API respondeu.',
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      final raw = e.toString();
      return SupabaseConnectionTestResult(
        ok: false,
        message: explainHttpAuthFailure(raw),
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
  }

  static bool _pushFullCloud(AppSession? s) {
    final x = s;
    return x == null || x.hasFullOrgAccess;
  }

  static bool _pushAsStudent(AppSession? s) => s != null && s.isStudent;

  /// Alunos permitidos no envio conforme o perfil da sessão (admin = todos no SQLite).
  Future<Set<String>> _allowedStudentIdsForPush(AppSession? session) async {
    if (_pushFullCloud(session)) {
      return (await _db.select(_db.students).get()).map((e) => e.id).toSet();
    }
    final s = session!;
    if (s.isPersonalTrainer) {
      final pid = s.personalId;
      if (pid == null) return {};
      return (await _db.select(_db.students).get())
          .where((e) => e.createdByPersonalId == pid)
          .map((e) => e.id)
          .toSet();
    }
    if (s.isStudent) {
      final sid = s.studentId;
      if (sid == null) return {};
      return {sid};
    }
    return {};
  }

  Future<SupabaseManualSyncReport> testConnectionAndPushAll({
    AppSession? session,
  }) async {
    final startedAt = DateTime.now();
    final tables = <SupabaseTablePushResult>[];

    final ping = await testConnectionOnly();
    if (!ping.ok) {
      return SupabaseManualSyncReport(
        connectionTest: ping,
        tables: tables,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
      );
    }

    final client = Supabase.instance.client;
    _sync.beginUpload();
    try {
      await reconcileLocalCatalogWithCloud(_db, client);

      final full = _pushFullCloud(session);
      final asStudent = _pushAsStudent(session);
      final studentMayCatalog = await _studentMayPushCatalog(session);
      final restrictCatalogTables = asStudent && !studentMayCatalog;
      final allowedStudents = await _allowedStudentIdsForPush(session);

      final muscleRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.muscleGroups).get())
                .map(supabaseMuscleGroup)
                .toList();
      final exerciseRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.exercises).get())
                .map(supabaseExercise)
                .toList();
      final gymRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.gyms).get()).map(supabaseGym).toList();

      var personalRows = (await _db.select(_db.personals).get())
          .map(supabasePersonal)
          .toList();
      if (!full) {
        final s = session!;
        if (s.isPersonalTrainer) {
          final pid = s.personalId;
          personalRows = pid == null
              ? []
              : personalRows.where((m) => m['id'] == pid).toList();
        } else if (s.isStudent) {
          final sid = s.studentId;
          if (sid == null) {
            personalRows = [];
          } else {
            final st = await (_db.select(
              _db.students,
            )..where((x) => x.id.equals(sid))).getSingleOrNull();
            final tid = st?.createdByPersonalId;
            personalRows = tid == null
                ? []
                : personalRows.where((m) => m['id'] == tid).toList();
          }
        } else {
          personalRows = [];
        }
      }

      var studentRows = (await _db.select(_db.students).get())
          .map(supabaseStudent)
          .toList();
      if (!full) {
        studentRows = studentRows
            .where((m) => allowedStudents.contains(m['id'] as String))
            .toList();
      }

      var studentGymRows = (await _db.select(_db.studentGyms).get())
          .map(supabaseStudentGym)
          .toList();
      if (!full) {
        studentGymRows = studentGymRows
            .where((m) => allowedStudents.contains(m['student_id'] as String))
            .toList();
      }

      final methodRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.trainingMethods).get())
                .map(supabaseTrainingMethod)
                .toList();

      var groupRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.workoutGroups).get())
                .map(supabaseWorkoutGroup)
                .toList();
      var groupExRows = restrictCatalogTables
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.workoutGroupExercises).get())
                .map(supabaseWorkoutGroupExercise)
                .toList();

      var weekBlockRows = (await _db.select(_db.weekScheduleBlocks).get())
          .map(supabaseWeekBlock)
          .toList();
      if (!full) {
        weekBlockRows = weekBlockRows
            .where((m) => allowedStudents.contains(m['student_id'] as String))
            .toList();
      }
      final blockIds = weekBlockRows.map((m) => m['id'] as String).toSet();

      var weekItemRows = (await _db.select(_db.weekScheduleItems).get())
          .map(supabaseWeekItem)
          .toList();
      if (!full) {
        weekItemRows = weekItemRows
            .where((m) => blockIds.contains(m['block_id'] as String))
            .toList();
      }

      var dayWorkoutRows = (await _db.select(_db.dayWorkouts).get())
          .map(supabaseDayWorkout)
          .toList();
      if (!full) {
        dayWorkoutRows = dayWorkoutRows
            .where((m) => allowedStudents.contains(m['student_id'] as String))
            .toList();
      }
      final dayWorkoutIds = dayWorkoutRows
          .map((m) => m['id'] as String)
          .toSet();

      var dweRows = (await _db.select(_db.dayWorkoutExercises).get())
          .map(supabaseDayWorkoutExercise)
          .toList();
      if (!full) {
        dweRows = dweRows
            .where((m) => dayWorkoutIds.contains(m['day_workout_id'] as String))
            .toList();
      }

      final auditRows = asStudent
          ? <Map<String, dynamic>>[]
          : (await _db.select(_db.auditLogs).get())
                .map(supabaseAuditLog)
                .toList();

      tables.add(await _pushMaps(client, 'muscle_groups', muscleRows));
      tables.add(await _pushMaps(client, 'exercises', exerciseRows));
      tables.add(await _pushMaps(client, 'gyms', gymRows));
      tables.add(await _pushMaps(client, 'personals', personalRows));
      tables.add(await _pushMaps(client, 'students', studentRows));
      tables.add(await _pushMaps(client, 'student_gyms', studentGymRows));
      tables.add(await _pushMaps(client, 'training_methods', methodRows));
      tables.add(await _pushMaps(client, 'workout_groups', groupRows));
      tables.add(
        await _pushMaps(client, 'workout_group_exercises', groupExRows),
      );
      tables.add(
        await _pushMaps(client, 'week_schedule_blocks', weekBlockRows),
      );
      tables.add(await _pushMaps(client, 'week_schedule_items', weekItemRows));
      tables.add(await _pushMaps(client, 'day_workouts', dayWorkoutRows));
      tables.add(await _pushMaps(client, 'day_workout_exercises', dweRows));
      tables.add(await _pushMaps(client, 'audit_logs', auditRows));

      final allOk = tables.every((t) => t.ok);
      if (allOk) {
        _sync.noteConnected();
      } else {
        _sync.noteDisconnected();
      }
    } catch (e, st) {
      debugPrint('SupabaseManualSyncService: $e\n$st');
      _sync.noteDisconnected();
      tables.add(
        SupabaseTablePushResult(
          tableName: '(fatal)',
          rowCount: 0,
          ok: false,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _sync.endUpload();
    }

    return SupabaseManualSyncReport(
      connectionTest: ping,
      tables: tables,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
  }

  Future<SupabaseTablePushResult> _pushMaps(
    SupabaseClient client,
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return SupabaseTablePushResult(
        tableName: tableName,
        rowCount: 0,
        ok: true,
        pushLikelyChangedOnCloud: 0,
        pushLikelyAlreadyAligned: 0,
      );
    }
    SupabasePushDiff diff;
    try {
      diff = await computeSupabasePushDiff(client, tableName, rows);
    } catch (e) {
      diff = SupabasePushDiff(
        total: rows.length,
        cloudStaleOrNewCount: rows.length,
        likelyAlreadyAlignedCount: 0,
      );
    }
    // LWW (backup): não sobrescrever nuvem se ela estiver mais recente.
    List<Map<String, dynamic>> toSend = rows;
    if (rows.isNotEmpty &&
        tableName != 'student_gyms' &&
        tableName != 'audit_logs') {
      try {
        final ids = rows
            .map((m) => m['id'] as String?)
            .whereType<String>()
            .toList(growable: false);
        final remoteTimes = <String, DateTime?>{};
        const chunk = 120;
        for (var i = 0; i < ids.length; i += chunk) {
          final part = ids.sublist(i, min(i + chunk, ids.length));
          final res = await client
              .from(tableName)
              .select('id, updated_at')
              .inFilter('id', part);
          final list = res as List<dynamic>;
          for (final e in list) {
            final m = Map<String, dynamic>.from(e as Map);
            final id = m['id'] as String?;
            if (id == null) continue;
            final v = m['updated_at'];
            DateTime? t;
            if (v is String && v.isNotEmpty) {
              try {
                t = DateTime.parse(v).toUtc();
              } catch (_) {}
            }
            remoteTimes[id] = t;
          }
        }
        DateTime? parseLocalTs(dynamic v) {
          if (v == null) return null;
          if (v is String && v.isNotEmpty) {
            try {
              return DateTime.parse(v).toUtc();
            } catch (_) {
              return null;
            }
          }
          return null;
        }

        bool localIsNewer(DateTime? local, DateTime? remote) {
          if (local == null) return false;
          if (remote == null) return true;
          return local.isAfter(remote.subtract(const Duration(seconds: 1)));
        }

        toSend = rows.where((m) {
          final id = m['id'] as String?;
          if (id == null) return false;
          final local = parseLocalTs(m['updated_at']);
          final remote = remoteTimes[id];
          return localIsNewer(local, remote);
        }).toList();
      } catch (e) {
        // Se não conseguir ler `updated_at` remoto, mantém comportamento anterior (best effort).
      }
    }

    var sent = 0;
    try {
      for (var i = 0; i < toSend.length; i += _chunkSize) {
        final end = min(i + _chunkSize, toSend.length);
        final chunk = toSend.sublist(i, end);
        await client.from(tableName).upsert(chunk);
        sent += chunk.length;
        await Future<void>.delayed(Duration.zero);
      }
      return SupabaseTablePushResult(
        tableName: tableName,
        rowCount: sent,
        ok: true,
        pushLikelyChangedOnCloud: diff.cloudStaleOrNewCount,
        pushLikelyAlreadyAligned: diff.likelyAlreadyAlignedCount,
      );
    } catch (e) {
      var msg = e.toString();
      final needsPlanningMigration =
          msg.contains('PGRST204') &&
          msg.contains('schema cache') &&
          (msg.contains('combo_id') ||
              msg.contains('training_method_id') ||
              msg.contains('reps_text') ||
              msg.contains('last_reps_text'));
      if (needsPlanningMigration) {
        msg +=
            '\n\n—\n'
            'Faltam colunas de planeamento/treino no Postgres (ou o cache da API está desatualizado).\n'
            '1) Aplique a migração versionada mais recente com o Supabase CLI.\n'
            '2) Supabase: Settings → Data API → «Reload schema» (ou espere ~1 min).\n'
            '3) Volte a sincronizar.';
      }
      return SupabaseTablePushResult(
        tableName: tableName,
        rowCount: sent,
        ok: false,
        errorMessage: msg,
        pushLikelyChangedOnCloud: diff.cloudStaleOrNewCount,
        pushLikelyAlreadyAligned: diff.likelyAlreadyAlignedCount,
      );
    }
  }
}
