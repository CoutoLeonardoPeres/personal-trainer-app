import '../../core/utils/reps_text_utils.dart';
import '../local/app_database.dart';

/// Item agendado na semana com nome do exercício resolvido (join).
class WeekScheduleRow {
  WeekScheduleRow({
    required this.item,
    required this.exerciseName,
  });

  final WeekScheduleItemEntity item;
  final String exerciseName;

  bool get needsAttention =>
      item.needsDetail || !weekScheduleItemHasValidPrescription(item);
}
