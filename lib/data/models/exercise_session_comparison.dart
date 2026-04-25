/// Dados para o resumo “último treino vs atual” ao concluir todas as séries de um exercício.
class ExerciseSetComparisonRow {
  const ExerciseSetComparisonRow({
    required this.setNumber,
    required this.currentSetScore,
    this.previousSetScore,
    required this.currentPctOfPrescribed,
    this.previousPctOfPrescribed,
    this.scoreEvolutionPctVsPrevious,
    this.restAfterCurrentCountdownMs,
    this.restAfterPreviousCountdownMs,
    this.restPrescribedSec,
  });

  final int setNumber;
  final double currentSetScore;
  final double? previousSetScore;

  /// Contribuição da série face ao prescrito (carga×reps do planejamento), em %.
  final double currentPctOfPrescribed;
  final double? previousPctOfPrescribed;

  /// (atual − anterior) / anterior × 100, quando há série homóloga no treino anterior.
  final double? scoreEvolutionPctVsPrevious;

  /// Descanso após esta série (timer), no treino atual; última série costuma ser null.
  final int? restAfterCurrentCountdownMs;
  final int? restAfterPreviousCountdownMs;
  final int? restPrescribedSec;
}

class ExerciseSessionComparison {
  const ExerciseSessionComparison({
    required this.exerciseName,
    required this.sets,
    required this.currentWallDuration,
    this.previousWallDuration,
    required this.currentTotalScore,
    this.previousTotalScore,
    this.totalScoreEvolutionPctVsPrevious,
    this.currentEstimatedKcal,
    this.previousEstimatedKcal,
    required this.hasWorkoutWatchKcal,
  });

  final String exerciseName;
  final List<ExerciseSetComparisonRow> sets;

  /// Tempo entre o registo da primeira e da última série (treino atual).
  final Duration currentWallDuration;
  final Duration? previousWallDuration;

  final double currentTotalScore;
  final double? previousTotalScore;
  final double? totalScoreEvolutionPctVsPrevious;

  /// Estimativa proporcional às calorias do relógio no treino (soma dos scores).
  final double? currentEstimatedKcal;
  final double? previousEstimatedKcal;

  /// Indica se o treino atual tem `watch_calories_kcal` para mostrar a estimativa.
  final bool hasWorkoutWatchKcal;
}
