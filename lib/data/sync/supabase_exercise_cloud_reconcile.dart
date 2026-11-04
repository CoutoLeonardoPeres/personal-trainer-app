import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Igual a [_normExerciseName] em [AppDatabase] / deduplicação local.
String _normalizeExerciseName(String raw) {
  var k = raw.trim().toLowerCase();
  if (k.isEmpty) k = '\u0000empty';
  return k;
}

/// Alinha exercícios locais ao `id` remoto quando o nome normalizado coincide,
/// evitando `23505` em [exercises_unique_normalized_name] no Postgres.
Future<void> reconcileLocalExercisesWithSupabase(
  AppDatabase db,
  SupabaseClient client,
) async {
  final raw = await client
      .from('exercises')
      .select(
        'id,name,muscle_group_id,video_url,alternative_note,alternative_video_url,created_at,updated_at',
      );
  final remoteList = (raw as List<dynamic>).cast<Map<String, dynamic>>();

  final byNorm = <String, Map<String, dynamic>>{};
  for (final r in remoteList) {
    final name = (r['name'] as String?) ?? '';
    final norm = _normalizeExerciseName(name);
    final id = r['id'] as String;
    final prev = byNorm[norm];
    if (prev == null || id.compareTo(prev['id'] as String) < 0) {
      byNorm[norm] = r;
    }
  }

  await db.transaction(() async {
    final locals = await db.select(db.exercises).get();
    for (final E in locals) {
      if (E.name.startsWith('__sync_reconcile_ex_')) continue;

      final norm = _normalizeExerciseName(E.name);
      final remoteRow = byNorm[norm];
      if (remoteRow == null) continue;

      final remoteId = remoteRow['id'] as String;
      if (remoteId == E.id) continue;

      final mgId = remoteRow['muscle_group_id'] as String;
      final mgLocal = await (db.select(
        db.muscleGroups,
      )..where((t) => t.id.equals(mgId))).getSingleOrNull();
      if (mgLocal == null) continue;

      await (db.update(db.exercises)..where((t) => t.id.equals(E.id))).write(
        ExercisesCompanion(
          name: Value('__sync_reconcile_ex_${E.id}'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final existingRemoteLocally = await (db.select(
        db.exercises,
      )..where((t) => t.id.equals(remoteId))).getSingleOrNull();
      if (existingRemoteLocally == null) {
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                id: remoteId,
                name: ((remoteRow['name'] as String?) ?? E.name).trim().isEmpty
                    ? 'Sem nome'
                    : ((remoteRow['name'] as String?) ?? E.name).trim(),
                muscleGroupId: mgId,
                videoUrl: Value(remoteRow['video_url'] as String?),
                alternativeNote: Value(
                  remoteRow['alternative_note'] as String?,
                ),
                alternativeVideoUrl: Value(
                  remoteRow['alternative_video_url'] as String?,
                ),
                createdAt: Value(_parseSupabaseTs(remoteRow['created_at'])),
                updatedAt: Value(_parseSupabaseTs(remoteRow['updated_at'])),
              ),
            );
      }

      await db.repointExerciseReferencesToKeeperId(E.id, remoteId);
      await (db.delete(db.exercises)..where((t) => t.id.equals(E.id))).go();
    }
  });
}
