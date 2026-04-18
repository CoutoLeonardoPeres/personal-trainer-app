/// Contribuição de uma série para o score do exercício: (carga × repetições) ÷ 10.
double perSetScoreContribution({required double loadKg, required int reps}) {
  if (reps < 1) return 0;
  return loadKg * reps / 10.0;
}

/// Score prescrito da linha (sem séries registadas): nº de séries × (carga × reps ÷ 10).
double prescribedExerciseLineScore({
  required int sets,
  required double loadKg,
  required int reps,
}) {
  if (sets <= 0) return 0;
  return sets * perSetScoreContribution(loadKg: loadKg, reps: reps);
}

/// Score final do treino: (Σ score dos exercícios **concluídos**) × 10 ÷ minutos ativos × (nº concluídos).
///
/// Exercício concluído: `sets > 0` e pelo menos `sets` entradas em `performed_sets_json`.
double workoutFinalScoreFromExerciseScores({
  required double exerciseScoresSum,
  required int activeDurationSeconds,
  required int completedExerciseCount,
}) {
  if (activeDurationSeconds <= 0) return 0;
  if (completedExerciseCount <= 0) return 0;
  final minutes = activeDurationSeconds / 60.0;
  if (minutes <= 0) return 0;
  return exerciseScoresSum * 10.0 / minutes * completedExerciseCount;
}

