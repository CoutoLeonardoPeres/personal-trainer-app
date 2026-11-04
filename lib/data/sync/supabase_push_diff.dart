import 'dart:math' show min;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Estima quantas linhas do [rows] a enviar realmente **alteram** a nuvem
/// (linha inexistente ou `updated_at` / `at` local posterior ao remoto).
class SupabasePushDiff {
  SupabasePushDiff({
    required this.total,
    required this.cloudStaleOrNewCount,
    required this.likelyAlreadyAlignedCount,
  });

  final int total;

  /// Local mais recente que o remoto, ou registo ainda inexistente na nuvem.
  final int cloudStaleOrNewCount;

  /// Mesmo `updated_at` (ou par já existente em student_gyms), dentro da resolução do relógio.
  final int likelyAlreadyAlignedCount;
}

DateTime? _parseTs(dynamic v) {
  if (v == null) return null;
  if (v is! String || v.isEmpty) return null;
  try {
    return DateTime.parse(v).toUtc();
  } catch (_) {
    return null;
  }
}

/// Compara timestamps com tolerância de 1s (relógios / truncagem Postgres).
bool _localIsNewer(DateTime? local, DateTime? remote) {
  if (local == null) return false;
  if (remote == null) return true;
  return local.toUtc().isAfter(
    remote.toUtc().subtract(const Duration(seconds: 1)),
  );
}

Future<Map<String, DateTime?>> _fetchIdToRemoteTime(
  SupabaseClient client,
  String table,
  List<String> ids,
  String timeColumn,
) async {
  final out = <String, DateTime?>{};
  if (ids.isEmpty) return out;
  const chunk = 120;
  for (var i = 0; i < ids.length; i += chunk) {
    final part = ids.sublist(i, min(i + chunk, ids.length));
    final res = await client
        .from(table)
        .select('id, $timeColumn')
        .inFilter('id', part);
    final list = res as List<dynamic>;
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      out[id] = _parseTs(m[timeColumn]);
    }
  }
  return out;
}

Future<Set<String>> _fetchExistingStudentGymKeys(
  SupabaseClient client,
  List<Map<String, dynamic>> rows,
) async {
  final keys = <String>{};
  if (rows.isEmpty) return keys;
  const chunk = 80;
  for (var i = 0; i < rows.length; i += chunk) {
    final part = rows.sublist(i, min(i + chunk, rows.length));
    final sids = part.map((m) => m['student_id'] as String).toSet().toList();
    if (sids.isEmpty) continue;
    final res = await client
        .from('student_gyms')
        .select('student_id, gym_id')
        .inFilter('student_id', sids);
    final list = res as List<dynamic>;
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final s = m['student_id'] as String?;
      final g = m['gym_id'] as String?;
      if (s != null && g != null) keys.add('$s|$g');
    }
  }
  return keys;
}

/// Calcula diff antes do upsert (evita N+1 por linha: consultas por IDs em blocos).
Future<SupabasePushDiff> computeSupabasePushDiff(
  SupabaseClient client,
  String tableName,
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) {
    return SupabasePushDiff(
      total: 0,
      cloudStaleOrNewCount: 0,
      likelyAlreadyAlignedCount: 0,
    );
  }

  if (tableName == 'student_gyms') {
    final existing = await _fetchExistingStudentGymKeys(client, rows);
    var stale = 0;
    for (final m in rows) {
      final s = m['student_id'] as String?;
      final g = m['gym_id'] as String?;
      if (s == null || g == null) continue;
      final k = '$s|$g';
      if (!existing.contains(k)) {
        stale++;
      }
    }
    return SupabasePushDiff(
      total: rows.length,
      cloudStaleOrNewCount: stale,
      likelyAlreadyAlignedCount: rows.length - stale,
    );
  }

  if (tableName == 'audit_logs') {
    final ids = rows
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toList();
    final remote = await _fetchIdToRemoteTime(client, tableName, ids, 'at');
    var stale = 0;
    for (final m in rows) {
      final id = m['id'] as String?;
      if (id == null) continue;
      final local = _parseTs(m['at']);
      final r = remote[id];
      if (_localIsNewer(local, r)) {
        stale++;
      }
    }
    return SupabasePushDiff(
      total: rows.length,
      cloudStaleOrNewCount: stale,
      likelyAlreadyAlignedCount: rows.length - stale,
    );
  }

  final ids = rows.map((m) => m['id'] as String?).whereType<String>().toList();
  final remote = await _fetchIdToRemoteTime(
    client,
    tableName,
    ids,
    'updated_at',
  );
  var stale = 0;
  for (final m in rows) {
    final id = m['id'] as String?;
    if (id == null) continue;
    final local = _parseTs(m['updated_at']);
    final r = remote[id];
    if (_localIsNewer(local, r)) {
      stale++;
    }
  }
  return SupabasePushDiff(
    total: rows.length,
    cloudStaleOrNewCount: stale,
    likelyAlreadyAlignedCount: rows.length - stale,
  );
}
