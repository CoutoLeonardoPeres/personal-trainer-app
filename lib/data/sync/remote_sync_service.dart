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

  /// Espelha só a linha `students` no Postgres (incl. `auth_user_id`); não altera `student_gyms`.
  Future<void> mirrorStudentRowNow(String studentId) async {}

  /// Espelha só a linha `personals` no Postgres (incl. `auth_user_id`).
  Future<void> mirrorPersonalRowNow(String personalId) async {}

  /// Força atualização imediata do treino e suas linhas a partir da nuvem.
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) async {}

  /// Pré-carrega treinos concluídos recentes do aluno para métricas comparativas
  /// (ex.: score percentual vs último treino do mesmo exercício).
  Future<void> refreshRecentCompletedHistoryForStudent(
    String studentId, {
    int limit = 40,
  }) async {}

  /// Força atualização do planejamento semanal de um aluno para a semana indicada.
  Future<void> refreshStudentWeekScheduleFromCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {}

  /// Convergência aditiva: publica apenas blocos/itens locais ainda ausentes
  /// na nuvem. Não sobrescreve nem remove linhas remotas.
  Future<void> repairMissingStudentWeekScheduleItemsOnCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {}

  /// Força atualização do catálogo base de exercícios (grupos + exercícios).
  Future<void> refreshExercisesCatalogFromCloud() async {}

  /// Força atualização do catálogo de grupos de treino e suas linhas.
  Future<void> refreshWorkoutGroupsCatalogFromCloud() async {}

  /// Força atualização pontual de exercícios por id (mais rápido para modal de treino).
  Future<void> refreshExercisesByIdsFromCloud(
    Iterable<String> exerciseIds,
  ) async {}
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

  @override
  Future<void> refreshRecentCompletedHistoryForStudent(
    String studentId, {
    int limit = 40,
  }) async {}

  @override
  Future<void> refreshStudentWeekScheduleFromCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {}

  @override
  Future<void> repairMissingStudentWeekScheduleItemsOnCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {}

  @override
  Future<void> refreshExercisesCatalogFromCloud() async {}

  @override
  Future<void> refreshWorkoutGroupsCatalogFromCloud() async {}

  @override
  Future<void> refreshExercisesByIdsFromCloud(
    Iterable<String> exerciseIds,
  ) async {}
}
