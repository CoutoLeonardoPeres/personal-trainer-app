import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/muscle_group_utils.dart';
import '../local/app_database.dart';

DateTime _parseSupabaseTs(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v.toLocal();
  if (v is String) {
    try {
      return DateTime.parse(v).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}

DateTime? _lastMuscleGroupCloudReconcile;

/// Alinha grupos musculares locais ao `id` já existente na nuvem quando o nome
/// normalizado coincide, evitando `23505` em [muscle_groups_unique_normalized_name].
///
/// O `upsert` por `id` não resolve: um `id` novo com nome igual ao de outra linha
/// remota viola o índice único em `lower(trim(name))`.
Future<void> reconcileLocalMuscleGroupsWithSupabase(
  AppDatabase db,
  SupabaseClient client, {
  Duration minInterval = Duration.zero,
}) async {
  if (minInterval > Duration.zero) {
    final now = DateTime.now();
    if (_lastMuscleGroupCloudReconcile != null &&
        now.difference(_lastMuscleGroupCloudReconcile!) < minInterval) {
      return;
    }
  }

  final raw = await client.from('muscle_groups').select('id,name,created_at,updated_at');
  final remoteList = (raw as List<dynamic>).cast<Map<String, dynamic>>();

  final byNorm = <String, Map<String, dynamic>>{};
  for (final r in remoteList) {
    final name = (r['name'] as String?) ?? '';
    final norm = normalizeMuscleGroupName(name);
    if (norm.isEmpty) continue;
    final id = r['id'] as String;
    final prev = byNorm[norm];
    if (prev == null || id.compareTo(prev['id'] as String) < 0) {
      byNorm[norm] = r;
    }
  }

  await db.transaction(() async {
    final locals = await db.select(db.muscleGroups).get();
    for (final L in locals) {
      if (L.name.startsWith('__sync_reconcile_')) continue;
      var norm = normalizeMuscleGroupName(L.name);
      if (norm.isEmpty) continue;

      final remoteRow = byNorm[norm];
      if (remoteRow == null) continue;

      final remoteId = remoteRow['id'] as String;
      if (remoteId == L.id) continue;

      final remoteName = (remoteRow['name'] as String?)?.trim();
      final nameToStore =
          (remoteName != null && remoteName.isNotEmpty) ? remoteName : L.name.trim();
      final created = _parseSupabaseTs(remoteRow['created_at']);
      final updated = _parseSupabaseTs(remoteRow['updated_at']);

      // Libera o índice único local (mesmo nome normalizado) antes de inserir o id da nuvem.
      await (db.update(db.muscleGroups)..where((t) => t.id.equals(L.id))).write(
            MuscleGroupsCompanion(
              name: Value('__sync_reconcile_${L.id}'),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final existingRemoteLocally = await (db.select(db.muscleGroups)
            ..where((t) => t.id.equals(remoteId)))
          .getSingleOrNull();
      if (existingRemoteLocally == null) {
        await db.into(db.muscleGroups).insert(
              MuscleGroupsCompanion.insert(
                id: remoteId,
                name: nameToStore.isEmpty ? 'Sem nome' : nameToStore,
                createdAt: Value(created),
                updatedAt: Value(updated),
              ),
            );
      }

      await (db.update(db.exercises)..where((e) => e.muscleGroupId.equals(L.id)))
          .write(ExercisesCompanion(muscleGroupId: Value(remoteId)));
      await (db.delete(db.muscleGroups)..where((t) => t.id.equals(L.id))).go();
    }
  });

  _lastMuscleGroupCloudReconcile = DateTime.now();
}
