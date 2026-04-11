import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import 'supabase_exercise_cloud_reconcile.dart';
import 'supabase_muscle_group_cloud_reconcile.dart';

DateTime? _lastCatalogReconcileThrottle;

/// Reconcilia [muscle_groups] e [exercises] com a nuvem antes do push (unicidade por nome).
///
/// [throttle]: intervalo mínimo entre execuções completas (sync incremental).
Future<void> reconcileLocalCatalogWithCloud(
  AppDatabase db,
  SupabaseClient client, {
  Duration throttle = Duration.zero,
}) async {
  final now = DateTime.now();
  if (throttle > Duration.zero &&
      _lastCatalogReconcileThrottle != null &&
      now.difference(_lastCatalogReconcileThrottle!) < throttle) {
    return;
  }

  await reconcileLocalMuscleGroupsWithSupabase(db, client, minInterval: Duration.zero);
  await reconcileLocalExercisesWithSupabase(db, client);
  _lastCatalogReconcileThrottle = DateTime.now();
}
