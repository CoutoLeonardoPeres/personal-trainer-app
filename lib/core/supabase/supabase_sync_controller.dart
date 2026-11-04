import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

enum SupabaseCloudStatus { unconfigured, unknown, online, offline }

enum SupabaseTrafficKind { idle, uploading, downloading }

class SupabaseSyncController extends ChangeNotifier {
  SupabaseCloudStatus cloudStatus = SupabaseCloudStatus.unconfigured;
  SupabaseTrafficKind trafficKind = SupabaseTrafficKind.idle;
  int _uploadDepth = 0;
  int _downloadDepth = 0;
  Timer? _heartbeat;

  /// Último erro ao enviar/receber (visível em Configurações).
  String? lastRemoteError;
  DateTime? lastRemoteSuccessAt;
  int backgroundPushCount = 0;

  /// Checagem periódica SQLite × Supabase (contagens por tabela).
  DateTime? lastFidelityCheckAt;
  bool? lastFidelityCountsAligned;
  String? lastFidelityDetail;

  bool get supabaseConfigured => supabaseAppEnabled;

  /// Linha curta para tooltip do indicador na AppBar.
  String? get fidelitySummaryForTooltip {
    if (!supabaseAppEnabled || lastFidelityCheckAt == null) return null;
    final t = lastFidelityCheckAt!.toLocal();
    if (lastFidelityCountsAligned == true) {
      return 'Fidelidade: contagens iguais ($t)';
    }
    if (lastFidelityCountsAligned == false) {
      return 'Fidelidade: divergência — veja Configurações ($t)';
    }
    return 'Fidelidade: verificação incompleta ($t)';
  }

  void noteBackgroundPushSuccess() {
    lastRemoteError = null;
    lastRemoteSuccessAt = DateTime.now();
    backgroundPushCount++;
    notifyListeners();
  }

  void noteBackgroundPushError(Object error) {
    final msg = error.toString();
    lastRemoteError = msg.length > 280 ? '${msg.substring(0, 280)}…' : msg;
    notifyListeners();
  }

  void clearDiagnostics() {
    lastRemoteError = null;
    notifyListeners();
  }

  void noteFidelityResult({
    required DateTime at,
    required bool aligned,
    String? detail,
  }) {
    lastFidelityCheckAt = at;
    lastFidelityCountsAligned = aligned;
    lastFidelityDetail = aligned ? null : detail;
    if (aligned) {
      noteConnected();
    }
    notifyListeners();
  }

  void noteFidelityCheckFailed(Object error) {
    lastFidelityCheckAt = DateTime.now();
    lastFidelityCountsAligned = null;
    final msg = error.toString();
    lastFidelityDetail = msg.length > 220 ? '${msg.substring(0, 220)}…' : msg;
    notifyListeners();
  }

  bool get isTrafficActive => _uploadDepth > 0 || _downloadDepth > 0;

  /// Enquanto ativo, pulls pontuais de [day_workouts] / linhas são ignorados
  /// (evita realtime/auto-pull a repor JSON antigo logo após registrar série).
  DateTime? _dayWorkoutPullMutedUntil;

  bool get isDayWorkoutPullMuted {
    final until = _dayWorkoutPullMutedUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _dayWorkoutPullMutedUntil = null;
    return false;
  }

  void muteDayWorkoutPullFor(Duration duration) {
    final until = DateTime.now().add(duration);
    final cur = _dayWorkoutPullMutedUntil;
    if (cur == null || until.isAfter(cur)) {
      _dayWorkoutPullMutedUntil = until;
    }
  }

  void beginUpload() {
    _uploadDepth++;
    _refreshTrafficKind();
    notifyListeners();
  }

  void beginDownload() {
    _downloadDepth++;
    _refreshTrafficKind();
    notifyListeners();
  }

  void endUpload() {
    _uploadDepth = (_uploadDepth - 1).clamp(0, 999);
    _refreshTrafficKind();
    notifyListeners();
  }

  void endDownload() {
    _downloadDepth = (_downloadDepth - 1).clamp(0, 999);
    _refreshTrafficKind();
    notifyListeners();
  }

  void _refreshTrafficKind() {
    if (_downloadDepth > 0) {
      trafficKind = SupabaseTrafficKind.downloading;
    } else if (_uploadDepth > 0) {
      trafficKind = SupabaseTrafficKind.uploading;
    } else {
      trafficKind = SupabaseTrafficKind.idle;
    }
  }

  void noteConnected() {
    final wasOffline = cloudStatus != SupabaseCloudStatus.online;
    final hadErr = lastRemoteError != null;
    lastRemoteError = null;
    if (wasOffline) {
      cloudStatus = SupabaseCloudStatus.online;
    }
    if (wasOffline || hadErr) {
      notifyListeners();
    }
  }

  void noteDisconnected() {
    if (cloudStatus != SupabaseCloudStatus.offline) {
      cloudStatus = SupabaseCloudStatus.offline;
      notifyListeners();
    }
  }

  void applyConfiguredState() {
    if (!supabaseAppEnabled) {
      cloudStatus = SupabaseCloudStatus.unconfigured;
      notifyListeners();
      return;
    }
    if (cloudStatus == SupabaseCloudStatus.unconfigured) {
      cloudStatus = SupabaseCloudStatus.unknown;
      notifyListeners();
    }
  }

  void startHeartbeat() {
    _heartbeat?.cancel();
    applyConfiguredState();
    if (!supabaseAppEnabled) return;

    _heartbeat = Timer.periodic(const Duration(seconds: 120), (_) {
      unawaited(_silentPing());
    });
    unawaited(_silentPing());
  }

  Future<void> _silentPing() async {
    if (!supabaseAppEnabled) return;
    try {
      await Supabase.instance.client
          .from('muscle_groups')
          .select('id')
          .limit(1);
      noteConnected();
    } catch (e) {
      noteDisconnected();
      // Deixa o motivo visível em Configurações (antes só ficava “offline” sem texto).
      final msg = e.toString();
      noteBackgroundPushError(
        msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
      );
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }
}
