import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/exercise_video_web_page.dart';
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';
import 'calendar_active_workout_sheet.dart';
import 'calendar_add_set_dialog.dart';

/// Data longa em português, ex.: "31 de março de 2026"
String formatCalendarDayHeaderDate(DateTime d) {
  const months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];
  final m = months[d.month - 1];
  final monthTitle = m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
  return '${d.day} de $monthTitle de ${d.year}';
}

String _workoutTagLabel(String status) => switch (status) {
      'programmed' => 'Treino programado',
      'started' => 'Em andamento',
      'completed' => 'Concluído',
      _ => 'Treino',
    };

String _formatVolumeScore(double v) {
  if (v == 0) return '0';
  if (v == v.roundToDouble()) return '${v.toInt()}';
  return v.toStringAsFixed(1);
}

/// Cadastro tem vídeo alternativo ou nota alternativa (nome exibido ao alternar).
bool calendarExerciseHasAlternative(ExerciseEntity? ex) {
  if (ex == null) return false;
  if (ex.alternativeVideoUrl != null && ex.alternativeVideoUrl!.trim().isNotEmpty) {
    return true;
  }
  if (ex.alternativeNote != null && ex.alternativeNote!.trim().isNotEmpty) {
    return true;
  }
  return false;
}

String calendarExerciseDisplayName(String base, ExerciseEntity? ex, bool useAlt) {
  if (!useAlt || ex == null) return base;
  final n = ex.alternativeNote?.trim();
  if (n != null && n.isNotEmpty) return n;
  return '$base (alternativo)';
}

/// Escala visual das linhas de série na expansão (~70% do tamanho original).
const double _kSerieScale = 0.7;

/// Linha prescrita (meta da série) — fundo azulado.
class _SeriePrescribedRow extends StatelessWidget {
  const _SeriePrescribedRow({
    required this.index,
    required this.prescribedReps,
  });

  final int index;
  final int prescribedReps;

