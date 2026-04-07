import 'local/app_database.dart';

/// Comparação para duplicata (trim + minúsculas).
String normalizeExerciseName(String raw) => raw.trim().toLowerCase();

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var row0 = List<int>.generate(b.length + 1, (i) => i);
  var row1 = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    row1[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final ins = row1[j] + 1;
      final del = row0[j + 1] + 1;
      final sub = row0[j] + cost;
      row1[j + 1] = ins < del ? (ins < sub ? ins : sub) : (del < sub ? del : sub);
    }
    final tmp = row0;
    row0 = row1;
    row1 = tmp;
  }
  return row0[b.length];
}

ExerciseEntity? findDuplicateExerciseByNormalizedName(
  String name,
  List<ExerciseEntity> all, {
  String? excludeExerciseId,
}) {
  final q = normalizeExerciseName(name);
  if (q.isEmpty) return null;
  for (final e in all) {
    if (excludeExerciseId != null && e.id == excludeExerciseId) continue;
    if (normalizeExerciseName(e.name) == q) return e;
  }
  return null;
}

/// Enquanto digita: mesmo nome, contém substring ou nome parecido (Levenshtein).
List<ExerciseEntity> exercisesSimilarForCadastro(
  String rawQuery,
  List<ExerciseEntity> all, {
  String? excludeExerciseId,
  int maxResults = 12,
}) {
  final q = normalizeExerciseName(rawQuery);
  if (q.length < 2) return [];

  final scored = <({ExerciseEntity e, int score})>[];
  for (final e in all) {
    if (excludeExerciseId != null && e.id == excludeExerciseId) continue;
    final en = normalizeExerciseName(e.name);
    if (en.isEmpty) continue;

    var score = 0;
    if (en == q) {
      score = 100000;
    } else if (en.startsWith(q) || q.startsWith(en)) {
      score = 50000 - (en.length - q.length).abs().clamp(0, 200);
    } else if (en.contains(q) || q.contains(en)) {
      score = 30000 - (en.length - q.length).abs().clamp(0, 200);
    } else if (q.length <= 48 && en.length <= 48) {
      final d = _levenshtein(q, en);
      final threshold = q.length <= 5 ? 1 : (q.length <= 14 ? 2 : 3);
      if (d <= threshold) {
        score = 20000 - d * 500 - (en.length - q.length).abs();
      }
    }

    if (score > 0) {
      scored.add((e: e, score: score));
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  final out = <ExerciseEntity>[];
  final seen = <String>{};
  for (final row in scored) {
    if (seen.add(row.e.id)) {
      out.add(row.e);
      if (out.length >= maxResults) break;
    }
  }
  return out;
}
