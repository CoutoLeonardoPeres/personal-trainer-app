import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/models/week_schedule_row.dart';

List<List<T>> _comboBlocksFromSorted<T>(
  List<T> sorted,
  String? Function(T) comboIdOf,
) {
  final blocks = <List<T>>[];
  List<T>? open;
  String? openCid;

  void flush() {
    if (open != null) {
      blocks.add(open!);
      open = null;
      openCid = null;
    }
  }

  for (final row in sorted) {
    final raw = comboIdOf(row)?.trim();
    if (raw == null || raw.isEmpty) {
      flush();
      blocks.add([row]);
      continue;
    }
    if (openCid == raw && open != null) {
      open!.add(row);
    } else {
      flush();
      open = [row];
      openCid = raw;
    }
  }
  flush();
  return blocks;
}

/// Agrupa linhas consecutivas (por [sortOrder]) que partilham o mesmo [comboId] não vazio.
List<List<WorkoutGroupExerciseEntity>> workoutGroupLinesAsComboBlocks(
  List<WorkoutGroupExerciseEntity> lines,
) {
  final sorted = List<WorkoutGroupExerciseEntity>.from(lines)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return _comboBlocksFromSorted(sorted, (e) => e.comboId);
}

List<List<WeekScheduleRow>> weekScheduleRowsAsComboBlocks(
  List<WeekScheduleRow> rows,
) {
  final sorted = List<WeekScheduleRow>.from(rows)
    ..sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
  return _comboBlocksFromSorted(sorted, (r) => r.item.comboId);
}

List<List<DayWorkoutExerciseEntity>> dayWorkoutLinesAsComboBlocks(
  List<DayWorkoutExerciseEntity> lines,
) {
  final sorted = List<DayWorkoutExerciseEntity>.from(lines)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return _comboBlocksFromSorted(sorted, (e) => e.comboId);
}

List<DayWorkoutExerciseEntity> flattenDayWorkoutComboBlocks(
  List<List<DayWorkoutExerciseEntity>> blocks,
) {
  return blocks.expand((b) => b).toList();
}

/// Ordena blocos pelo histórico de séries (como a lista plana), mantendo o combo junto.
List<DayWorkoutExerciseEntity> orderDayWorkoutLinesByPerformedHistoryRespectingCombos(
  List<DayWorkoutExerciseEntity> plannedLines,
) {
  final blocks = dayWorkoutLinesAsComboBlocks(plannedLines);
  blocks.sort((ba, bb) {
    final a = ba.first;
    final b = bb.first;
    final aList = DayWorkoutPerformedSetCodec.decode(a.performedSetsJson);
    final bList = DayWorkoutPerformedSetCodec.decode(b.performedSetsJson);
    final aDone = aList.isNotEmpty;
    final bDone = bList.isNotEmpty;
    if (aDone != bDone) return aDone ? -1 : 1;
    if (!aDone) return a.sortOrder.compareTo(b.sortOrder);
    final aMs = DayWorkoutPerformedSetCodec.minLoggedAtMs(aList);
    final bMs = DayWorkoutPerformedSetCodec.minLoggedAtMs(bList);
    if (aMs != null && bMs != null) {
      final c = aMs.compareTo(bMs);
      if (c != 0) return c;
    } else if (aMs != null) {
      return -1;
    } else if (bMs != null) {
      return 1;
    }
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return flattenDayWorkoutComboBlocks(blocks);
}