import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
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
  });

  final String tableName;
  final int rowCount;
  final bool ok;
  final String? errorMessage;
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
      buf.writeln('  [$status] ${t.tableName}: ${t.rowCount} linha(s)');
      if (t.errorMessage != null && t.errorMessage!.isNotEmpty) {
        buf.writeln('      → ${t.errorMessage}');
      }
    }
    buf.writeln();
    buf.writeln(
      'Resumo: $successTableCount/${tables.length} tabelas sem erro, $totalRows linhas enviadas (upsert).',
    );
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

  static const int _chunkSize = 350;

  /// Mensagem extra quando a API responde 401 / JWT inválido (chave ou URL erradas).
  static String explainHttpAuthFailure(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    final looks401 = lower.contains('401') ||
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
        '• Não use chave secret (sb_secret_…) nem service_role no app.';
  }

  static Future<SupabaseConnectionTestResult> testConnectionOnly() async {
    if (!supabaseAppEnabled) {
      return SupabaseConnectionTestResult(
        ok: false,
        message: 'App sem Supabase ativo. Opções: (1) --dart-define=SUPABASE_ANON_KEY=<JWT eyJ…> '
            'e opcionalmente SUPABASE_URL; (2) Configurações → Nuvem → guardar anon JWT + URL e '
            'reiniciar o app por completo. Não use sb_publishable_… como se fosse anon — use o JWT '
            'em Settings → API → Legacy API keys.',
      );
    }
    final sw = Stopwatch()..start();
    try {
      await Supabase.instance.client.from('muscle_groups').select('id').limit(1);
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

  Future<SupabaseManualSyncReport> testConnectionAndPushAll() async {
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
      tables.add(await _pushMaps(
        client,
        'muscle_groups',
        (await _db.select(_db.muscleGroups).get()).map(supabaseMuscleGroup).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'exercises',
        (await _db.select(_db.exercises).get()).map(supabaseExercise).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'gyms',
        (await _db.select(_db.gyms).get()).map(supabaseGym).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'personals',
        (await _db.select(_db.personals).get()).map(supabasePersonal).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'students',
        (await _db.select(_db.students).get()).map(supabaseStudent).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'student_gyms',
        (await _db.select(_db.studentGyms).get()).map(supabaseStudentGym).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'training_methods',
        (await _db.select(_db.trainingMethods).get()).map(supabaseTrainingMethod).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'workout_groups',
        (await _db.select(_db.workoutGroups).get()).map(supabaseWorkoutGroup).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'workout_group_exercises',
        (await _db.select(_db.workoutGroupExercises).get())
            .map(supabaseWorkoutGroupExercise)
            .toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'week_schedule_blocks',
        (await _db.select(_db.weekScheduleBlocks).get()).map(supabaseWeekBlock).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'week_schedule_items',
        (await _db.select(_db.weekScheduleItems).get()).map(supabaseWeekItem).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'day_workouts',
        (await _db.select(_db.dayWorkouts).get()).map(supabaseDayWorkout).toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'day_workout_exercises',
        (await _db.select(_db.dayWorkoutExercises).get())
            .map(supabaseDayWorkoutExercise)
            .toList(),
      ));
      tables.add(await _pushMaps(
        client,
        'audit_logs',
        (await _db.select(_db.auditLogs).get()).map(supabaseAuditLog).toList(),
      ));

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
      );
    }
    var sent = 0;
    try {
      for (var i = 0; i < rows.length; i += _chunkSize) {
        final end = min(i + _chunkSize, rows.length);
        final chunk = rows.sublist(i, end);
        await client.from(tableName).upsert(chunk);
        sent += chunk.length;
        await Future<void>.delayed(Duration.zero);
      }
      return SupabaseTablePushResult(
        tableName: tableName,
        rowCount: sent,
        ok: true,
      );
    } catch (e) {
      return SupabaseTablePushResult(
        tableName: tableName,
        rowCount: sent,
        ok: false,
        errorMessage: e.toString(),
      );
    }
  }
}
