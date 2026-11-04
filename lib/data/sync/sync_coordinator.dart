import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../local/app_database.dart';
import 'supabase_auto_pull_scheduler.dart';
import 'supabase_pull_sync_service.dart';
import 'sync_watermark_store.dart';
import '../../core/supabase/supabase_sync_controller.dart';

/// Orquestra pull incremental (watermark) e evita full-scan desnecessário.
abstract final class SyncCoordinator {
  SyncCoordinator._();

  static Future<void> pullIncremental({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    bool bootstrapIfNoWatermark = true,
  }) async {
    if (!supabaseAppEnabled) return;
    final scope = SyncWatermarkStore.scopeForSession(
      fullCloud: session.hasFullOrgAccess,
      personalId: session.personalId,
      studentId: session.studentId,
    );
    final svc = SupabasePullSyncService(db, sync, session: session);
    final wm = await SyncWatermarkStore.getWatermark(
      table: '_global',
      scope: scope,
    );
    if (wm == null && bootstrapIfNoWatermark) {
      await svc.pullAllFromRemote();
      await SyncWatermarkStore.setWatermark(
        table: '_global',
        at: DateTime.now().toUtc(),
        scope: scope,
      );
      return;
    }
    await svc.pullIncrementalSince(wm ?? DateTime.fromMillisecondsSinceEpoch(0));
    await SyncWatermarkStore.setWatermark(
      table: '_global',
      at: DateTime.now().toUtc(),
      scope: scope,
    );
  }

  /// Resume / foreground: incremental + hot started workouts.
  static Future<void> onAppForeground({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
  }) async {
    await pullIncremental(db: db, sync: sync, session: session);
    await SupabaseAutoPullScheduler.pullHotStartedWorkoutsById(
      db: db,
      sync: sync,
      session: session,
    );
  }
}
