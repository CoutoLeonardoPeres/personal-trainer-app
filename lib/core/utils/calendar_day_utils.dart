// Regras de negócio do calendário (dia civil local).

/// `true` se [date] (só ano/mês/dia) for **anterior** ao dia de hoje.
bool isCalendarDateBeforeToday(DateTime date) {
  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  return d.isBefore(today);
}
