// Regras de negócio do calendário (dia civil local).

/// Converte um [DateTime] vindo do SQLite ou do Supabase (muitas vezes UTC) para o
/// **dia civil local** (meia-noite local), alinhado a [DateTime]\(y, m, d\) usado no calendário.
///
/// Assim o bloco `week_start_monday` bate com a segunda-feira do calendário local mesmo após
/// `toUtc()` na ida e `DateTime.parse` na volta.
DateTime weekScheduleLocalCalendarDate(DateTime stored) {
  final local = stored.isUtc ? stored.toLocal() : stored;
  return DateTime(local.year, local.month, local.day);
}

/// Segunda-feira civil local da semana de [stored], para gravar/normalizar `week_schedule_blocks.week_start_monday`.
DateTime normalizeStoredWeekStartMonday(DateTime stored) {
  final cal = weekScheduleLocalCalendarDate(stored);
  final day = DateTime(cal.year, cal.month, cal.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// `true` se [date] (só ano/mês/dia) for **anterior** ao dia de hoje.
bool isCalendarDateBeforeToday(DateTime date) {
  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  return d.isBefore(today);
}
