/// Prefixo legado (dados antigos / sync) — removido na exibição.
const kStudentArchivedNamePrefixLegacy = '(Excluído) ';

/// Prefixo gravado ao arquivar aluno ([AppDataRepository.deleteStudent]).
const kStudentArchivedNamePrefix = '(Inativo) ';

/// Nome ainda com prefixo de inativo mas `is_archived` ausente/falso na nuvem (sync legado).
bool studentNameIndicatesArchivedStub(String rawName) {
  final t = rawName.trim();
  return t.startsWith(kStudentArchivedNamePrefix) ||
      t.startsWith(kStudentArchivedNamePrefixLegacy);
}

/// Remove prefixos de arquivado para exibição (calendário, listas, etc.).
String studentNameWithoutArchivePrefix(String raw) {
  var t = raw.trim();
  for (;;) {
    if (t.startsWith(kStudentArchivedNamePrefix)) {
      t = t.substring(kStudentArchivedNamePrefix.length).trim();
      continue;
    }
    if (t.startsWith(kStudentArchivedNamePrefixLegacy)) {
      t = t.substring(kStudentArchivedNamePrefixLegacy.length).trim();
      continue;
    }
    break;
  }
  return t;
}

/// Treino no calendário: aluno **inativo** só entra em dias **anteriores** à data de inativação
/// (civil local). No dia da inativação e depois, some da grade — exceto fluxo de reativar em Cadastro.
bool isArchivedStudentWorkoutVisibleOnCalendarDay({
  required bool isArchived,
  required DateTime? archivedAt,
  required DateTime workoutCalendarDay,
}) {
  if (!isArchived) return true;
  final d = DateTime(
    workoutCalendarDay.year,
    workoutCalendarDay.month,
    workoutCalendarDay.day,
  );
  if (archivedAt == null) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return d.isBefore(today);
  }
  final archDay = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
  return d.isBefore(archDay);
}
