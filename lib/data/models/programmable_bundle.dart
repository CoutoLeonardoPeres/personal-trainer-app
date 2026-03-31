import 'week_schedule_row.dart';

/// Conjunto agendado na semana que pode ser programado num dia (grupo ou avulsos).
class ProgrammableBundle {
  ProgrammableBundle({
    required this.title,
    required this.rows,
    this.workoutGroupId,
  });

  final String title;
  final String? workoutGroupId;
  final List<WeekScheduleRow> rows;
}
