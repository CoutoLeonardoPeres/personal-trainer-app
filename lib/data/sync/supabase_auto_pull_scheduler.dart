import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'modern_remote_sync_service.dart';
import 'sync_coordinator.dart';

/// Baixa alterações do Supabase para o SQLite após o app voltar ao primeiro plano.
abstract final class SupabaseAutoPullScheduler {
  static const _kLastPullMs = 'supabase_auto_pull_last_ms';
  static const _minGapBetweenPulls = Duration(seconds: 3);
  static Timer? _scheduledPull;
  static Timer? _foregroundPullTicker;

  static void scheduleAfterResume({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    Duration delay = const Duration(seconds: 4),
    bool bypassMinInterval = false,
  }) {
    _scheduledPull?.cancel();
    if (!supabaseAppEnabled) return;
    _scheduledPull = Timer(delay, () {
      _scheduledPull = null;
      unawaited(
        _runIfDue(db, sync, session, bypassMinInterval: bypassMinInterval),
      );
    });
  }

  static void cancelScheduledWork() {
    _scheduledPull?.cancel();
    _scheduledPull = null;
  }

  /// Fallback esparso (Sprint 3): incremental por watermark a cada 5 min.
  static void startForegroundPolling({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    Duration interval = const Duration(minutes: 5),
  }) {
    _foregroundPullTicker?.cancel();
    if (!supabaseAppEnabled) return;
    _foregroundPullTicker = Timer.periodic(interval, (_) {
      unawaited(
        SyncCoordinator.pullIncremental(db: db, sync: sync, session: session),
      );
    });
  }

  static void stopForegroundPolling() {
    _foregroundPullTicker?.cancel();
    _foregroundPullTicker = null;
  }

  static Future<void> _runIfDue(
    AppDatabase db,
    SupabaseSyncController sync,
    AppSession session, {
    bool bypassMinInterval = false,
  }) async {
    if (!supabaseAppEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_kLastPullMs) ?? 0;
    if (!bypassMinInterval && now - last < _minGapBetweenPulls.inMilliseconds) {
      return;
    }
    await prefs.setInt(_kLastPullMs, now);

    if (kDebugMode) {
      debugPrint('SupabaseAutoPullScheduler: pull incremental…');
    }

    try {
      await SyncCoordinator.onAppForeground(
        db: db,
        sync: sync,
        session: session,
      );
      await session.hydratePersonalAdminFlag(db);
    } catch (e, st) {
      debugPrint('SupabaseAutoPullScheduler: $e\n$st');
    }
  }

  /// Recupera o estado dos treinos em execução pelo mesmo cursor RPC.
  /// O protocolo não faz pull direto por tabela, evitando duas fontes de
  /// verdade e atualizações que reaparecem depois de concluídas.
  static Future<void> pullHotStartedWorkoutsById({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
  }) async {
    if (!supabaseAppEnabled) return;
    try {
      await ModernRemoteSyncService(db, sync).recoverPendingWork();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SupabaseAutoPullScheduler hotPull: $e\n$st');
      }
    }
  }
}
