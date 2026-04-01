import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/exercise_video_web_page.dart';
import '../../core/widgets/swipeable_registry_card.dart'
    show kRegistrySlidableActionRadius;
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';
import 'calendar_add_set_dialog.dart'
    show
        showCalendarAddSetDialog,
        showCalendarEditPerformedSetDialog,
        showFuturisticDeletePerformedSeriesDialog;

/// Data longa em português, ex.: "31 de março de 2026"
String formatCalendarDayHeaderDate(DateTime d) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
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
  if (ex.alternativeVideoUrl != null &&
      ex.alternativeVideoUrl!.trim().isNotEmpty) {
    return true;
  }
  if (ex.alternativeNote != null && ex.alternativeNote!.trim().isNotEmpty) {
    return true;
  }
  return false;
}

String calendarExerciseDisplayName(
  String base,
  ExerciseEntity? ex,
  bool useAlt,
) {
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
          Icon(
            Icons.swap_horiz_rounded,
            color: AppColors.accentPink,
            size: iconSwap,
          ),
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
  const _SerieLoggedRow({required this.index, required this.entry});

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          Icon(
            Icons.swap_horiz_rounded,
            color: AppColors.accentPink,
            size: iconSz,
          ),
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

/// Após fechar o [Slidable], abre diálogo no próximo frame usando o overlay do
/// navigator raiz — evita contexto inválido com bottom sheet + Slidable aninhados.
void _openDialogAfterSlidableClose(
  BuildContext context,
  void Function(BuildContext ctx) body,
) {
  final rootNav = Navigator.of(context, rootNavigator: true);
  final overlayCtx = rootNav.overlay?.context;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = (overlayCtx != null && overlayCtx.mounted)
        ? overlayCtx
        : context;
    if (!ctx.mounted) return;
    body(ctx);
  });
}

Future<bool?> _confirmDialogAfterSlidableClose(
  BuildContext context,
  Future<bool?> Function(BuildContext ctx) showConfirm,
) async {
  final rootNav = Navigator.of(context, rootNavigator: true);
  final overlayCtx = rootNav.overlay?.context;
  final completer = Completer<bool?>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = (overlayCtx != null && overlayCtx.mounted)
        ? overlayCtx
        : context;
    if (!ctx.mounted) {
      completer.complete(null);
      return;
    }
    showConfirm(ctx).then(
      completer.complete,
      onError: (_) => completer.complete(null),
    );
  });
  return completer.future;
}

/// Registro de série com ações ao arrastar para a esquerda (editar / excluir).
class _PerformedSerieSlidableRow extends StatelessWidget {
  const _PerformedSerieSlidableRow({
    required this.repo,
    required this.lineId,
    required this.performedIndex,
    required this.displayIndex,
    required this.entry,
    required this.exerciseLabel,
  });

  final AppDataRepository repo;
  final String lineId;
  final int performedIndex;
  final int displayIndex;
  final DayWorkoutPerformedSet entry;
  final String exerciseLabel;

