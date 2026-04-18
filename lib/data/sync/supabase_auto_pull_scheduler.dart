import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../local/app_database.dart';
import 'supabase_pull_sync_service.dart';

/// Baixa alterações do Supabase para o SQLite após o app voltar ao primeiro plano,
/// para que **outros dispositivos** (ou o mesmo utilizador noutro telemóvel) vejam dados
/// recentes sem abrir manualmente “Importar da nuvem”.
///
/// O **envio** das alterações locais para a nuvem é feito logo após cada gravação via
/// [SupabaseRemoteSyncService] (fila de auditoria). Este job só complementa com **pull**.
abstract final class SupabaseAutoPullScheduler {
  static const _kLastPullMs = 'supabase_auto_pull_last_ms';
  static const _minGapBetweenPulls = Duration(seconds: 90);
  static Timer? _scheduledPull;

  /// Agenda importação após [delay] (por defeito após o arranque da fila de envio).
  static void scheduleAfterResume({
    required AppDatabase db,
    required SupabaseSyncController sync,
    required AppSession session,
    Duration delay = const Duration(seconds: 14),
    /// Quando true, ignora o intervalo mínimo entre importações (ex.: arranque ou voltar ao primeiro plano).
    bool bypassMinInterval = false,
  }) {
    _scheduledPull?.cancel();
    if (!supabaseAppEnabled) return;
    _scheduledPull = Timer(delay, () {
      _scheduledPull = null;
      unawaited(_runIfDue(db, sync, session, bypassMinInterval: bypassMinInterval));
    });
  }

  static void cancelScheduledWork() {
    _scheduledPull?.cancel();
    _scheduledPull = null;
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
    if (!bypassMinInterval &&
        now - last < _minGapBetweenPulls.inMilliseconds) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseAutoPullScheduler: pulado (última importação há menos de '
          '${_minGapBetweenPulls.inSeconds}s).',
        );
      }
      return;
    }
    await prefs.setInt(_kLastPullMs, now);

    if (kDebugMode) {
      debugPrint('SupabaseAutoPullScheduler: importando Supabase → SQLite…');
    }

    try {
      final svc = SupabasePullSyncService(db, sync, session: session);
      final report = await svc.pullAllFromRemote();
      await session.hydratePersonalAdminFlag(db);
      if (report.connectionOk && report.tables.every((t) => t.ok)) {
        if (kDebugMode) {
          debugPrint(
            'SupabaseAutoPullScheduler: importação concluída — '
            '${report.tables.length} tabela(s).',
          );
        }
      } else if (kDebugMode) {
        debugPrint(
          'SupabaseAutoPullScheduler: importação incompleta — '
          '${report.connectionMessage}',
        );
      }
    } catch (e, st) {
      debugPrint('SupabaseAutoPullScheduler: $e\n$st');
    }
  }
}
