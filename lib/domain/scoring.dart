/// Score por série: carga (kg) × repetições.
double setScore({required double loadKg, required int reps}) => loadKg * reps;

/// Score do exercício: soma das séries.
double exerciseTotalScore(List<double> setScores) =>
    setScores.fold(0.0, (a, b) => a + b);

/// Score do treino: soma dos scores dos exercícios ÷ tempo ativo (segundos).
/// Evita divisão por zero.
double workoutScore({
  required double exercisesScoreSum,
  required int activeDurationSeconds,
}) {
  if (activeDurationSeconds <= 0) return 0;
  return exercisesScoreSum / activeDurationSeconds;
}
