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

  Future<void> recoverPendingWork() async {}

  /// Espelha só a linha `students` no Postgres (incl. `password_hash`); não altera `student_gyms`.
  Future<void> mirrorStudentRowNow(String studentId) async {}

  /// Espelha só a linha `personals` no Postgres (incl. `password_hash`).
  Future<void> mirrorPersonalRowNow(String personalId) async {}

  /// Força atualização imediata do treino e suas linhas a partir da nuvem.
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) async {}
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

  @override
  Future<void> recoverPendingWork() async {}

  @override
  Future<void> mirrorStudentRowNow(String studentId) async {}

  @override
  Future<void> mirrorPersonalRowNow(String personalId) async {}

  @override
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) async {}
}
