/// Contrato para sincronização remota (Supabase). Implementação real virá na fase de backend.
abstract class RemoteSyncService {
  const RemoteSyncService();

  Future<void> enqueueAudit({
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
    required String action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? payload,
  }) async {}
}
