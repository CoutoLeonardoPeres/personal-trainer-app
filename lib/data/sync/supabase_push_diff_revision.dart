import 'dart:math' show min;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'conflict_resolver.dart';
import 'supabase_push_diff.dart';

/// Estima linhas a enviar com diff por **revision** (Sprint 3).
Future<SupabasePushDiff> estimatePushDiffByRevision({
  required SupabaseClient client,
  required String table,
  required List<Map<String, dynamic>> localRows,
}) async {
  if (localRows.isEmpty) {
    return SupabasePushDiff(
      total: 0,
      cloudStaleOrNewCount: 0,
      likelyAlreadyAlignedCount: 0,
    );
  }
  final ids = localRows
      .map((m) => m['id'] as String?)
      .whereType<String>()
      .toList();
  final remoteRevisions = <String, int>{};
  const chunk = 120;
  for (var i = 0; i < ids.length; i += chunk) {
    final part = ids.sublist(i, min(i + chunk, ids.length));
    final res = await client.from(table).select('id, revision').inFilter('id', part);
    for (final e in res as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      final rev = m['revision'];
      remoteRevisions[id] = rev is num ? rev.toInt() : int.tryParse('$rev') ?? 0;
    }
  }
  var stale = 0;
  var aligned = 0;
  for (final row in localRows) {
    final id = row['id'] as String?;
    if (id == null) {
      stale++;
      continue;
    }
    final localRev = row['revision'];
    final lr = localRev is num ? localRev.toInt() : int.tryParse('$localRev') ?? 0;
    final rr = remoteRevisions[id];
    if (rr == null || ConflictResolver.isStaleWrite(expectedRevision: lr, serverRevision: rr)) {
      stale++;
    } else {
      aligned++;
    }
  }
  return SupabasePushDiff(
    total: localRows.length,
    cloudStaleOrNewCount: stale,
    likelyAlreadyAlignedCount: aligned,
  );
}

int revisionDiffCount({
  required int localRevision,
  required int remoteRevision,
}) =>
    ConflictResolver.isStaleWrite(
      expectedRevision: localRevision,
      serverRevision: remoteRevision,
    )
        ? 1
        : 0;
