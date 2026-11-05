import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'modern_remote_sync_service.dart';

/// Retoma a sincronização RPC local-first após o app voltar ao primeiro plano.
/// O outbox já contém todas as mutações locais; não há mais envio em massa
/// direto de tabelas, que poderia reintroduzir duplicidades e bloquear a UI.
///
/// Após sucesso: mínimo 30 min até outro envio completo; entre tentativas: 4 min.
abstract final class SupabaseAutoPushScheduler {
  static const _kLastSuccessMs = 'supabase_auto_full_push_success_ms';
  static const _kLastAttemptMs = 'supabase_auto_full_push_attempt_ms';
  static const _minGapSuccess = Duration(minutes: 30);
  static const _minGapRetry = Duration(minutes: 4);
  static Timer? _scheduledRun;

  /// Chame após `resumed`/boot para evitar trabalho pesado no caminho de fechamento do iOS.
  static void scheduleAfterResume({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    Duration delay = const Duration(seconds: 8),
  }) {
    _scheduledRun?.cancel();
    if (!supabaseAppEnabled) return;
    _scheduledRun = Timer(delay, () {
      _scheduledRun = null;
      unawaited(_run(db, sync, session));
    });
  }

  static void cancelScheduledWork() {
    _scheduledRun?.cancel();
    _scheduledRun = null;
  }

  static Future<void> _run(
    AppDatabase db,
    SupabaseSyncController sync,
    AppSession session,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!supabaseAppEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final lastSuccess = prefs.getInt(_kLastSuccessMs);
    if (lastSuccess != null &&
        now - lastSuccess < _minGapSuccess.inMilliseconds) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseAutoPushScheduler: pulado (envio completo recente, '
          'mín. ${_minGapSuccess.inMinutes} min).',
        );
      }
      return;
    }

    final lastAttempt = prefs.getInt(_kLastAttemptMs) ?? 0;
    if (now - lastAttempt < _minGapRetry.inMilliseconds) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseAutoPushScheduler: pulado (tentativa recente, '
          'aguarde ${_minGapRetry.inMinutes} min entre tentativas).',
        );
      }
      return;
    }
    await prefs.setInt(_kLastAttemptMs, now);

    if (kDebugMode) {
      debugPrint('SupabaseAutoPushScheduler: retomando outbox RPC…');
    }

    try {
      await ModernRemoteSyncService(db, sync).recoverPendingWork();
      await prefs.setInt(_kLastSuccessMs, now);
      sync.noteConnected();
      sync.noteBackgroundPushSuccess();
      if (kDebugMode) {
        debugPrint('SupabaseAutoPushScheduler: outbox RPC concluído.');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SupabaseAutoPushScheduler: outbox RPC falhou: $error');
      }
      sync.noteBackgroundPushError('Sincronização RPC incompleta: $error');
    }
  }
}
