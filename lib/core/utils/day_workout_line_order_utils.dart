import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';

/// Indica se a linha [line] foi executada fora da ordem planejada em [plannedOrder]
/// (ordem do planejamento = ordem dos itens na lista, tipicamente por [sortOrder]).
///
/// - Enquanto o treino está em andamento: vale se ainda havia exercício anterior
///   sem série registrada.
/// - Com treino concluído: usa o primeiro [DayWorkoutPerformedSet.loggedAtMs] de
///   cada linha; se este exercício foi registrado antes de algum anterior no
///   plano, permanece `true`.
bool dayWorkoutLineExecutedOutOfPlannedOrder(
  List<DayWorkoutExerciseEntity> plannedOrder,
  DayWorkoutExerciseEntity line,
) {
  if (plannedOrder.isEmpty) return false;
  final idxById = <String, int>{
    for (var k = 0; k < plannedOrder.length; k++) plannedOrder[k].id: k,
  };
  final myIdx = idxById[line.id];
  if (myIdx == null) return false;

  final myPerf = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
  if (myPerf.isEmpty) return false;
  final myFirst = DayWorkoutPerformedSetCodec.minLoggedAtMs(myPerf);

  for (var j = 0; j < myIdx; j++) {
    final earlier = plannedOrder[j];
    final earlierPerf =
        DayWorkoutPerformedSetCodec.decode(earlier.performedSetsJson);
    if (earlierPerf.isEmpty) {
      return true;
    }
    final earlierFirst = DayWorkoutPerformedSetCodec.minLoggedAtMs(earlierPerf);
    if (myFirst != null &&
        earlierFirst != null &&
        myFirst < earlierFirst) {
      return true;
    }
  }
  return false;
}
