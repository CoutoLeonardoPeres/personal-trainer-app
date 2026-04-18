import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../domain/scoring.dart' as scoring;

/// Trecho concluído com linhas (mesmo tipo que [AppDataRepository.completedWorkoutSnapshots]).
typedef CompletedWorkoutSnapshot = ({
  DayWorkoutEntity workout,
  List<DayWorkoutExerciseEntity> exercises,
});

/// Fatia agregada por grupo muscular (volume = linhas; rendimento = soma dos scores por linha).
typedef MuscleGroupPieSlice = ({
  String muscleGroupId,
  String name,
  int lineCount,
  double scoreTotal,
});

const _unknownMuscleId = '__unknown_muscle__';

/// Mesma lógica de score por linha do relatório de performance.
double _lineScore(DayWorkoutExerciseEntity line) {
  final performed = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
  final performedScore =
      DayWorkoutPerformedSetCodec.totalExerciseScore(performed);
  return line.exerciseScore ??
      (performedScore > 0
          ? performedScore
          : scoring.prescribedExerciseLineScore(
              sets: line.sets,
              loadKg: line.loadKg ?? 0,
              reps: line.reps,
            ));
}

/// Conta linhas de treino e soma score por grupo muscular (cadastro do exercício).
List<MuscleGroupPieSlice> aggregateMuscleGroupPieSlices(
  List<CompletedWorkoutSnapshot> snapshots,
  Map<String, ExerciseEntity> exerciseById,
  Map<String, MuscleGroupEntity> muscleById,
) {
  final lineByMg = <String, int>{};
  final scoreByMg = <String, double>{};

  for (final snapshot in snapshots) {
    final lines = snapshot.exercises;
    if (lines.isEmpty) continue;

    final lineScores = <String, double>{};
    var workoutScore = 0.0;
    for (final line in lines) {
      final s = _lineScore(line);
      lineScores[line.id] = s;
      workoutScore += s;
    }
    if (workoutScore <= 0) workoutScore = lines.length.toDouble();

    for (final line in lines) {
      final exId = line.exerciseId;
      final mgId = exerciseById[exId]?.muscleGroupId.trim();
      final key = (mgId == null || mgId.isEmpty) ? _unknownMuscleId : mgId;
      lineByMg[key] = (lineByMg[key] ?? 0) + 1;
      scoreByMg[key] = (scoreByMg[key] ?? 0) + (lineScores[line.id] ?? 0);
    }
  }

  String nameFor(String id) {
    if (id == _unknownMuscleId) return 'Outros (sem grupo cadastrado)';
    final row = muscleById[id];
    final n = row == null ? '' : row.name.trim();
    return n.isNotEmpty ? n : 'Grupo';
  }

  final keys = {...lineByMg.keys, ...scoreByMg.keys}.toList();
  if (keys.isEmpty) return [];

  final raw = <MuscleGroupPieSlice>[
    for (final id in keys)
      (
        muscleGroupId: id,
        name: nameFor(id),
        lineCount: lineByMg[id] ?? 0,
        scoreTotal: scoreByMg[id] ?? 0,
      ),
  ];
  raw.sort((a, b) => b.lineCount.compareTo(a.lineCount));
  return raw;
}

/// Junta fatias pequenas em «Demais» para legibilidade no gráfico.
List<MuscleGroupPieSlice> mergeSmallestPieSlices(
  List<MuscleGroupPieSlice> slices,
  int maxVisible,
  int Function(MuscleGroupPieSlice) measure,
) {
  if (slices.length <= maxVisible) return slices;
  final sorted = List<MuscleGroupPieSlice>.from(slices)
    ..sort((a, b) => measure(b).compareTo(measure(a)));
  final head = sorted.take(maxVisible - 1).toList();
  var restCount = 0;
  var restScore = 0.0;
  for (var i = maxVisible - 1; i < sorted.length; i++) {
    restCount += sorted[i].lineCount;
    restScore += sorted[i].scoreTotal;
  }
  head.add((
    muscleGroupId: '__demais__',
    name: 'Demais',
    lineCount: restCount,
    scoreTotal: restScore,
  ));
  return head;
}

String formatPieSlicesForReport(
  List<MuscleGroupPieSlice> slices, {
  required bool byVolume,
}) {
  if (slices.isEmpty) return '- Sem dados.';
  final total = byVolume
      ? slices.fold<int>(0, (a, s) => a + s.lineCount)
      : slices.fold<double>(0, (a, s) => a + s.scoreTotal);
  if (total <= 0) return '- Sem dados.';
  final lines = <String>[];
  for (final s in slices) {
    final v = byVolume ? s.lineCount.toDouble() : s.scoreTotal;
    final pct = (v / total * 100).clamp(0, 100);
    if (byVolume) {
      lines.add('- ${s.name}: ${s.lineCount} exercício(s) no período (${pct.toStringAsFixed(1)}%)');
    } else {
      lines.add(
        '- ${s.name}: score acumulado ${s.scoreTotal.toStringAsFixed(1)} '
        '(${pct.toStringAsFixed(1)}% do total no período)',
      );
    }
  }
  return lines.join('\n');
}
