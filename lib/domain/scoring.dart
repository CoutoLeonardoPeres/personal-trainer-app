/// Contribuição de uma série para o score do exercício: carga × repetições.
double perSetScoreContribution({required double loadKg, required int reps}) {
  if (reps < 1) return 0;
  return loadKg * reps;
}

/// Score prescrito da linha (sem séries registadas): nº de séries × (carga × reps).
double prescribedExerciseLineScore({
  required int sets,
  required double loadKg,
  required int reps,
}) {
  if (sets <= 0) return 0;
  return sets * perSetScoreContribution(loadKg: loadKg, reps: reps);
}

/// Score final do treino: (Σ score dos exercícios **concluídos**) × nº concluídos.
///
/// Exercício concluído: `sets > 0` e pelo menos `sets` entradas em `performed_sets_json`.
/// [activeDurationSeconds] é ignorado (mantido só para compatibilidade de chamadas antigas).
double workoutFinalScoreFromExerciseScores({
  required double exerciseScoresSum,
  required int completedExerciseCount,
  int? activeDurationSeconds,
}) {
  if (completedExerciseCount <= 0) return 0;
  return exerciseScoresSum * completedExerciseCount;
}