  Future<void> _onDelete(BuildContext context) async {
    Slidable.of(context)?.close();
    final snackAnchor = Navigator.of(context, rootNavigator: true).context;
    final ok = await _confirmDialogAfterSlidableClose(
      context,
      (ctx) => showFuturisticDeletePerformedSeriesDialog(
        ctx,
        detailLine: 'Série $displayIndex · ${entry.reps} repetições',
      ),
    );
    if (ok != true) return;

    try {
      await repo.removeDayWorkoutExercisePerformedSetAt(
        lineId: lineId,
        performedIndex: performedIndex,
      );
      if (snackAnchor.mounted) {
        ScaffoldMessenger.of(snackAnchor).showSnackBar(
          const SnackBar(content: Text('Série removida.')),
        );
      }
    } on ArgumentError catch (e) {
      if (snackAnchor.mounted) {
        ScaffoldMessenger.of(snackAnchor).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível excluir.')),
        );
      }
    } catch (_) {
      if (snackAnchor.mounted) {
        ScaffoldMessenger.of(snackAnchor).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir.')),
        );
      }
    }
  }

  void _onEdit(BuildContext context) {
    Slidable.of(context)?.close();
    _openDialogAfterSlidableClose(context, (ctx) {
      showCalendarEditPerformedSetDialog(
        context: ctx,
        repo: repo,
        lineId: lineId,
        performedIndex: performedIndex,
        initial: entry,
        exerciseName: exerciseLabel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey('perf_${lineId}_$performedIndex'),
      groupTag: 'performed_$lineId',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: [
          SlidableAction(
            onPressed: (ctx) => _onEdit(ctx),
            backgroundColor: const Color(0xFF26C6DA),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Editar',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(kRegistrySlidableActionRadius),
              bottomLeft: Radius.circular(kRegistrySlidableActionRadius),
            ),
          ),
          SlidableAction(
            onPressed: (ctx) => _onDelete(ctx),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Excluir',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(kRegistrySlidableActionRadius),
              bottomRight: Radius.circular(kRegistrySlidableActionRadius),
            ),
          ),
        ],
      ),
      child: _SerieLoggedRow(index: displayIndex, entry: entry),
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
    this.workoutPaused = false,
    this.useAlternative = false,
    this.onToggleAlternative,
    this.performedSetsRepo,
  });

  final DayWorkoutExerciseEntity line;
  final String exerciseName;
  final ExerciseEntity? exercise;
  final VoidCallback? onAdicionar;
  final bool expandable;

  /// Ex.: `programmed`, `started`, `completed` — vermelho se concluído e faltam séries.
  final String? workoutStatus;

  /// Treino `started` com cronômetro pausado (`timerResumeAt == null`): bloqueia registro de séries.
  final bool workoutPaused;
  final bool useAlternative;

  /// Ao arrastar a barra e tocar na ação rosa; alterna principal ↔ alternativo.
  final VoidCallback? onToggleAlternative;

  /// Quando não nulo, séries registradas na expansão ganham slide Editar/Excluir.
  final AppDataRepository? performedSetsRepo;

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
  State<CalendarExerciseLineCard> createState() =>
      _CalendarExerciseLineCardState();
}

class _CalendarExerciseLineCardState extends State<CalendarExerciseLineCard> {
  var _expanded = false;

  bool get _usesSlidable => widget.onToggleAlternative != null;

  List<DayWorkoutPerformedSet> get _performed =>
      DayWorkoutPerformedSetCodec.decode(widget.line.performedSetsJson);

  /// Só com treino em andamento e cronômetro rodando (não pausado).
  bool get _canMutatePerformedSets =>
      widget.workoutStatus == 'started' && !widget.workoutPaused;

  String get _addSeriesTooltip {
    if (widget.workoutStatus != 'started') {
      return 'Inicie o treino para registrar séries';
    }
    if (widget.workoutPaused) {
      return 'Retome o treino para registrar séries';
    }
    return 'Registrar carga e repetições';
  }

  AppDataRepository? get _repoForPerformedSlidable =>
      _canMutatePerformedSets ? widget.performedSetsRepo : null;