  @override
  Widget build(BuildContext context) {
    final padH = 12 * _kSerieScale;
    final padV = 10 * _kSerieScale;
    final r = 10 * _kSerieScale;
    final avatarR = 15 * _kSerieScale;
    final gap = 10 * _kSerieScale;
    final smallGap = 6 * _kSerieScale;
    final iconSwap = 22 * _kSerieScale;
    final fsLabel = 14 * _kSerieScale;
    final fsVal = 15 * _kSerieScale;
    final fsIdx = 13 * _kSerieScale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: const Color(0xFF2A5080).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarR,
            backgroundColor: const Color(0xFF1976D2),
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: fsIdx,
              ),
            ),
          ),
          SizedBox(width: gap),
          Icon(Icons.swap_horiz_rounded, color: AppColors.accentPink, size: iconSwap),
          SizedBox(width: smallGap),
          Text(
            'Rep: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: fsLabel,
            ),
          ),
          Text(
            '$prescribedReps',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fsVal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha executada (carga + reps registradas) — só usada quando [entry] existe.
class _SerieLoggedRow extends StatelessWidget {
  const _SerieLoggedRow({
    required this.index,
    required this.entry,
  });

  final int index;
  final DayWorkoutPerformedSet entry;

  static String _fmtLoad(double? kg) {
    if (kg == null) return '—';
    if (kg == kg.roundToDouble()) return '${kg.toInt()}';
    return kg.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final padH = 12 * _kSerieScale;
    final padV = 10 * _kSerieScale;
    final r = 10 * _kSerieScale;
    final avatarR = 15 * _kSerieScale;
    final gap = 10 * _kSerieScale;
    final smallGap = 6 * _kSerieScale;
    final midGap = 8 * _kSerieScale;
    final iconSz = 20 * _kSerieScale;
    final fsMuted = 13 * _kSerieScale;
    final fsVal = 15 * _kSerieScale;
    final fsIdx = 13 * _kSerieScale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E16),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarR,
            backgroundColor: AppColors.accentGreen,
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: fsIdx,
              ),
            ),
          ),
          SizedBox(width: gap),
          Icon(
            Icons.fitness_center_rounded,
            color: const Color(0xFF42A5F5),
            size: iconSz,
          ),
          SizedBox(width: smallGap),
          Text(
            'Carga: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: fsMuted,
            ),
          ),
          Text(
            _fmtLoad(entry.loadKg),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fsVal,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: midGap),
            child: Text(
              '·',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
          Icon(Icons.swap_horiz_rounded, color: AppColors.accentPink, size: iconSz),
          SizedBox(width: 4 * _kSerieScale),
          Text(
            'Rep: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: fsMuted,
            ),
          ),
          Text(
            '${entry.reps}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fsVal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de exercício (lista do dia). Com [expandable], toque no cabeçalho expande as séries.
class CalendarExerciseLineCard extends StatefulWidget {
  const CalendarExerciseLineCard({
    super.key,
    required this.line,
    required this.exerciseName,
    this.exercise,
    this.onAdicionar,
    this.expandable = false,
    this.workoutStatus,
    this.useAlternative = false,
    this.onToggleAlternative,
  });

  final DayWorkoutExerciseEntity line;
  final String exerciseName;
  final ExerciseEntity? exercise;
  final VoidCallback? onAdicionar;
  final bool expandable;
  /// Ex.: `programmed`, `started`, `completed` — vermelho se concluído e faltam séries.
  final String? workoutStatus;
  final bool useAlternative;
  /// Ao arrastar a barra e tocar na ação rosa; alterna principal ↔ alternativo.
  final VoidCallback? onToggleAlternative;

  static bool hasMainVideoLink(ExerciseEntity? ex) {
    if (ex == null) return false;
    final u = ex.videoUrl;
    return u != null && u.trim().isNotEmpty;
  }

  static bool hasAltVideoLink(ExerciseEntity? ex) {
    if (ex == null) return false;
    final u = ex.alternativeVideoUrl;
    return u != null && u.trim().isNotEmpty;
  }

  @override
  State<CalendarExerciseLineCard> createState() => _CalendarExerciseLineCardState();
}

class _CalendarExerciseLineCardState extends State<CalendarExerciseLineCard> {
  var _expanded = false;

  bool get _usesSlidable => widget.onToggleAlternative != null;

  List<DayWorkoutPerformedSet> get _performed =>
      DayWorkoutPerformedSetCodec.decode(widget.line.performedSetsJson);

  @override
  void didUpdateWidget(CalendarExerciseLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.id != widget.line.id) {
      _expanded = false;
    }
  }

  void _toggleExpand() {
    if (!widget.expandable) return;
    setState(() => _expanded = !_expanded);
  }

  void _openVideo(BuildContext context, String url, String title) {
    if (ExerciseVideoWebPage.normalizeVideoUri(url) == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseVideoWebPage(initialUrl: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final load = line.loadKg != null ? ' · ${line.loadKg} kg' : '';
    final volumeFromSets = DayWorkoutPerformedSetCodec.totalVolumeScore(_performed);
    final displayScore =
        _performed.isNotEmpty ? volumeFromSets : (line.exerciseScore ?? 0);
    final scoreStr = _formatVolumeScore(displayScore);
    final ex = widget.exercise;
    final useAlt = widget.useAlternative;
    final displayName = calendarExerciseDisplayName(widget.exerciseName, ex, useAlt);

    final allSetsDone = line.sets > 0 && _performed.length >= line.sets;
    final incompleteAfterComplete = widget.workoutStatus == 'completed' &&
        line.sets > 0 &&
        _performed.length < line.sets;

    late final Color fillColor;
    late final Color borderColor;
    late final Color titleAccent;
    if (incompleteAfterComplete) {
      fillColor = const Color(0xFF2A1518);
      borderColor = AppColors.calendarIncomplete;
      titleAccent = const Color(0xFFFF8A80);
    } else if (allSetsDone) {
      fillColor = const Color(0xFF15261C);
      borderColor = const Color(0xFF43A047);
      titleAccent = AppColors.splashMint;
    } else {
      fillColor = const Color(0xFF152A45);
      borderColor = const Color(0xFF42A5F5);
      titleAccent = const Color(0xFF90CAF9);
    }

    final iconTint = titleAccent;

    final addPadH = 12.0;
    final addPadV = 6.0;
    const addFontSize = 12.0;

    Widget? videoAction;
    if (!useAlt && CalendarExerciseLineCard.hasMainVideoLink(ex)) {
      videoAction = Tooltip(
        message: 'Vídeo do exercício (link do cadastro)',
        child: Material(
          color: AppColors.splashMint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openVideo(
              context,
              ex!.videoUrl!.trim(),
              'Vídeo — ${widget.exerciseName}',
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ),
      );
    } else if (useAlt && CalendarExerciseLineCard.hasAltVideoLink(ex)) {
      videoAction = Tooltip(
        message: 'Vídeo alternativo',
        child: Material(
          color: AppColors.splashMint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openVideo(
              context,
              ex!.alternativeVideoUrl!.trim(),
              'Vídeo — $displayName',
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    final cardFace = Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.22),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.expandable ? _toggleExpand : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 4, 4, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              widget.expandable
                                  ? (_expanded
                                      ? Icons.expand_more_rounded
                                      : Icons.chevron_right_rounded)
                                  : Icons.chevron_right_rounded,
                              color: iconTint,
                              size: 20,
                            ),
                          ),
                          Icon(Icons.fitness_center_rounded, color: iconTint, size: 17),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1, bottom: 1),
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ?videoAction,
                                  if (videoAction != null && widget.onAdicionar != null)
                                    const SizedBox(width: 4),
                                  if (widget.onAdicionar != null)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: widget.onAdicionar,
                                        borderRadius: BorderRadius.circular(999),
                                        child: Ink(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: addPadH,
                                            vertical: addPadV,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF26C6DA)
                                                    .withValues(alpha: 0.95),
                                                AppColors.splashMint.withValues(alpha: 0.9),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.splashMint
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            'Adicionar',
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w700,
                                              fontSize: addFontSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                      '${line.sets}×${line.reps}$load',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.sentiment_neutral_rounded,
                                    size: 15,
                                    color: Colors.amberAccent.shade200,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    scoreStr,
                                    style: TextStyle(
                                      color: Colors.amberAccent.shade200,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (widget.expandable && _expanded && line.sets > 0) ...[
                      SizedBox(height: 10 * _kSerieScale),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 6 * _kSerieScale,
                          right: 2 * _kSerieScale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Séries:',
                              style: TextStyle(
                                color: titleAccent,
                                fontWeight: FontWeight.w800,
                                fontSize: 14 * _kSerieScale,
                              ),
                            ),
                            SizedBox(height: 10 * _kSerieScale),
                            for (var i = 0; i < line.sets; i++) ...[
                              _SeriePrescribedRow(
                                index: i + 1,
                                prescribedReps: line.reps,
                              ),
                              if (i < _performed.length) ...[
                                SizedBox(height: 6 * _kSerieScale),
                                _SerieLoggedRow(
                                  index: i + 1,
                                  entry: _performed[i],
                                ),
                              ],
                              SizedBox(height: 10 * _kSerieScale),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
              Container(
                width: 10,
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      borderColor.withValues(alpha: 0.95),
                      borderColor.withValues(alpha: 0.45),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 14,
                ),
              ),
            ],
          ),
          if (useAlt)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.accentPink,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: const Text(
                'Alternativo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );

    if (!_usesSlidable) {
      return cardFace;
    }

    return Slidable(
      key: ValueKey('${line.id}_alt'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (ctx) {
              widget.onToggleAlternative!();
              Slidable.of(ctx)?.close();
            },
            backgroundColor: AppColors.accentPink,
            foregroundColor: Colors.white,
            icon: Icons.swap_horiz_rounded,
            label: useAlt ? 'Principal' : 'Alternativo',
          ),
        ],
      ),
      child: cardFace,
    );
  }
}

/// Modal "Exercícios agendados" — lista do treino; [programmedStartWorkout] abre o fluxo iniciar/substituir.
Future<void> showProgrammedDayExercisesSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required DayWorkoutEntity workout,
  required String studentName,
  required DateTime day,
  String? workoutBadgeLabel,
  Future<void> Function(BuildContext sheetContext)? programmedStartWorkout,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scroll) {
          return _DayExercisesSheetScaffold(
            scrollController: scroll,
            repo: repo,
            studentName: studentName,
            day: day,
            workout: workout,
            workoutBadgeLabel: workoutBadgeLabel,
            showStartButton: workout.status == 'programmed',
            onStartWorkout: workout.status == 'programmed'
                ? () async {
                    if (programmedStartWorkout != null) {
                      await programmedStartWorkout(sheetCtx);
                      return;
                    }
                    await repo.startDayWorkout(workout.id);
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    if (context.mounted) {
                      showActiveWorkoutSheet(context, workout.id);
                    }
                  }
                : null,
          );
        },
      );
    },
  );
}

