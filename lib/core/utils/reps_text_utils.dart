import '../../data/local/app_database.dart';

/// Extrai um inteiro “de referência” a partir de texto livre (ex.: «12», «12-15»).
/// Usado para o campo legado [reps] e para volume prescrito aproximado.
int? repsHintIntFromText(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final single = int.tryParse(t);
  if (single != null) return single > 0 ? single : null;
  final range = RegExp(r'^(\d+)\s*[-–]\s*(\d+)\s*$').firstMatch(t);
  if (range != null) {
    final a = int.parse(range.group(1)!);
    final b = int.parse(range.group(2)!);
    if (a <= 0 || b <= 0) return null;
    return ((a + b) / 2).round().clamp(1, 9999);
  }
  final m = RegExp(r'\d+').firstMatch(t);
  if (m != null) {
    final n = int.parse(m.group(0)!);
    return n > 0 ? n : null;
  }
  return null;
}

String weekScheduleRepsDisplay(WeekScheduleItemEntity i) {
  final t = i.repsText?.trim();
  if (t != null && t.isNotEmpty) return t;
  if (i.reps > 0) return '${i.reps}';
  return '';
}

bool weekScheduleItemHasValidPrescription(WeekScheduleItemEntity i) {
  if (i.sets <= 0) return false;
  final hint = repsHintIntFromText(weekScheduleRepsDisplay(i));
  return hint != null && hint > 0;
}

String dayWorkoutRepsDisplay(DayWorkoutExerciseEntity e) {
  final t = e.repsText?.trim();
  if (t != null && t.isNotEmpty) return t;
  if (e.reps > 0) return '${e.reps}';
  return '';
}