  @override
  void didUpdateWidget(CalendarExerciseLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.id != widget.line.id) {
      _expanded = false;
    }
  }

  void _toggleExpand() {
    if (!widget.expandable) return;
    final nextExpanded = !_expanded;
    if (nextExpanded && _usesSlidable) {
      Slidable.of(context)?.close();
    }
    setState(() => _expanded = nextExpanded);
  }

  void _openVideo(BuildContext context, String url, String title) {
    ExerciseVideoWebPage.showInAppWindow(
      context,
      initialUrl: url,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final load = line.loadKg != null ? ' · ${line.loadKg} kg' : '';
    final volumeFromSets = DayWorkoutPerformedSetCodec.totalVolumeScore(
      _performed,
    );
    final displayScore = _performed.isNotEmpty
        ? volumeFromSets
        : (line.exerciseScore ?? 0);
    final scoreStr = _formatVolumeScore(displayScore);
    final ex = widget.exercise;
    final useAlt = widget.useAlternative;
    final displayName = calendarExerciseDisplayName(
      widget.exerciseName,
      ex,
      useAlt,
    );

    final allSetsDone = line.sets > 0 && _performed.length >= line.sets;
    final incompleteAfterComplete =
        widget.workoutStatus == 'completed' &&
        line.sets > 0 &&
        _performed.length < line.sets;
    final canAddMoreSeries =
        line.sets > 0 && _performed.length < line.sets && widget.onAdicionar != null;

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

    final addPadH = 12.0 * 1.2;
    final addPadV = 6.0 * 1.2;
    final addFontSize = 12.0 * 1.2;

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
      // Altura finita para o Row com stretch dentro do ListView (evita card invisível).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.expandable ? _toggleExpand : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 4, 6),
                      child: Row(
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
                          Icon(
                            Icons.fitness_center_rounded,
                            color: iconTint,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 1,
                                bottom: 1,
                              ),
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
                                  if (videoAction != null && canAddMoreSeries)
                                    const SizedBox(width: 4),
                                  if (canAddMoreSeries)
                                    Tooltip(
                                      message: _addSeriesTooltip,
                                      child: Opacity(
                                        opacity:
                                            _canMutatePerformedSets ? 1 : 0.38,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _canMutatePerformedSets
                                                ? widget.onAdicionar
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: Ink(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: addPadH,
                                                vertical: addPadV,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF26C6DA)
                                                        .withValues(alpha: 0.95),
                                                    AppColors.splashMint
                                                        .withValues(alpha: 0.9),
                                                  ],
                                                ),
                                                boxShadow: _canMutatePerformedSets
                                                    ? [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .splashMint
                                                              .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                          blurRadius: 7,
                                                          offset:
                                                              const Offset(0, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                'Adicionar',
                                                style: TextStyle(
                                                  color: Colors.black87
                                                      .withValues(
                                                    alpha:
                                                        _canMutatePerformedSets
                                                            ? 1
                                                            : 0.55,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: addFontSize,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 112,
                                      ),
                                      child: Text(
                                        '${line.sets}×${line.reps}$load',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.55,
                                          ),
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                              if (_repoForPerformedSlidable != null)
                                _PerformedSerieSlidableRow(
                                  repo: _repoForPerformedSlidable!,
                                  lineId: line.id,
                                  performedIndex: i,
                                  displayIndex: i + 1,
                                  entry: _performed[i],
                                  exerciseLabel: displayName,
                                )
                              else
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
                  if (useAlt)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentPink,
                        borderRadius: BorderRadius.circular(8),
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
            ),
            Container(
              width: 10,
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
      ),
    );

    if (!_usesSlidable) {
      return cardFace;
    }

    // Com o card expandido, desliga o arraste do Slidable pai para o interno
    // (séries registradas — Editar/Excluir) receber o gesto horizontal.
    return Slidable(
      key: ValueKey('${line.id}_alt'),
      enabled: !(widget.expandable && _expanded),
      groupTag: 'exercise_alt_${line.id}',
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: cardFace,
    );
  }
}

String _formatWorkoutTimer(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Pausar cronômetro ou concluir treino (permanece na mesma sheet).
Future<String?> showFuturisticPauseOrCompleteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => const _FuturisticPauseOrCompleteDialog(),
  );
}

/// Treino pausado: retomar cronômetro ou concluir.
Future<String?> showFuturisticResumeOrCompleteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => const _FuturisticResumeOrCompleteDialog(),
  );
}

/// Confirma conclusão quando ainda há exercícios sem todas as séries registradas.
Future<bool?> showFuturisticIncompleteBeforeCompleteDialog(
  BuildContext context, {
  required int incompleteExerciseCount,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => _FuturisticIncompleteBeforeCompleteDialog(
      incompleteExerciseCount: incompleteExerciseCount,
    ),
  );
}

/// Conclui o treino após avisar séries pendentes; retorna se [completeDayWorkout] foi chamado.
Future<bool> tryCompleteDayWorkoutWithIncompletePrompt({
  required BuildContext context,
  required AppDataRepository repo,
  required String dayWorkoutId,
}) async {
  final lines = await repo.getDayWorkoutExercises(dayWorkoutId);
  if (!context.mounted) return false;
  var incomplete = 0;
  for (final line in lines) {
    if (line.sets <= 0) continue;
    final p = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
    if (p.length < line.sets) incomplete++;
  }
  if (incomplete > 0) {
    final confirm = await showFuturisticIncompleteBeforeCompleteDialog(
      context,
      incompleteExerciseCount: incomplete,
    );
    if (confirm != true) return false;
    if (!context.mounted) return false;
  }
  if (!context.mounted) return false;
  await repo.completeDayWorkout(dayWorkoutId);
  return true;
}

