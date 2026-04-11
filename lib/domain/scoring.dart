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

/// Volume já registrado (soma carga×reps das séries) ÷ minutos de treino **ativo**,
/// multiplicado por **10** — valor gravado em [DayWorkoutEntity.workoutScore] no instante
/// do registro da série (com o tempo ativo daquele momento).
double workoutScoreStoredAtInstant({
  required double performedVolumeSum,
  required int activeDurationSeconds,
}) {
  final minutes = activeDurationSeconds / 60.0;
  if (minutes <= 0) return 0;
  return 10.0 * performedVolumeSum / minutes;
}

/// Legado (sem fator 10). Preferir [workoutScoreStoredAtInstant].
double workoutScorePerActiveMinute({
  required double exercisesScoreSum,
  required int activeDurationSeconds,
}) {
  final minutes = activeDurationSeconds / 60.0;
  if (minutes <= 0) return 0;
  return exercisesScoreSum / minutes;
}
