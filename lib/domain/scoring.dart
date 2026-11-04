/// Escala do score exibido/gravado: volume bruto (carga × reps) ÷ [kScoreScaleDivisor].
const double kScoreScaleDivisor = 10;

/// Contribuição de uma série para o score do exercício: (carga × repetições) ÷ 10.
double perSetScoreContribution({required double loadKg, required int reps}) {
  if (reps < 1) return 0;
  return loadKg * reps / kScoreScaleDivisor;
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

/// Score final do treino: (Σ score dos exercícios **concluídos**) × nº concluídos × 10 ÷ minutos ativos.
///
/// Exercício concluído: `sets > 0` e pelo menos `sets` entradas em `performed_sets_json`.
/// [activeDurationSeconds] é o tempo ativo do treino (timer); mínimo efetivo de 1 s → 1/60 min.
double workoutFinalScoreFromExerciseScores({
  required double exerciseScoresSum,
  required int completedExerciseCount,
  required int activeDurationSeconds,
}) {
  if (completedExerciseCount <= 0) return 0;
  final sec = activeDurationSeconds > 0 ? activeDurationSeconds : 1;
  final minutes = sec / 60.0;
  return exerciseScoresSum * completedExerciseCount * 10.0 / minutes;
}

const _scoreCompareEps = 0.0001;

/// Percentual de execução vs último score registrado (100 = mesmo rendimento; 110 = 10% acima).
double executionPercentVsPrevious({
  required double current,
  required double? previous,
}) {
  if (previous == null) return 100.0;
  if (previous.abs() <= _scoreCompareEps) return 100.0;
  return (current / previous) * 100.0;
}

/// Rótulo do percentual de execução (ex.: `100%`, `110%`, `90%`).
String formatExecutionPercentLabel({
  required double current,
  required double? previous,
}) {
  final pct = executionPercentVsPrevious(current: current, previous: previous);
  final decimals = pct.abs() >= 100 ? 0 : 1;
  return '${pct.toStringAsFixed(decimals).replaceAll('.', ',')}%';
}