/// Modal "Exercícios agendados" — timer no topo após iniciar; concluir abre escolha pausar/concluir.
/// [onSwapWorkout] opcional: substituir treino (só com status programado).
Future<void> showProgrammedDayExercisesSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required DayWorkoutEntity workout,
  required String studentName,
  required DateTime day,
  String? workoutBadgeLabel,
  Future<void> Function(BuildContext sheetContext)? onSwapWorkout,
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
            onSwapWorkout: onSwapWorkout,
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
    this.workoutBadgeLabel,
    this.onSwapWorkout,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final String studentName;
  final DateTime day;
  final DayWorkoutEntity workout;
  final String? workoutBadgeLabel;
  final Future<void> Function(BuildContext sheetContext)? onSwapWorkout;

  @override
  State<_DayExercisesSheetScaffold> createState() =>
      _DayExercisesSheetScaffoldState();
}

class _DayExercisesSheetScaffoldState
    extends State<_DayExercisesSheetScaffold> {
  var _refreshKey = 0;
  final Map<String, bool> _useAlternativeByLineId = {};
  Timer? _tick;
  var _tickerRunning = false;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTickerForWorkout(DayWorkoutEntity w) {
    final run = w.status == 'started' && w.timerResumeAt != null;
    if (run == _tickerRunning) return;
    _tickerRunning = run;
    _tick?.cancel();
    _tick = run
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  Future<void> _onStartWorkout(DayWorkoutEntity w) async {
    await widget.repo.startDayWorkout(w.id);
    if (mounted) setState(() {});
  }

  Future<void> _completeWorkoutAfterChecks(
    BuildContext sheetContext,
    DayWorkoutEntity w,
  ) async {
    final ok = await tryCompleteDayWorkoutWithIncompletePrompt(
      context: sheetContext,
      repo: widget.repo,
      dayWorkoutId: w.id,
    );
    if (!ok || !mounted) return;
    setState(() {});
    if (sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Treino concluído. Score atualizado.')),
      );
    }
  }

  Future<void> _onRunningPrimaryCta(
    BuildContext sheetContext,
    DayWorkoutEntity w,
  ) async {
    final action = await showFuturisticPauseOrCompleteDialog(sheetContext);
    if (!mounted) return;
    if (action == 'pause') {
      await widget.repo.pauseDayWorkout(w.id);
      if (mounted) setState(() {});
      return;
    }
    if (action == 'complete') {
      if (!sheetContext.mounted) return;
      await _completeWorkoutAfterChecks(sheetContext, w);
    }
  }

  Future<void> _onPausedPrimaryCta(
    BuildContext sheetContext,
    DayWorkoutEntity w,
  ) async {
    final action = await showFuturisticResumeOrCompleteDialog(sheetContext);
    if (!mounted) return;
    if (action == 'resume') {
      await widget.repo.resumeDayWorkout(w.id);
      if (mounted) setState(() {});
      return;
    }
    if (action == 'complete') {
      if (!sheetContext.mounted) return;
      await _completeWorkoutAfterChecks(sheetContext, w);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12122A).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: StreamBuilder<DayWorkoutEntity?>(
        stream: widget.repo.watchDayWorkout(widget.workout.id),
        builder: (context, workoutSnap) {
          final w = workoutSnap.data ?? widget.workout;
          _syncTickerForWorkout(w);
          return Column(
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
                padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
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
                    if (w.status == 'programmed' && widget.onSwapWorkout != null)
                      IconButton(
                        icon: Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.accentPink.withValues(alpha: 0.95),
                        ),
                        tooltip: 'Substituir treino',
                        onPressed: () => widget.onSwapWorkout!(context),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: AppColors.accentGreen,
                      ),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final btnW = constraints.maxWidth * 0.32;
                        const iconW = 28.0;
                        const gap = 10.0;
                        final textInset = iconW + gap;
                        final showTimerRow =
                            w.status == 'started' || w.status == 'completed';

                        Widget timerLeading() {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: w.status == 'started' &&
                                        w.timerResumeAt == null
                                    ? const Color(0xFFFFB74D)
                                    : AppColors.accentGreen
                                        .withValues(alpha: 0.9),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatWorkoutTimer(
                                  widget.repo.effectiveActiveSeconds(
                                    w,
                                    DateTime.now(),
                                  ),
                                ),
                                style: TextStyle(
                                  color: w.status == 'started' &&
                                          w.timerResumeAt == null
                                      ? const Color(0xFFFFE082)
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (w.status == 'started' &&
                                  w.timerResumeAt == null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Pausado',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  color: AppColors.splashMint,
                                  size: iconW,
                                ),
                                const SizedBox(width: gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: const Color(
                                            0xFF1565C0,
                                          ).withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF42A5F5,
                                            ).withValues(alpha: 0.6),
                                          ),
                                        ),
                                        child: Text(
                                          widget.workoutBadgeLabel ??
                                              _workoutTagLabel(w.status),
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
                                if (w.status == 'programmed')
                                  SizedBox(
                                    width: btnW,
                                    child: _FuturisticSheetStartWorkoutCta(
                                      compact: true,
                                      onPressed: () => _onStartWorkout(w),
                                    ),
                                  ),
                              ],
                            ),
                            if (showTimerRow) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.only(left: textInset),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(child: timerLeading()),
                                    if (w.status == 'started' &&
                                        w.timerResumeAt != null)
                                      SizedBox(
                                        width: btnW,
                                        child: _FuturisticSheetCompleteWorkoutCta(
                                          compact: true,
                                          onPressed: () =>
                                              _onRunningPrimaryCta(
                                                  context, w),
                                        ),
                                      ),
                                    if (w.status == 'started' &&
                                        w.timerResumeAt == null)
                                      SizedBox(
                                        width: btnW,
                                        child: _FuturisticSheetPausedWorkoutCta(
                                          compact: true,
                                          onPressed: () =>
                                              _onPausedPrimaryCta(
                                                  context, w),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
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
                        stream: widget.repo.watchDayWorkoutExercises(
                          widget.workout.id,
                        ),
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
                                final useAlt =
                                    _useAlternativeByLineId[line.id] ?? false;
                                final performed =
                                    DayWorkoutPerformedSetCodec.decode(
                                      line.performedSetsJson,
                                    );
                                final canAddSerie =
                                    line.sets > 0 && performed.length < line.sets;
                                final dialogTitle = calendarExerciseDisplayName(
                                  name,
                                  ex,
                                  useAlt,
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: CalendarExerciseLineCard(
                                    line: line,
                                    exerciseName: name,
                                    exercise: ex,
                                    expandable: true,
                                    workoutStatus: w.status,
                                    workoutPaused: w.status == 'started' &&
                                        w.timerResumeAt == null,
                                    useAlternative: useAlt,
                                    onToggleAlternative:
                                        calendarExerciseHasAlternative(ex)
                                        ? () => setState(() {
                                              _useAlternativeByLineId[line.id] =
                                                  !(_useAlternativeByLineId[line.id] ??
                                                      false);
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
                                    performedSetsRepo: widget.repo,
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
          );
        },
      ),
    );
  }
}

/// CTA “Iniciar Treino” na sheet — gradiente mint/ciano e brilho discreto.
/// [compact] texto em duas linhas para caber em ~30% da largura do card (canto superior direito).
class _FuturisticSheetStartWorkoutCta extends StatelessWidget {
  const _FuturisticSheetStartWorkoutCta({
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  static const _cyan = Color(0xFF26C6DA);

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.splashMint, _cyan],
    );

    if (compact) {
      return Tooltip(
        message: 'Iniciar Treino',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.splashMint.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Iniciar\nTreino',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w900,
                    fontSize: 11 * 1.3,
                    height: 1.1,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.splashMint.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              'Iniciar Treino',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.88),
                fontWeight: FontWeight.w900,
                fontSize: 15 * 1.3,
                letterSpacing: 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA “Concluir Treino” — roxo/rosa para contrastar com o mint do iniciar.
class _FuturisticSheetCompleteWorkoutCta extends StatelessWidget {
  const _FuturisticSheetCompleteWorkoutCta({
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  static const _violet = Color(0xFF7E57C2);
  static const _magenta = Color(0xFFEC407A);

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_magenta, _violet],
    );

    if (compact) {
      return Tooltip(
        message: 'Concluir Treino',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: _magenta.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Concluir\nTreino',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 11 * 1.3,
                    height: 1.1,
                    letterSpacing: 0.12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: _violet.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              'Concluir Treino',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w900,
                fontSize: 15 * 1.3,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA quando o treino está pausado — âmbar, texto “Treino pausado”.
class _FuturisticSheetPausedWorkoutCta extends StatelessWidget {
  const _FuturisticSheetPausedWorkoutCta({
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  static const _deep = Color(0xFFE65100);
  static const _light = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_deep, Color(0xFFFF9800)],
    );

    if (compact) {
      return Tooltip(
        message: 'Treino pausado — toque para retomar ou concluir',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: _light.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Treino\npausado',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.96),
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5 * 1.3,
                    height: 1.1,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: _deep.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Center(
            child: Text(
              'Treino pausado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontWeight: FontWeight.w900,
                fontSize: 14 * 1.3,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FuturisticPauseOrCompleteDialog extends StatelessWidget {
  const _FuturisticPauseOrCompleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E18),
                  Color(0xFF151028),
                  Color(0xFF0A1220),
                ],
              ),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPink.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPink.withValues(alpha: 0.95),
                        const Color(0xFF7E57C2),
                        AppColors.splashMint,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPink.withValues(alpha: 0.22),
                                  const Color(0xFF7E57C2).withValues(alpha: 0.18),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.accentPink.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: AppColors.accentPink,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Treino em andamento',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Pausar treino para o cronômetro e bloquear o registro de séries, '
                        'ou concluir agora. Ao concluir, o treino fica bloqueado para edição.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'pause'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFF1A1424).withValues(alpha: 0.95),
                              border: Border.all(
                                color: AppColors.splashMint.withValues(alpha: 0.55),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pause_circle_outline_rounded,
                                  color: AppColors.splashMint.withValues(alpha: 0.95),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Pausar treino',
                                  style: TextStyle(
                                    color: AppColors.splashMint.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'complete'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEC407A).withValues(alpha: 0.95),
                                  const Color(0xFF7E57C2).withValues(alpha: 0.92),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEC407A).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Concluir treino',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FuturisticResumeOrCompleteDialog extends StatelessWidget {
  const _FuturisticResumeOrCompleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E18),
                  Color(0xFF151028),
                  Color(0xFF0A1220),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFB74D),
                        AppColors.splashMint,
                        const Color(0xFF7E57C2),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFFB74D).withValues(alpha: 0.22),
                                  const Color(0xFFE65100).withValues(alpha: 0.15),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFB74D).withValues(alpha: 0.55),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.pause_circle_filled_rounded,
                                color: Color(0xFFFFB74D),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Treino pausado',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Deseja retomar o treino (cronômetro e registro de séries) '
                        'ou concluir o treino?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'resume'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [AppColors.splashMint, Color(0xFF26C6DA)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.splashMint.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_rounded,
                                  color: Colors.black.withValues(alpha: 0.82),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Retomar treino',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'complete'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEC407A).withValues(alpha: 0.95),
                                  const Color(0xFF7E57C2).withValues(alpha: 0.92),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEC407A).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Concluir treino',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FuturisticIncompleteBeforeCompleteDialog extends StatelessWidget {
  const _FuturisticIncompleteBeforeCompleteDialog({
    required this.incompleteExerciseCount,
  });

  final int incompleteExerciseCount;

  @override
  Widget build(BuildContext context) {
    final n = incompleteExerciseCount;
    final body = n == 1
        ? 'Ainda há 1 exercício sem todas as séries registradas conforme o planejado.'
        : 'Ainda há $n exercícios sem todas as séries registradas conforme o planejado.';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E18),
                  Color(0xFF151028),
                  Color(0xFF0A1220),
                ],
              ),
              border: Border.all(
                color: AppColors.accentPink.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPink.withValues(alpha: 0.1),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPink.withValues(alpha: 0.95),
                        const Color(0xFFFFB74D),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentPink.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppColors.accentPink.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.accentPink,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Séries pendentes',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deseja concluir o treino mesmo assim? '
                        'O treino ficará bloqueado para edição.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context, false),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context, true),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFEC407A).withValues(alpha: 0.95),
                                        const Color(0xFF7E57C2).withValues(alpha: 0.9),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Concluir assim mesmo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
