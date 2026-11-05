import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../local/app_database.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import 'modern_remote_sync_service.dart';

/// Orquestra o ciclo RPC local-first sem cursores baseados em data.
abstract final class SyncCoordinator {
  SyncCoordinator._();

  static Future<void> pullIncremental({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    bool bootstrapIfNoWatermark = true,
  }) async {
    if (!supabaseAppEnabled) return;
    await ModernRemoteSyncService(db, sync).recoverPendingWork();
  }

  /// Resume / foreground: incremental + hot started workouts.
  static Future<void> onAppForeground({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
  }) async {
    await pullIncremental(db: db, sync: sync, session: session);
  }
}
