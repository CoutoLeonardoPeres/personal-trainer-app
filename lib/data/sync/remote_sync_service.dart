/// Contrato para sincronização remota (Supabase). Local primeiro; remoto em segundo plano.
abstract class RemoteSyncService {
  const RemoteSyncService();

  Future<void> enqueueAudit({
    required String auditLogId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  });
}

class NoOpRemoteSyncService implements RemoteSyncService {
  const NoOpRemoteSyncService();

  @override
  Future<void> enqueueAudit({
    required String auditLogId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {}
}
