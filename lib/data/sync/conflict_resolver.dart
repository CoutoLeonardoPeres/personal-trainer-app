/// Resolução determinística de conflitos — **somente por revision do servidor**.
///
/// Sprint 3: proibido usar relógio local (`updated_at`, `DateTime.now()`, tolerâncias).
abstract final class ConflictResolver {
  ConflictResolver._();

  /// Escrita local baseada em [expectedRevision] ficou obsoleta face ao servidor.
  static bool isStaleWrite({
    required int expectedRevision,
    required int serverRevision,
  }) => expectedRevision < serverRevision;

  /// Pull remoto deve substituir o estado local.
  static bool remoteWins({
    required int localRevision,
    required int remoteRevision,
  }) => remoteRevision > localRevision;

  /// Local pode tentar push (mesma revision ou servidor desatualizado).
  static bool localMayPush({
    required int localRevision,
    required int serverRevision,
  }) => localRevision >= serverRevision;

  /// Empate de revision: aceitar remoto (servidor é fonte da verdade).
  static bool acceptRemoteOnRevisionTie({
    required int localRevision,
    required int remoteRevision,
  }) => remoteRevision >= localRevision;
}

/// Resultado de um UPDATE otimista condicionado a `revision`.
sealed class OptimisticUpdateOutcome {
  const OptimisticUpdateOutcome();

  const factory OptimisticUpdateOutcome.applied({required int newRevision}) =
      OptimisticUpdateApplied;

  const factory OptimisticUpdateOutcome.stale({required int serverRevision}) =
      OptimisticUpdateStale;

  const factory OptimisticUpdateOutcome.notFound() = OptimisticUpdateNotFound;
}

final class OptimisticUpdateApplied extends OptimisticUpdateOutcome {
  const OptimisticUpdateApplied({required this.newRevision});
  final int newRevision;
}

final class OptimisticUpdateStale extends OptimisticUpdateOutcome {
  const OptimisticUpdateStale({required this.serverRevision});
  final int serverRevision;
}

final class OptimisticUpdateNotFound extends OptimisticUpdateOutcome {
  const OptimisticUpdateNotFound();
}
