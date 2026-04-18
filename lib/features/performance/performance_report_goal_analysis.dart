import 'performance_report_document.dart';

String _norm(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Maior número de dias entre dois treinos consecutivos (por data civil).
int maxGapDaysBetweenCompletedWorkouts(List<DateTime> sortedUniqueLocalDays) {
  if (sortedUniqueLocalDays.length < 2) return 0;
  var maxG = 0;
  for (var i = 1; i < sortedUniqueLocalDays.length; i++) {
    final gap = sortedUniqueLocalDays[i]
        .difference(sortedUniqueLocalDays[i - 1])
        .inDays;
    if (gap > maxG) maxG = gap;
  }
  return maxG;
}

/// Respostas com várias opções separadas por «;» (ex.: prioridade na anamnese).
List<String> _anamnesePriorityParts(String raw) {
  return raw
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

void _writelnAnamnesePriority(
  PerformanceReportDocument doc,
  String label,
  String raw,
) {
  final parts = _anamnesePriorityParts(raw);
  if (parts.isEmpty) return;
  doc.write(PerformanceReportSpanStyle.anamneseMeta, label);
  final text = parts.length == 1
      ? parts.single
      : parts
          .asMap()
          .entries
          .map((e) => '${e.key + 1}º ${e.value}')
          .join(' · ');
  doc.writeln(PerformanceReportSpanStyle.anamneseAnswer, text);
}

int? parseAnamneseDaysPerWeek(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('6')) return 6;
  return int.tryParse(t);
}

/// Palavras que aparecem em nomes de grupos musculares do cadastro.
List<String> _hintsForBodyPartToken(String token) {
  final k = _norm(token);
  const map = <String, List<String>>{
    'braços': ['bícep', 'trícep', 'antebr'],
    'peito': ['peitoral'],
    'costas': ['dorsal', 'costas', 'lombar', 'trapé'],
    'abdômen': ['abdômen', 'abdomen'],
    'pernas': ['coxa', 'panturrilha', 'quadríceps'],
    'glúteos': ['glúteo', 'gluteo'],
    'ombros': ['ombro'],
    'corpo inteiro': ['corpo', 'funcional'],
  };
  for (final e in map.entries) {
    if (k.contains(e.key) || e.key.contains(k)) return e.value;
  }
  return [k];
}

bool _muscleNameMatchesBodyGoal(String muscleName, String bodyPartToken) {
  final mn = _norm(muscleName);
  for (final h in _hintsForBodyPartToken(bodyPartToken)) {
    if (mn.contains(h)) return true;
  }
  return false;
}

/// Cruzamento heurístico entre respostas da anamnese e métricas do período.
void appendTrainingVsAnamneseAnalysis(
  PerformanceReportDocument doc, {
  required Map<String, String> latestAnswers,
  required int snapshotCount,
  required double periodWeeks,
  required double avgWorkoutsPerWeek,
  required double avgActiveMinPerWorkout,
  required double avgScorePerWorkout,
  required List<({String mgId, double avgScore})> weakGroups,
  required List<({String mgId, double avgScore})> bestGroups,
  required Map<String, String> muscleNamesById,
  required List<({String exId, double trend, int sessions})> attention,
  required List<DateTime> completedWorkoutLocalDaysSortedUnique,
  required int periodCalendarDays,
}) {
  if (latestAnswers.isEmpty) return;

  doc.writeln(
    PerformanceReportSpanStyle.sectionHeading,
    '7b. Objetivos (anamnese) × treino no período',
  );

  final objetivo =
      (latestAnswers['Principal objetivo'] ?? '').trim();
  final motivaTreinar =
      (latestAnswers['O que mais motiva a treinar?'] ?? '').trim();
  final resultadoLivre =
      (latestAnswers['Descreva o corpo/resultado que gostaria de atingir'] ??
              '')
          .trim();
  final prazo =
      (latestAnswers['Quanto tempo pretende manter o acompanhamento?'] ?? '')
          .trim();
  final diasTxt = latestAnswers['Quantos dias por semana consegue treinar?'];
  final dias = parseAnamneseDaysPerWeek(diasTxt);
  final condicionamento =
      (latestAnswers['Como avalia o condicionamento físico atual?'] ?? '')
          .trim();

  _writelnAnamnesePriority(
    doc,
    'Objetivo declarado (ordem de prioridade): ',
    objetivo,
  );
  _writelnAnamnesePriority(
    doc,
    'O que mais motiva a treinar (prioridade): ',
    motivaTreinar,
  );
  if (resultadoLivre.isNotEmpty) {
    doc.write(PerformanceReportSpanStyle.anamneseMeta, 'Resultado desejado: ');
    doc.writeln(PerformanceReportSpanStyle.anamneseAnswer, resultadoLivre);
  }
  if (prazo.isNotEmpty) {
    doc.write(PerformanceReportSpanStyle.anamneseMeta, 'Prazo de acompanhamento: ');
    doc.writeln(PerformanceReportSpanStyle.anamneseAnswer, prazo);
  }
  doc.write(PerformanceReportSpanStyle.body, '\n');

  void insight(String line) {
    doc.write(PerformanceReportSpanStyle.coachingInsight, '• ');
    doc.writeln(PerformanceReportSpanStyle.coachingInsight, line);
  }

  doc.writeln(
    PerformanceReportSpanStyle.sectionHeading,
    '7c. Adesão ao calendário (treinos concluídos vs anamnese)',
  );
  final uniqueDays = completedWorkoutLocalDaysSortedUnique
      .map(_dateOnly)
      .toList();
  uniqueDays.sort();
  final maxGap = maxGapDaysBetweenCompletedWorkouts(uniqueDays);
  doc.writeln(
    PerformanceReportSpanStyle.body,
    '- Dias distintos com treino concluído no período: ${uniqueDays.length} '
    '(em $periodCalendarDays dias civis da janela do relatório).',
  );
  doc.writeln(
    PerformanceReportSpanStyle.body,
    '- Maior intervalo entre dois treinos concluídos consecutivos (por data): '
    '$maxGap dia(s).',
  );
  if (dias != null) {
    doc.writeln(
      PerformanceReportSpanStyle.body,
      '- Dias/semana que o aluno declarou poder treinar (anamnese): $dias.',
    );
  }
  doc.write(PerformanceReportSpanStyle.body, '\n');

  final wk = periodWeeks > 0 ? snapshotCount / periodWeeks : avgWorkoutsPerWeek;
  if (dias != null && periodWeeks >= 0.5) {
    if (wk + 0.35 < dias) {
      insight(
        'Frequência: na anamnese constam $dias dia(s)/semana disponíveis; a média '
        'no período foi ~${wk.toStringAsFixed(1)} treino(s)/semana. Avalie ajustar '
        'expectativas, priorizar agenda ou reduzir volume por sessão para manter adesão.',
      );
    } else if (wk > dias + 1.0) {
      insight(
        'Frequência: volume no período (~${wk.toStringAsFixed(1)} treinos/semana) está '
        'acima do declarado ($dias). Ótimo para estímulo; monitore fadiga, sono e '
        'lesões.',
      );
    }
  }

  if (maxGap >= 14 && snapshotCount >= 2) {
    insight(
      'Lacunas: intervalo muito longo ($maxGap dias) entre treinos concluídos — '
      'risco de perda de condicionamento e desalinhamento com prazo/objetivos da anamnese.',
    );
  } else if (maxGap >= 10 && snapshotCount >= 2) {
    insight(
      'Lacunas: houve até $maxGap dias sem treino concluído entre duas sessões — '
      'avaliar adesão, viagens, lesão ou carga de trabalho vs objetivos declarados.',
    );
  }

  if (_norm(objetivo).contains('emagrec')) {
    if (avgActiveMinPerWorkout < 32 && snapshotCount >= 3) {
      insight(
        'Emagrecimento: tempo ativo médio por treino (${avgActiveMinPerWorkout.toStringAsFixed(0)} min) '
        'é modesto para gasto energético. Considere estender sessões, densidade ou '
        'blocos metabólicos e revisar hábitos (anamnese: alimentação/álcool/sono).',
      );
    }
  }

  if (_norm(objetivo).contains('massa') ||
      _norm(objetivo).contains('hipertrof') ||
      _norm(objetivo).contains('defini')) {
    if (attention.isNotEmpty) {
      insight(
        'Hipertrofia/definição: há exercícios com queda de score no período — priorizar '
        'progressão de carga ou volume nesses movimentos e revisar técnica/amplitude.',
      );
    }
    if (avgScorePerWorkout > 0 && avgScorePerWorkout < 12 && snapshotCount >= 4) {
      insight(
        'Volume de estímulo (score médio por treino) está baixo; para ganho/definição, '
        'avaliar mais séries efetivas ou seleção de exercícios compostos.',
      );
    }
  }

  if (_norm(condicionamento).contains('iniciante') && avgWorkoutsPerWeek >= 3.5) {
    insight(
      'Condicionamento declarado como iniciante com frequência elevada: validar '
      'recuperação e progressão gradual para evitar sobrecarga.',
    );
  }

  final partesRaw =
      latestAnswers['Parte do corpo que mais gostaria de desenvolver'] ?? '';
  final partes = partesRaw
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  for (final p in partes) {
    for (final w in weakGroups) {
      final name = muscleNamesById[w.mgId] ?? '';
      if (name.isEmpty) continue;
      if (_muscleNameMatchesBodyGoal(name, p)) {
        insight(
          'Prioridade corporal declarada (“$p”) aparece entre grupos com menor score '
          'médio no período (“$name”, ${w.avgScore.toStringAsFixed(1)}). Reforçar '
          'volume, variedade de ângulos ou técnicas avançadas nesse grupo.',
        );
      }
    }
  }

  if (prazo.contains('1 mês') && snapshotCount < 4 && periodWeeks >= 3) {
    insight(
      'Prazo curto declarado (1 mês) com poucos treinos concluídos no período — '
      'alinhar expectativas de resultado com frequência real e intensidade.',
    );
  }
  final prazoN = _norm(prazo);
  if ((prazoN.contains('3') && prazoN.contains('mês')) ||
      prazoN.contains('trimestre')) {
    if (periodWeeks >= 10 && snapshotCount < 18) {
      insight(
        'Prazo declarado na faixa de ~3 meses: com menos de ~18 sessões em '
        '${periodWeeks.toStringAsFixed(0)} semana(s), o ritmo pode ser insuficiente '
        'para objetivos ambiciosos de composição/força — revisar frequência e prioridades.',
      );
    }
  }
  if (prazoN.contains('6') && prazoN.contains('mês')) {
    if (periodWeeks >= 20 && snapshotCount < 40) {
      insight(
        'Prazo longo (≈6 meses) com densidade de treinos relativamente baixa no '
        'período analisado — cruzar com objetivos (massa/definição) e musculatura '
        'prioritária da anamnese.',
      );
    }
  }

  if (bestGroups.isNotEmpty && weakGroups.isNotEmpty) {
    final best = bestGroups.first;
    final weak = weakGroups.last;
    final bn = muscleNamesById[best.mgId] ?? 'Grupo';
    final wn = muscleNamesById[weak.mgId] ?? 'Grupo';
    insight(
      'Comparativo: melhor resposta em $bn (score médio ${best.avgScore.toStringAsFixed(1)}); '
      'menor em $wn (${weak.avgScore.toStringAsFixed(1)}). Redistribuir foco semanais '
      'ou ajustar cargas/reps nos exercícios do grupo mais fraco.',
    );
  }

  doc.write(PerformanceReportSpanStyle.body, '\n');
}

/// Todas as perguntas do formulário com resposta ou «(não informado)», mais chaves
/// extra no mapa — texto pensado para o modelo de IA e para o personal.
void appendLatestAnamneseFullInventoryForAi(
  PerformanceReportDocument doc, {
  required Map<String, String> answers,
  required List<String> questionPromptsInOrder,
}) {
  doc.write(PerformanceReportSpanStyle.body, '\n');
  doc.writeln(
    PerformanceReportSpanStyle.sectionHeading,
    '7a. Inventário completo — última anamnese (todas as perguntas do formulário)',
  );
  doc.writeln(
    PerformanceReportSpanStyle.body,
    'Use esta secção para cruzar hábitos, limitações, sono, objetivos e prioridades '
    'corporais com o que foi efetivamente treinado no período do relatório.',
  );
  doc.write(PerformanceReportSpanStyle.body, '\n');

  final known = <String>{};
  for (final prompt in questionPromptsInOrder) {
    known.add(prompt);
    final v = (answers[prompt] ?? '').trim();
    doc.write(PerformanceReportSpanStyle.anamneseQuestion, '- ');
    doc.writeln(PerformanceReportSpanStyle.anamneseQuestion, prompt);
    doc.writeln(
      PerformanceReportSpanStyle.anamneseAnswer,
      v.isEmpty ? '  (não informado)' : '  $v',
    );
  }

  final extraKeys = answers.keys
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty && !known.contains(k))
      .toList()
    ..sort();
  if (extraKeys.isEmpty) return;

  doc.writeln(
    PerformanceReportSpanStyle.sectionHeading,
    '7a (continuação). Outras respostas gravadas (chaves fora do formulário atual)',
  );
  for (final k in extraKeys) {
    final v = (answers[k] ?? '').trim();
    doc.write(PerformanceReportSpanStyle.anamneseQuestion, '- ');
    doc.writeln(PerformanceReportSpanStyle.anamneseQuestion, k);
    doc.writeln(
      PerformanceReportSpanStyle.anamneseAnswer,
      v.isEmpty ? '  (não informado)' : '  $v',
    );
  }
}