class _DayExercisesSheetScaffold extends StatefulWidget {
  const _DayExercisesSheetScaffold({
    required this.scrollController,
    required this.repo,
    required this.studentName,
    required this.day,
    required this.workout,
    required this.showStartButton,
    this.workoutBadgeLabel,
    this.onStartWorkout,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final String studentName;
  final DateTime day;
  final DayWorkoutEntity workout;
  final String? workoutBadgeLabel;
  final bool showStartButton;
  final Future<void> Function()? onStartWorkout;

  @override
  State<_DayExercisesSheetScaffold> createState() =>
      _DayExercisesSheetScaffoldState();
}

class _DayExercisesSheetScaffoldState extends State<_DayExercisesSheetScaffold> {
  var _refreshKey = 0;
  final Map<String, bool> _useAlternativeByLineId = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12122A).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(
          color: AppColors.accentPink.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exercícios Agendados',
                        style: TextStyle(
                          color: AppColors.splashMint,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCalendarDayHeaderDate(widget.day),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AppColors.accentGreen),
                  tooltip: 'Atualizar',
                  onPressed: () => setState(() => _refreshKey++),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.accentPink.withValues(alpha: 0.85),
                    const Color(0xFF5C6BC0).withValues(alpha: 0.9),
                    const Color(0xFF26C6DA).withValues(alpha: 0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPink.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.5),
                  color: const Color(0xFF15182A).withValues(alpha: 0.98),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.person_rounded, color: AppColors.splashMint, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              widget.workoutBadgeLabel ??
                                  _workoutTagLabel(widget.workout.status),
                              style: const TextStyle(
                                color: Color(0xFF90CAF9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showStartButton && widget.onStartWorkout != null)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.splashMint,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => widget.onStartWorkout!(),
                        child: const Text(
                          'Início de treino',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_refreshKey),
              child: StreamBuilder<List<ExerciseEntity>>(
                stream: widget.repo.watchExercisesAlphabetical(),
                builder: (context, exSnap) {
                  final byId = {for (final e in exSnap.data ?? []) e.id: e};
                  return StreamBuilder<List<DayWorkoutExerciseEntity>>(
                    stream: widget.repo.watchDayWorkoutExercises(widget.workout.id),
                    builder: (context, lineSnap) {
                      final lines = lineSnap.data ?? [];
                      if (lines.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhum exercício neste treino.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      return SlidableAutoCloseBehavior(
                        child: ListView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          itemCount: lines.length,
                          itemBuilder: (_, i) {
                            final line = lines[i];
                            final ex = byId[line.exerciseId];
                            final name = ex?.name ?? 'Exercício';
                            final useAlt = _useAlternativeByLineId[line.id] ?? false;
                            final performed =
                                DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
                            final canAddSerie =
                                line.sets > 0 && performed.length < line.sets;
                            final dialogTitle =
                                calendarExerciseDisplayName(name, ex, useAlt);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CalendarExerciseLineCard(
                                line: line,
                                exerciseName: name,
                                exercise: ex,
                                expandable: true,
                                workoutStatus: widget.workout.status,
                                useAlternative: useAlt,
                                onToggleAlternative: calendarExerciseHasAlternative(ex)
                                    ? () => setState(() {
                                          _useAlternativeByLineId[line.id] =
                                              !(_useAlternativeByLineId[line.id] ?? false);
                                        })
                                    : null,
                                onAdicionar: canAddSerie
                                    ? () => showCalendarAddSetDialog(
                                          context: context,
                                          repo: widget.repo,
                                          line: line,
                                          exerciseName: dialogTitle,
                                        )
                                    : null,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
