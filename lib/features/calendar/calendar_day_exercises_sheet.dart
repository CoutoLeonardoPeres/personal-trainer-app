import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/auth/app_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/workout/active_workout_sheet_coordinator.dart';
import '../../core/workout/rest_live_activity_controller.dart';
import '../../core/utils/combo_line_grouping_utils.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/day_workout_line_order_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../core/ui/keyboard_bottom_inset.dart';
import '../../core/widgets/count_up_score_text.dart';
import '../../core/widgets/inter_set_rest_modal.dart';
import '../../core/widgets/modern_loading.dart';
import '../../domain/scoring.dart' as scoring;
import '../../core/ui/exercise_video_web_page.dart';
import '../../core/widgets/swipeable_registry_card.dart'
    show kRegistrySlidableActionRadius;
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';
import 'watch_metrics_after_workout_dialog.dart';
import 'calendar_add_set_dialog.dart'
    show
        showCalendarAddSetDialog,
        showCalendarEditPerformedSetDialog,
        showFuturisticDeletePerformedSeriesDialog;

String _dweRepsCompact(DayWorkoutExerciseEntity line) {
  final d = dayWorkoutRepsDisplay(line);
  return d.isNotEmpty ? d : '${line.reps}';
}

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

/// Linhas com série registrada primeiro, por ordem do primeiro registro
/// ([DayWorkoutPerformedSet.loggedAtMs]); sem registro ou legado sem timestamp ficam por [sortOrder].
List<DayWorkoutExerciseEntity> orderDayWorkoutLinesByPerformedHistory(
  List<DayWorkoutExerciseEntity> plannedLines,
) {
  final sorted = List<DayWorkoutExerciseEntity>.from(plannedLines)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return orderDayWorkoutLinesByPerformedHistoryRespectingCombos(sorted);
}

String _workoutTagLabel(String status) => switch (status) {
  'programmed' => 'Treino programado',
  'started' => 'Em andamento',
  'completed' => 'Concluído',
  _ => 'Treino',
};

String _workoutHeaderDeltaPercentLabel(double current, double? previous) =>
    scoring.formatExecutionPercentLabel(current: current, previous: previous);

Color _workoutHeaderDeltaColor(double current, double? previous) {
  if (previous == null) return const Color(0xFF64B5F6);
  const eps = 0.0001;
  final diff = current - previous;
  if (diff.abs() <= eps) return Colors.amberAccent.shade200;
  if (current > previous + eps) return const Color(0xFF4CAF50);
  return const Color(0xFFEF5350);
}

/// Valor do score no canto direito do card do cabeçalho (ícone + número + % vs treino anterior).
class _CalendarSheetHeaderWorkoutScore extends StatelessWidget {
  const _CalendarSheetHeaderWorkoutScore({
    required this.workout,
    required this.repo,
  });

  final DayWorkoutEntity workout;
  final AppDataRepository repo;

  @override
  Widget build(BuildContext context) {
    const iconSize = 16.0;
    const valueFs = 17.0;
    const pctFs = 14.0;
    final iconColor = AppColors.splashMint.withValues(alpha: 0.9);
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: valueFs,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (workout.status == 'completed') {
      return FutureBuilder<double?>(
        future: repo.resolvedCompletedDayWorkoutScore(workout.id),
        builder: (context, scoreSnap) {
          final cur = scoreSnap.data;
          if (cur == null) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: iconSize,
                    color: iconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '—',
                    style: valueStyle.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }
          return FutureBuilder<double?>(
            future: repo.previousCompletedWorkoutScore(
              dayWorkoutId: workout.id,
            ),
            builder: (context, snap) {
              final prev = snap.data;
              final color = _workoutHeaderDeltaColor(cur, prev);
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: iconSize,
                      color: iconColor,
                    ),
                    const SizedBox(width: 4),
                    CountUpScoreText(
                      key: ValueKey('dw_header_score_${workout.id}'),
                      target: cur,
                      duration: const Duration(milliseconds: 900),
                      format: (v) => v.toStringAsFixed(2),
                      style: valueStyle.copyWith(color: color),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _workoutHeaderDeltaPercentLabel(cur, prev),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: pctFs,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
    if (workout.status == 'started') {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: iconSize, color: iconColor),
            const SizedBox(width: 4),
            Text('—', style: valueStyle.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded, size: iconSize, color: iconColor),
          const SizedBox(width: 4),
          Text('—', style: valueStyle.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

enum _ExerciseScoreTrend { better, worse, same, noPrevious }

class _ExerciseScoreVisual {
  const _ExerciseScoreVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
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

String _formatReferenceLoadKg(double kg) {
  if (kg == kg.roundToDouble()) return '${kg.toInt()}';
  return kg.toStringAsFixed(1).replaceAll('.', ',');
}

String _lastWorkoutSeriesReferenceLabel({
  required double? referenceLastLoadKg,
  required int? referenceLastReps,
}) {
  final kg = referenceLastLoadKg;
  final reps = referenceLastReps;
  if (kg != null) {
    final tail = reps != null ? ' · $reps reps' : '';
    return 'últ. treino ${_formatReferenceLoadKg(kg)} kg$tail';
  }
  if (reps != null) {
    return 'últ. treino · $reps reps';
  }
  return '';
}

/// Linha prescrita (meta da série) — fundo azulado.
/// [onTap] na próxima série vazia: mesmo fluxo do botão Adicionar.
/// [referenceLastLoadKg]/[referenceLastReps]: série homóloga do último treino
/// registrado do mesmo exercício; `null` não mostra nada (ex.: primeira vez).
class _SeriePrescribedRow extends StatelessWidget {
  const _SeriePrescribedRow({
    required this.index,
    required this.prescribedRepsLabel,
    this.onTap,
    this.tooltip,
    this.referenceLastLoadKg,
    this.referenceLastReps,
  });

  final int index;
  final String prescribedRepsLabel;
  final VoidCallback? onTap;
  final String? tooltip;
  final double? referenceLastLoadKg;
  final int? referenceLastReps;

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

    final borderColor = onTap != null
        ? const Color(0xFF42A5F5).withValues(alpha: 0.75)
        : const Color(0xFF2A5080).withValues(alpha: 0.55);

    final body = Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: borderColor),
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
            prescribedRepsLabel,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fsVal,
            ),
          ),
          if (referenceLastLoadKg != null || referenceLastReps != null) ...[
            const Spacer(),
            Text(
              _lastWorkoutSeriesReferenceLabel(
                referenceLastLoadKg: referenceLastLoadKg,
                referenceLastReps: referenceLastReps,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // Mais destaque no treino em execução.
                color: AppColors.splashMint.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
                // +15% na fonte da última carga (pedido na sheet do treino em execução).
                fontSize: fsLabel * 1.15,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;

    Widget ink = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: body,
      ),
    );

    final t = tooltip;
    if (t != null && t.isNotEmpty) {
      return Tooltip(message: t, child: ink);
    }
    return ink;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = (overlayCtx != null && overlayCtx.mounted)
          ? overlayCtx
          : context;
      if (!ctx.mounted) return;
      body(ctx);
    });
  });
}

Future<bool?> _confirmDialogAfterSlidableClose(
  BuildContext context,
  Future<bool?> Function(BuildContext ctx) showConfirm,
) async {
  final rootNav = Navigator.of(context, rootNavigator: true);
  final overlayCtx = rootNav.overlay?.context;
  final completer = Completer<bool?>();
  // Dois frames: o Slidable/tablet pode ainda estar a animar; com um só,
  // o showDialog por vezes não recebe o toque em «Excluir» ou fica preso.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = (overlayCtx != null && overlayCtx.mounted)
          ? overlayCtx
          : context;
      if (!ctx.mounted) {
        completer.complete(null);
        return;
      }
      try {
        completer.complete(await showConfirm(ctx));
      } catch (_) {
        completer.complete(null);
      }
    });
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
    required this.requireAllMetricFields,
  });

  final AppDataRepository repo;
  final String lineId;
  final int performedIndex;
  final int displayIndex;
  final DayWorkoutPerformedSet entry;
  final String exerciseLabel;
  final bool requireAllMetricFields;

  Future<bool> _waitLocalSeriesCount({required int expectedCount}) async {
    for (var i = 0; i < 6; i++) {
      final cur = await repo.getDayWorkoutExerciseById(lineId);
      final count = DayWorkoutPerformedSetCodec.decode(
        cur?.performedSetsJson,
      ).length;
      if (count == expectedCount) return true;
      await Future<void>.delayed(Duration(milliseconds: 80 * (i + 1)));
    }
    return false;
  }

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
      final before = await repo.getDayWorkoutExerciseById(lineId);
      final beforeCount = DayWorkoutPerformedSetCodec.decode(
        before?.performedSetsJson,
      ).length;
      await repo.removeDayWorkoutExercisePerformedSetAt(
        lineId: lineId,
        performedIndex: performedIndex,
      );
      final expected = beforeCount > 0 ? beforeCount - 1 : 0;
      final okPersist = await _waitLocalSeriesCount(expectedCount: expected);
      if (!okPersist) {
        throw StateError('remove_not_confirmed_locally');
      }
      if (snackAnchor.mounted) {
        ScaffoldMessenger.of(
          snackAnchor,
        ).showSnackBar(const SnackBar(content: Text('Série removida.')));
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
        requireAllMetricFields: requireAllMetricFields,
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
    this.executedOutOfPlannedOrder = false,
    this.forceExpanded = false,
    this.collapseSignal = 0,
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
  /// Com [workoutStatus] `completed`, ou quando todas as séries planejadas já foram
  /// registradas, o gesto fica desligado (não passar callback).
  final VoidCallback? onToggleAlternative;

  /// Quando não nulo, séries registradas na expansão ganham slide Editar/Excluir.
  final AppDataRepository? performedSetsRepo;

  /// Exercício com série registrada antes de algum anterior ainda não iniciado na ordem planejada.
  final bool executedOutOfPlannedOrder;
  final bool forceExpanded;
  final int collapseSignal;

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
  Future<double?>? _previousScoreFuture;
  String? _comparisonKey;
  Future<List<DayWorkoutPerformedSet>>? _referenceLastPerformedSetsFuture;
  String? _referenceLastPerformedSetsKey;

  bool get _usesSlidable =>
      widget.onToggleAlternative != null && widget.workoutStatus != 'completed';

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

  Future<double?> _resolvePreviousScore() async {
    final repo = widget.performedSetsRepo;
    if (repo == null) return null;
    return repo.previousCompletedExerciseScoreForWorkout(
      dayWorkoutId: widget.line.dayWorkoutId,
      exerciseId: widget.line.exerciseId,
    );
  }

  Future<double?> _previousScore() {
    final key = '${widget.line.dayWorkoutId}|${widget.line.exerciseId}';
    if (_previousScoreFuture != null && _comparisonKey == key) {
      return _previousScoreFuture!;
    }
    _comparisonKey = key;
    _previousScoreFuture = _resolvePreviousScore();
    return _previousScoreFuture!;
  }

  Future<List<DayWorkoutPerformedSet>> _referenceLastPerformedSetsSeed() {
    final key = widget.line.id;
    if (_referenceLastPerformedSetsFuture != null &&
        _referenceLastPerformedSetsKey == key) {
      return _referenceLastPerformedSetsFuture!;
    }
    _referenceLastPerformedSetsKey = key;
    final repo = widget.performedSetsRepo;
    if (repo == null) {
      _referenceLastPerformedSetsFuture =
          Future<List<DayWorkoutPerformedSet>>.value(
            const <DayWorkoutPerformedSet>[],
          );
    } else {
      final cached = repo.cachedLastPerformedSetsSeedForLine(widget.line.id);
      _referenceLastPerformedSetsFuture = cached == null
          ? repo.lastPerformedSetsSeedForLine(widget.line.id)
          : Future<List<DayWorkoutPerformedSet>>.value(cached);
    }
    return _referenceLastPerformedSetsFuture!;
  }

  _ExerciseScoreTrend _scoreTrend(double current, double? previous) {
    if (previous == null) return _ExerciseScoreTrend.noPrevious;
    const eps = 0.0001;
    final diff = current - previous;
    if (diff > eps) return _ExerciseScoreTrend.better;
    if (diff < -eps) return _ExerciseScoreTrend.worse;
    return _ExerciseScoreTrend.same;
  }

  _ExerciseScoreVisual _scoreVisual(_ExerciseScoreTrend trend) {
    return _ExerciseScoreVisual(
      icon: switch (trend) {
        _ExerciseScoreTrend.better => Icons.sentiment_very_satisfied_rounded,
        _ExerciseScoreTrend.worse => Icons.sentiment_very_dissatisfied_rounded,
        _ => Icons.sentiment_neutral_rounded,
      },
      color: switch (trend) {
        _ExerciseScoreTrend.noPrevious => const Color(0xFF64B5F6),
        _ExerciseScoreTrend.same => Colors.amberAccent.shade200,
        _ExerciseScoreTrend.better => const Color(0xFF4CAF50),
        _ExerciseScoreTrend.worse => const Color(0xFFEF5350),
      },
    );
  }

  String _scoreDeltaPercentLabel(double current, double? previous) =>
      scoring.formatExecutionPercentLabel(current: current, previous: previous);

  @override
  void didUpdateWidget(CalendarExerciseLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.id != widget.line.id) {
      _expanded = false;
    }
    if (oldWidget.line.dayWorkoutId != widget.line.dayWorkoutId ||
        oldWidget.line.exerciseId != widget.line.exerciseId ||
        oldWidget.performedSetsRepo != widget.performedSetsRepo ||
        oldWidget.workoutStatus != widget.workoutStatus) {
      _comparisonKey = null;
      _previousScoreFuture = null;
      _referenceLastPerformedSetsKey = null;
      _referenceLastPerformedSetsFuture = null;
    }
    if (oldWidget.collapseSignal != widget.collapseSignal) {
      _expanded = false;
    }
    if (widget.forceExpanded &&
        (!oldWidget.forceExpanded ||
            oldWidget.collapseSignal != widget.collapseSignal)) {
      _expanded = true;
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
    final scoreFromSets = DayWorkoutPerformedSetCodec.totalExerciseScore(
      _performed,
    );
    final hasLoggedSetsThisSession = _performed.isNotEmpty;
    final awaitingFirstSetThisSession =
        widget.workoutStatus == 'started' && !hasLoggedSetsThisSession;
    final displayScore = awaitingFirstSetThisSession
        ? 0.0
        : hasLoggedSetsThisSession
        ? scoreFromSets
        : (line.exerciseScore ??
              scoring.prescribedExerciseLineScore(
                sets: line.sets,
                loadKg: line.loadKg ?? 0,
                reps: line.reps,
              ));
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
        line.sets > 0 &&
        _performed.length < line.sets &&
        widget.onAdicionar != null;

    late final Color fillColor;
    late final Color borderColor;
    late final Color titleAccent;
    if (incompleteAfterComplete) {
      fillColor = const Color(0xFF2A1518);
      borderColor = AppColors.calendarIncomplete;
      titleAccent = const Color(0xFFFF8A80);
    } else if (allSetsDone) {
      const completedGreen = Color(0xFF2E7D32);
      fillColor = completedGreen.withValues(alpha: 0.20);
      borderColor = completedGreen.withValues(alpha: 0.2);
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
                              padding: const EdgeInsets.only(top: 1, bottom: 1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
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
                                  const SizedBox(height: 4),
                                  Text(
                                    '${line.sets}×${_dweRepsCompact(line)}$load',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 12.65,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                                        opacity: _canMutatePerformedSets
                                            ? 1
                                            : 0.38,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _canMutatePerformedSets
                                                ? widget.onAdicionar
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
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
                                                    const Color(
                                                      0xFF26C6DA,
                                                    ).withValues(alpha: 0.95),
                                                    AppColors.splashMint
                                                        .withValues(alpha: 0.9),
                                                  ],
                                                ),
                                                boxShadow:
                                                    _canMutatePerformedSets
                                                    ? [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .splashMint
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                          blurRadius: 7,
                                                          offset: const Offset(
                                                            0,
                                                            1,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                'Adicionar',
                                                style: TextStyle(
                                                  color: Colors.black87.withValues(
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
                              const SizedBox(height: 6),
                              FutureBuilder<double?>(
                                future: _previousScore(),
                                builder: (context, snap) {
                                  final previous = snap.data;
                                  final trend = awaitingFirstSetThisSession
                                      ? (previous == null
                                            ? _ExerciseScoreTrend.noPrevious
                                            : _ExerciseScoreTrend.same)
                                      : _scoreTrend(displayScore, previous);
                                  final v = _scoreVisual(trend);
                                  final percentLabel =
                                      awaitingFirstSetThisSession
                                      ? scoring.formatExecutionPercentLabel(
                                          current: 0,
                                          previous: null,
                                        )
                                      : _scoreDeltaPercentLabel(
                                          displayScore,
                                          previous,
                                        );
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CountUpScoreText(
                                        key: ValueKey('ex_score_${line.id}'),
                                        target: displayScore,
                                        duration: const Duration(
                                          milliseconds: 650,
                                        ),
                                        style: TextStyle(
                                          color: v.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.8,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        percentLabel,
                                        style: TextStyle(
                                          color: v.color,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.8,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.executedOutOfPlannedOrder)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.swap_vert_circle_rounded,
                            color: const Color(
                              0xFFFF8A65,
                            ).withValues(alpha: 0.95),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Executado fora da ordem planejada',
                              style: TextStyle(
                                color: const Color(
                                  0xFFFF8A65,
                                ).withValues(alpha: 0.95),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.expandable && _expanded && line.sets > 0) ...[
                    SizedBox(height: 10 * _kSerieScale),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 6 * _kSerieScale,
                        right: 2 * _kSerieScale,
                      ),
                      child: FutureBuilder<List<DayWorkoutPerformedSet>>(
                        future: _referenceLastPerformedSetsSeed(),
                        builder: (context, refSnap) {
                          final referenceSets =
                              refSnap.data ?? const <DayWorkoutPerformedSet>[];
                          return Column(
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
                                  prescribedRepsLabel: _dweRepsCompact(line),
                                  referenceLastLoadKg: i < referenceSets.length
                                      ? referenceSets[i].loadKg
                                      : null,
                                  referenceLastReps: i < referenceSets.length
                                      ? referenceSets[i].reps
                                      : null,
                                  onTap:
                                      i == _performed.length &&
                                          canAddMoreSeries &&
                                          _canMutatePerformedSets
                                      ? widget.onAdicionar
                                      : null,
                                  tooltip:
                                      i == _performed.length &&
                                          canAddMoreSeries &&
                                          _canMutatePerformedSets
                                      ? _addSeriesTooltip
                                      : null,
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
                                      requireAllMetricFields:
                                          widget.workoutStatus == 'started',
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
                          );
                        },
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

class _WorkoutTimerLeading extends StatefulWidget {
  const _WorkoutTimerLeading({
    required this.repo,
    required this.workout,
    this.compact = false,
  });

  final AppDataRepository repo;
  final DayWorkoutEntity workout;
  final bool compact;

  @override
  State<_WorkoutTimerLeading> createState() => _WorkoutTimerLeadingState();
}

class _WorkoutTimerLeadingState extends State<_WorkoutTimerLeading> {
  Timer? _tick;

  bool get _running =>
      widget.workout.status == 'started' &&
      widget.workout.timerResumeAt != null;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(covariant _WorkoutTimerLeading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout.status != widget.workout.status ||
        oldWidget.workout.timerResumeAt != widget.workout.timerResumeAt) {
      _syncTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTick() {
    _tick?.cancel();
    _tick = _running
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final iconSz = compact ? 17.0 : 20.0;
    final timeFs = compact ? 16.0 : 20.0;
    final w = widget.workout;
    final paused = w.status == 'started' && w.timerResumeAt == null;
    final color = paused
        ? const Color(0xFFFFB74D)
        : AppColors.accentGreen.withValues(alpha: 0.9);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, color: color, size: iconSz),
        const SizedBox(width: 5),
        Text(
          _formatWorkoutTimer(
            widget.repo.effectiveActiveSeconds(w, DateTime.now()),
          ),
          style: TextStyle(
            color: paused ? const Color(0xFFFFE082) : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: timeFs,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (paused) ...[
          const SizedBox(width: 6),
          Text(
            'Pausado',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

/// Evita tap-through: o toque que fecha o overlay não deve acionar botões por baixo
/// (ex.: reabrir «Registrar série» logo após fechar o cronômetro entre séries).
void _schedulePopDialogResult(BuildContext dialogContext, Object? result) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext, rootNavigator: true).pop(result);
  });
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

Future<String?> showFuturisticStartOrSwapDialog(
  BuildContext context, {
  required bool canSwap,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => _FuturisticStartOrSwapDialog(canSwap: canSwap),
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
  required AppSession session,
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
  if (session.isStudent && context.mounted) {
    await showWatchMetricsAfterWorkoutDialog(
      context: context,
      repo: repo,
      dayWorkoutId: dayWorkoutId,
    );
  }
  return true;
}

/// Modal "Exercícios agendados" — timer no topo após iniciar; concluir abre escolha pausar/concluir.
/// [onSwapWorkout] opcional: substituir treino (só com status programado).
Future<void> showProgrammedDayExercisesSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required DayWorkoutEntity workout,
  required String studentName,
  bool studentInactive = false,
  required DateTime day,
  String? workoutBadgeLabel,
  Future<void> Function(BuildContext sheetContext)? onSwapWorkout,
  bool showRestTimerOverlayFromLive = false,
}) async {
  await ActiveWorkoutSheetCoordinator.openSingleton(workout.id, () async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      routeSettings: RouteSettings(
        name: 'programmed_day_exercises_sheet',
        arguments: workout.id,
      ),
      builder: (sheetCtx) {
        ActiveWorkoutSheetCoordinator.registerSheet(workout.id, () {
          if (sheetCtx.mounted) {
            Navigator.of(sheetCtx, rootNavigator: true).pop();
          }
        });
        return KeyboardBottomInsetPadding(
          child: DraggableScrollableSheet(
            initialChildSize: 0.87,
            minChildSize: 0.45,
            maxChildSize: 0.87,
            expand: false,
            builder: (context, scroll) {
              return _DayExercisesSheetScaffold(
                scrollController: scroll,
                repo: repo,
                studentName: studentName,
                studentInactive: studentInactive,
                day: day,
                workout: workout,
                workoutBadgeLabel: workoutBadgeLabel,
                onSwapWorkout: onSwapWorkout,
                showRestTimerOverlayFromLive: showRestTimerOverlayFromLive,
              );
            },
          ),
        );
      },
    );
  });
}

class _DayExercisesSheetScaffold extends StatefulWidget {
  const _DayExercisesSheetScaffold({
    required this.scrollController,
    required this.repo,
    required this.studentName,
    this.studentInactive = false,
    required this.day,
    required this.workout,
    this.workoutBadgeLabel,
    this.onSwapWorkout,
    this.showRestTimerOverlayFromLive = false,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final String studentName;
  final bool studentInactive;
  final DateTime day;
  final DayWorkoutEntity workout;
  final String? workoutBadgeLabel;
  final Future<void> Function(BuildContext sheetContext)? onSwapWorkout;
  final bool showRestTimerOverlayFromLive;

  @override
  State<_DayExercisesSheetScaffold> createState() =>
      _DayExercisesSheetScaffoldState();
}

class _DayExercisesSheetScaffoldState
    extends State<_DayExercisesSheetScaffold> {
  var _refreshKey = 0;
  final Map<String, bool> _useAlternativeByLineId = {};
  var _restPopupOpenAttempted = false;
  var _focusCurrentExerciseAfterRestClose = false;
  var _repairingInitialExercises = false;
  var _hasLoadedAnyExerciseLine = false;
  var _cloudHydrationInFlight = false;
  var _cloudHydrationDone = false;
  var _cloudRefreshRequestInFlight = false;
  var _activeWorkoutRescueInFlight = false;
  var _activeWorkoutRescueTriggered = false;
  var _catalogHydrationInFlight = false;
  DateTime? _lastCatalogHydrationAttemptAt;
  final Map<String, String> _exerciseNameCacheById = <String, String>{};
  final Map<String, DateTime> _missingExerciseNameFirstSeenAt =
      <String, DateTime>{};
  List<DayWorkoutExerciseEntity>? _bootstrapLines;
  final DateTime _sheetOpenedAt = DateTime.now();
  String? _forceExpandedLineId;
  var _collapseAllSignal = 0;
  Set<String> _lastMissingExerciseIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _repairingInitialExercises = true;
    if (widget.showRestTimerOverlayFromLive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_tryOpenRestTimerOverlayFromLive());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final local = await widget.repo
            .getDayWorkoutExercises(widget.workout.id)
            .timeout(
              const Duration(milliseconds: 450),
              onTimeout: () => const [],
            );
        if (mounted && local.isNotEmpty) {
          setState(() {
            _bootstrapLines = local;
            _hasLoadedAnyExerciseLine = true;
          });
        }
      } catch (_) {
        // Best effort: segue com stream.
      }
      try {
        final n = await widget.repo
            .repairDayWorkoutExercisesFromSourceGroupIfNeeded(widget.workout.id)
            .timeout(const Duration(seconds: 10), onTimeout: () => 0);
        if (mounted && n > 0) {
          // O stream de linhas já notifica alterações; evitar rebuild total
          // da sheet aqui elimina o "refresh" visual logo após abrir.
          setState(() {});
        }
      } catch (_) {
        // Sem permissão ou dados inconsistentes: mantém a lista atual.
      } finally {
        if (mounted) {
          setState(() => _repairingInitialExercises = false);
        } else {
          _repairingInitialExercises = false;
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateWorkoutLinesFromCloud());
    });
    // Evita loading infinito se pull/rede ou flags de hidratação ficarem presos.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 9), () {
        if (!mounted) return;
        if (!_cloudHydrationDone) {
          setState(() {
            _cloudHydrationDone = true;
            _cloudHydrationInFlight = false;
          });
        }
      }),
    );
  }

  Future<void> _hydrateWorkoutLinesFromCloud({bool silentUi = false}) async {
    if (_cloudRefreshRequestInFlight) return;
    _cloudRefreshRequestInFlight = true;
    var hydratedSuccessfully = false;
    try {
      if (!silentUi && mounted) {
        setState(() => _cloudHydrationInFlight = true);
      } else {
        _cloudHydrationInFlight = true;
      }
      try {
        await widget.repo
            .refreshDayWorkoutFromCloud(widget.workout.id)
            .timeout(const Duration(seconds: 8));
        hydratedSuccessfully = true;
      } catch (_) {
        // Best effort: mantém snapshot local e tenta de novo no polling.
      } finally {
        final canMarkHydrationDone =
            hydratedSuccessfully || _hasLoadedAnyExerciseLine;
        if (!silentUi && mounted) {
          setState(() {
            _cloudHydrationDone = canMarkHydrationDone;
            _cloudHydrationInFlight = false;
          });
        } else {
          _cloudHydrationDone = canMarkHydrationDone;
          _cloudHydrationInFlight = false;
        }
      }
    } finally {
      _cloudRefreshRequestInFlight = false;
    }
  }

  Future<void> _rescueActiveWorkoutLines() async {
    if (_activeWorkoutRescueInFlight) return;
    _activeWorkoutRescueInFlight = true;
    try {
      try {
        await widget.repo
            .repairDayWorkoutExercisesFromSourceGroupIfNeeded(widget.workout.id)
            .timeout(const Duration(seconds: 5), onTimeout: () => 0);
      } catch (_) {
        // best effort
      }
      await _hydrateWorkoutLinesFromCloud(silentUi: true);
    } finally {
      _activeWorkoutRescueInFlight = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _hydrateMissingExercisesCatalog(
    Set<String> missingExerciseIds,
  ) async {
    if (missingExerciseIds.isEmpty) return;
    if (_catalogHydrationInFlight) return;
    final now = DateTime.now();
    final lastAttempt = _lastCatalogHydrationAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 2)) {
      return;
    }
    if (setEquals(missingExerciseIds, _lastMissingExerciseIds) &&
        lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 8)) {
      return;
    }
    _lastCatalogHydrationAttemptAt = now;
    _catalogHydrationInFlight = true;
    if (mounted) setState(() {});
    try {
      final localExercises = await widget.repo
          .getExercisesByIds(missingExerciseIds)
          .timeout(
            const Duration(milliseconds: 500),
            onTimeout: () => const [],
          );
      for (final e in localExercises) {
        final n = e.name.trim();
        if (n.isNotEmpty) {
          _exerciseNameCacheById[e.id] = n;
        }
      }
      await widget.repo
          .refreshExercisesByIdsFromCloud(missingExerciseIds)
          .timeout(const Duration(seconds: 7), onTimeout: () {});
      await widget.repo.refreshExercisesCatalogFromCloud().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      _lastMissingExerciseIds = Set<String>.from(missingExerciseIds);
    } catch (_) {
      // Permite nova tentativa automática no próximo rebuild.
      _lastMissingExerciseIds = const <String>{};
    } finally {
      _catalogHydrationInFlight = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _tryOpenRestTimerOverlayFromLive() async {
    if (!mounted || _restPopupOpenAttempted) return;
    _restPopupOpenAttempted = true;
    final rest = context.read<RestLiveActivityController>();
    if (!rest.hasRestSession) return;
    final prescribedSec = rest.prescribedSec;
    if (prescribedSec <= 0) return;
    await showInterSetRestModal(context: context, prescribedSec: prescribedSec);
    if (!mounted) return;
    // Só foco na linha atual — não incrementar [_refreshKey]: isso remontava
    // toda a lista e o [CountUpScoreText] de todos os exercícios animava de novo.
    setState(() {
      _focusCurrentExerciseAfterRestClose = true;
    });
  }

  String? _lineBeingFilledId(List<DayWorkoutExerciseEntity> lines) {
    var bestLoggedAtMs = -1;
    String? bestLineId;
    for (final line in lines) {
      final sets = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
      for (final s in sets) {
        final ms = s.loggedAtMs ?? -1;
        if (ms > bestLoggedAtMs) {
          bestLoggedAtMs = ms;
          bestLineId = line.id;
        }
      }
    }
    if (bestLineId != null) return bestLineId;
    if (lines.isEmpty) return null;
    return lines.first.id;
  }

  void _scheduleFocusCurrentExerciseAfterRestClose(
    List<DayWorkoutExerciseEntity> lines,
  ) {
    if (!_focusCurrentExerciseAfterRestClose || lines.isEmpty) return;
    final targetLineId = _lineBeingFilledId(lines);
    if (targetLineId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusCurrentExerciseAfterRestClose) return;
      setState(() {
        _focusCurrentExerciseAfterRestClose = false;
        _collapseAllSignal++;
        _forceExpandedLineId = targetLineId;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onStartWorkout(
    BuildContext sheetContext,
    DayWorkoutEntity w,
  ) async {
    if (isCalendarDateBeforeToday(weekScheduleLocalCalendarDate(w.dayDate))) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text('Treinos em datas passadas não podem ser iniciados.'),
        ),
      );
      return;
    }
    final canSwap = widget.onSwapWorkout != null;
    final action = await showFuturisticStartOrSwapDialog(
      sheetContext,
      canSwap: canSwap,
    );
    if (!mounted) return;
    if (action == null || action == 'cancel') return;
    if (action == 'swap' && canSwap) {
      if (!sheetContext.mounted) return;
      await widget.onSwapWorkout!(sheetContext);
      return;
    }
    if (action != 'start') return;

    try {
      await widget.repo.startDayWorkout(w.id);
      if (mounted) setState(() {});
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Não foi possível iniciar o treino.'),
        ),
      );
    }
  }

  Future<void> _completeWorkoutAfterChecks(
    BuildContext sheetContext,
    DayWorkoutEntity w,
  ) async {
    final session = context.read<AppSession>();
    final ok = await tryCompleteDayWorkoutWithIncompletePrompt(
      context: sheetContext,
      repo: widget.repo,
      session: session,
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
                    if (w.status == 'programmed' &&
                        widget.onSwapWorkout != null)
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
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textPrimary,
                      ),
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
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.5),
                      color: const Color(0xFF15182A).withValues(alpha: 0.98),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final btnW = constraints.maxWidth * 0.32;
                        const iconW = 26.0;
                        const gap = 8.0;
                        final workoutDate = weekScheduleLocalCalendarDate(
                          w.dayDate,
                        );
                        final isPastProgrammedWorkout =
                            w.status == 'programmed' &&
                            isCalendarDateBeforeToday(workoutDate);
                        final showTimerRow =
                            w.status == 'started' || w.status == 'completed';
                        final workoutTitle =
                            widget.workoutBadgeLabel ??
                            _workoutTagLabel(w.status);

                        /// Nome do treino: +20% em relação à base 15 → 18.
                        const kStudentNameFontSize = 16.0;
                        final workoutTitleFontSize = 15.0 * 1.2;
                        const kGapStudentToWorkout = 12.0;
                        const kGapWorkoutToTimer = 12.0;

                        Widget timerLeading({bool compact = false}) {
                          return _WorkoutTimerLeading(
                            repo: widget.repo,
                            workout: w,
                            compact: compact,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  widget.studentInactive
                                      ? Icons.person_off_rounded
                                      : Icons.person_rounded,
                                  color: widget.studentInactive
                                      ? const Color(0xFFFFB74D)
                                      : AppColors.splashMint,
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: kStudentNameFontSize,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (widget.studentInactive) ...[
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.archive_outlined,
                                              size: 13,
                                              color: const Color(
                                                0xFFFFB74D,
                                              ).withValues(alpha: 0.95),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Aluno inativo',
                                              style: TextStyle(
                                                color: const Color(
                                                  0xFFFFB74D,
                                                ).withValues(alpha: 0.95),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(
                                        height: kGapStudentToWorkout,
                                      ),
                                      Text(
                                        workoutTitle,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(
                                            0xFF90CAF9,
                                          ).withValues(alpha: 0.98),
                                          fontWeight: FontWeight.w800,
                                          fontSize: workoutTitleFontSize,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (showTimerRow) ...[
                                        const SizedBox(
                                          height: kGapWorkoutToTimer,
                                        ),
                                        timerLeading(compact: true),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: btnW,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (w.status == 'completed')
                                        const _FuturisticSheetCompleteWorkoutCta(
                                          compact: true,
                                          isCompleted: true,
                                        )
                                      else if (w.status == 'started' &&
                                          w.timerResumeAt != null)
                                        _FuturisticSheetCompleteWorkoutCta(
                                          compact: true,
                                          onPressed: () =>
                                              _onRunningPrimaryCta(context, w),
                                        )
                                      else if (w.status == 'started' &&
                                          w.timerResumeAt == null)
                                        _FuturisticSheetPausedWorkoutCta(
                                          compact: true,
                                          onPressed: () =>
                                              _onPausedPrimaryCta(context, w),
                                        )
                                      else if (w.status == 'programmed')
                                        _FuturisticSheetStartWorkoutCta(
                                          compact: true,
                                          onPressed: isPastProgrammedWorkout
                                              ? null
                                              : () =>
                                                    _onStartWorkout(context, w),
                                        )
                                      else
                                        const SizedBox(height: 42),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Score',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _CalendarSheetHeaderWorkoutScore(
                                          workout: w,
                                          repo: widget.repo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                // [_refreshKey] só para “Tentar novamente” / ícone Atualizar — não após cada série
                // (remontar aqui reiniciava [CountUpScoreText] em todos os exercícios).
                child: KeyedSubtree(
                  key: ValueKey(_refreshKey),
                  child: StreamBuilder<List<ExerciseEntity>>(
                    stream: widget.repo.watchExercisesForDayWorkout(
                      widget.workout.id,
                    ),
                    builder: (context, exSnap) {
                      final byId = {for (final e in exSnap.data ?? []) e.id: e};
                      for (final e in byId.values) {
                        final n = e.name.trim();
                        if (n.isNotEmpty) {
                          _exerciseNameCacheById[e.id] = n;
                        }
                      }
                      return StreamBuilder<List<DayWorkoutExerciseEntity>>(
                        stream: widget.repo.watchDayWorkoutExercises(
                          widget.workout.id,
                        ),
                        builder: (context, lineSnap) {
                          if (lineSnap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  'Não foi possível carregar os exercícios deste treino.\n'
                                  '${lineSnap.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            );
                          }
                          final plannedLinesRaw =
                              lineSnap.data ?? (_bootstrapLines ?? const []);
                          if (plannedLinesRaw.isNotEmpty) {
                            _hasLoadedAnyExerciseLine = true;
                            _bootstrapLines = plannedLinesRaw;
                          }
                          final sheetAge = DateTime.now().difference(
                            _sheetOpenedAt,
                          );
                          final stallHydration =
                              sheetAge > const Duration(seconds: 10);
                          final uiCloudHydrationDone =
                              _cloudHydrationDone || stallHydration;
                          final shouldKeepLoadingWhileHydrating =
                              plannedLinesRaw.isEmpty &&
                              !_hasLoadedAnyExerciseLine &&
                              !stallHydration &&
                              (_repairingInitialExercises ||
                                  _cloudHydrationInFlight ||
                                  !uiCloudHydrationDone);
                          final loadingWorkoutLines =
                              (lineSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !lineSnap.hasData) ||
                              shouldKeepLoadingWhileHydrating;
                          final holdCompletedSnapshotUntilCloudHydrated =
                              plannedLinesRaw.isEmpty &&
                              w.status == 'completed' &&
                              !_cloudHydrationDone &&
                              DateTime.now().difference(_sheetOpenedAt) <
                                  const Duration(seconds: 8);
                          if (holdCompletedSnapshotUntilCloudHydrated &&
                              !_cloudRefreshRequestInFlight) {
                            unawaited(
                              _hydrateWorkoutLinesFromCloud(silentUi: true),
                            );
                          }
                          final stalledNoLineData =
                              stallHydration &&
                              plannedLinesRaw.isEmpty &&
                              (lineSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !lineSnap.hasData);
                          final missingExerciseIds = <String>{
                            for (final l in plannedLinesRaw)
                              if (!byId.containsKey(l.exerciseId)) l.exerciseId,
                          };
                          final now = DateTime.now();
                          _missingExerciseNameFirstSeenAt.removeWhere(
                            (id, _) => !missingExerciseIds.contains(id),
                          );
                          for (final id in missingExerciseIds) {
                            _missingExerciseNameFirstSeenAt.putIfAbsent(
                              id,
                              () => now,
                            );
                          }
                          if (missingExerciseIds.isNotEmpty) {
                            unawaited(
                              _hydrateMissingExercisesCatalog(
                                missingExerciseIds,
                              ),
                            );
                          } else {
                            _lastMissingExerciseIds = const <String>{};
                          }
                          final shouldShowInitialLoadingState =
                              holdCompletedSnapshotUntilCloudHydrated ||
                              (loadingWorkoutLines && plannedLinesRaw.isEmpty);
                          if (shouldShowInitialLoadingState) {
                            if (stalledNoLineData) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const ModernLoadingIndicator(size: 54),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Não foi possível carregar os exercícios agora.\n'
                                        'Toque para tentar novamente.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 13.5,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: () {
                                          if (!mounted) return;
                                          setState(() => _refreshKey++);
                                          unawaited(
                                            _hydrateWorkoutLinesFromCloud(),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Tentar novamente'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const Center(
                              child: FuturisticLoadingView(size: 58),
                            );
                          }
                          final plannedOrder =
                              List<DayWorkoutExerciseEntity>.from(
                                plannedLinesRaw,
                              )..sort(
                                (a, b) => a.sortOrder.compareTo(b.sortOrder),
                              );
                          final lines = orderDayWorkoutLinesByPerformedHistory(
                            plannedLinesRaw,
                          );
                          _scheduleFocusCurrentExerciseAfterRestClose(lines);
                          final blocks = dayWorkoutLinesAsComboBlocks(lines);
                          if (lines.isEmpty) {
                            if (w.status == 'started' &&
                                !_activeWorkoutRescueTriggered) {
                              _activeWorkoutRescueTriggered = true;
                              unawaited(_rescueActiveWorkoutLines());
                            }
                            final shouldKeepLoadingActiveWorkout =
                                w.status == 'started' &&
                                (DateTime.now().difference(_sheetOpenedAt) <
                                        const Duration(seconds: 16) ||
                                    _activeWorkoutRescueInFlight);
                            if (shouldKeepLoadingActiveWorkout) {
                              if (!_cloudRefreshRequestInFlight) {
                                unawaited(
                                  _hydrateWorkoutLinesFromCloud(silentUi: true),
                                );
                              }
                              return const Center(
                                child: FuturisticLoadingView(size: 58),
                              );
                            }
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
                              itemCount: blocks.length,
                              itemBuilder: (_, bi) {
                                final block = blocks[bi];
                                Widget lineCard(DayWorkoutExerciseEntity line) {
                                  final ex = byId[line.exerciseId];
                                  final name =
                                      ex?.name ??
                                      _exerciseNameCacheById[line.exerciseId] ??
                                      'Exercício a sincronizar';
                                  final outOfOrder =
                                      dayWorkoutLineExecutedOutOfPlannedOrder(
                                        plannedOrder,
                                        line,
                                      );
                                  final useAlt =
                                      _useAlternativeByLineId[line.id] ?? false;
                                  final performed =
                                      DayWorkoutPerformedSetCodec.decode(
                                        line.performedSetsJson,
                                      );
                                  final canAddSerie =
                                      w.status == 'started' &&
                                      w.timerResumeAt != null &&
                                      line.sets > 0 &&
                                      performed.length < line.sets;
                                  final allPlannedSeriesLogged =
                                      line.sets > 0 &&
                                      performed.length >= line.sets;
                                  final dialogTitle =
                                      calendarExerciseDisplayName(
                                        name,
                                        ex,
                                        useAlt,
                                      );
                                  return CalendarExerciseLineCard(
                                    line: line,
                                    exerciseName: name,
                                    exercise: ex,
                                    expandable: true,
                                    forceExpanded:
                                        _forceExpandedLineId == line.id,
                                    collapseSignal: _collapseAllSignal,
                                    workoutStatus: w.status,
                                    workoutPaused:
                                        w.status == 'started' &&
                                        w.timerResumeAt == null,
                                    useAlternative: useAlt,
                                    executedOutOfPlannedOrder: outOfOrder,
                                    onToggleAlternative:
                                        calendarExerciseHasAlternative(ex) &&
                                            w.status != 'completed' &&
                                            !allPlannedSeriesLogged
                                        ? () => setState(() {
                                            _useAlternativeByLineId[line.id] =
                                                !(_useAlternativeByLineId[line
                                                        .id] ??
                                                    false);
                                          })
                                        : null,
                                    onAdicionar: canAddSerie
                                        ? () => showCalendarAddSetDialog(
                                            context: context,
                                            restFlowContext: context,
                                            repo: widget.repo,
                                            line: line,
                                            exerciseName: dialogTitle,
                                            requireAllMetricFields:
                                                w.status == 'started',
                                          )
                                        : null,
                                    performedSetsRepo: widget.repo,
                                  );
                                }

                                if (block.length == 1) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: lineCard(block.single),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Combinação (sem intervalo entre estes)',
                                          style: TextStyle(
                                            color: AppColors.splashMint
                                                .withValues(alpha: 0.88),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      for (
                                        var j = 0;
                                        j < block.length;
                                        j++
                                      ) ...[
                                        if (j > 0) const SizedBox(height: 8),
                                        lineCard(block[j]),
                                      ],
                                    ],
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

  final VoidCallback? onPressed;
  final bool compact;

  static const _cyan = Color(0xFF26C6DA);

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final gradient = disabled
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.08),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.splashMint, _cyan],
          );
    final labelColor = disabled
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.88);

    if (compact) {
      return Tooltip(
        message: disabled
            ? 'Treinos em datas passadas não podem ser iniciados'
            : 'Iniciar Treino',
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
                    color: disabled
                        ? Colors.transparent
                        : AppColors.splashMint.withValues(alpha: 0.32),
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
                    color: labelColor,
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
                color: disabled
                    ? Colors.transparent
                    : AppColors.splashMint.withValues(alpha: 0.38),
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
                color: labelColor,
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
    this.onPressed,
    this.compact = false,
    this.isCompleted = false,
  });

  final VoidCallback? onPressed;
  final bool compact;
  final bool isCompleted;

  static const _violet = Color(0xFF7E57C2);
  static const _magenta = Color(0xFFEC407A);

  @override
  Widget build(BuildContext context) {
    final gradient = isCompleted
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_magenta, _violet],
          );
    final tooltip = isCompleted ? 'Treino concluído' : 'Concluir Treino';
    final compactLabel = isCompleted ? 'Treino\nconcluído' : 'Concluir\nTreino';
    final regularLabel = isCompleted ? 'Treino concluído' : 'Concluir Treino';
    final textColor = Colors.white.withValues(alpha: 0.95);
    final shadowColor = isCompleted
        ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
        : _magenta.withValues(alpha: 0.35);

    if (compact) {
      return Tooltip(
        message: tooltip,
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
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  compactLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: textColor,
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
                color: shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              regularLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
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

class _FuturisticStartOrSwapDialog extends StatelessWidget {
  const _FuturisticStartOrSwapDialog({required this.canSwap});

  final bool canSwap;

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
                  Color(0xFF0B1324),
                  Color(0xFF171236),
                  Color(0xFF0A1A2D),
                ],
              ),
              border: Border.all(
                color: AppColors.splashMint.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.splashMint.withValues(alpha: 0.12),
                  blurRadius: 30,
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
                        AppColors.splashMint,
                        const Color(0xFF26C6DA),
                        AppColors.accentPink.withValues(alpha: 0.9),
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
                                  AppColors.splashMint.withValues(alpha: 0.22),
                                  const Color(
                                    0xFF26C6DA,
                                  ).withValues(alpha: 0.18),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.splashMint.withValues(
                                  alpha: 0.52,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.rocket_launch_rounded,
                                color: AppColors.splashMint,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Iniciar este treino?',
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
                        canSwap
                            ? 'Você pode iniciar o treino agora ou trocar o grupo de treino antes de começar.'
                            : 'Confirme para iniciar o treino agora.',
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
                          onTap: () =>
                              _schedulePopDialogResult(context, 'start'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.splashMint,
                                  Color(0xFF26C6DA),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.splashMint.withValues(
                                    alpha: 0.35,
                                  ),
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
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.black.withValues(alpha: 0.84),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Iniciar treino',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (canSwap) ...[
                        const SizedBox(height: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _schedulePopDialogResult(context, 'swap'),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: const Color(
                                  0xFF17133A,
                                ).withValues(alpha: 0.95),
                                border: Border.all(
                                  color: AppColors.accentPink.withValues(
                                    alpha: 0.55,
                                  ),
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
                                    Icons.swap_horiz_rounded,
                                    color: AppColors.accentPink.withValues(
                                      alpha: 0.95,
                                    ),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Trocar grupo de treino',
                                    style: TextStyle(
                                      color: AppColors.accentPink.withValues(
                                        alpha: 0.95,
                                      ),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _schedulePopDialogResult(context, 'cancel'),
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
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
                                  const Color(
                                    0xFF7E57C2,
                                  ).withValues(alpha: 0.18),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.accentPink.withValues(
                                  alpha: 0.5,
                                ),
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
                          onTap: () =>
                              _schedulePopDialogResult(context, 'pause'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(
                                0xFF1A1424,
                              ).withValues(alpha: 0.95),
                              border: Border.all(
                                color: AppColors.splashMint.withValues(
                                  alpha: 0.55,
                                ),
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
                                  color: AppColors.splashMint.withValues(
                                    alpha: 0.95,
                                  ),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Pausar treino',
                                  style: TextStyle(
                                    color: AppColors.splashMint.withValues(
                                      alpha: 0.95,
                                    ),
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
                          onTap: () =>
                              _schedulePopDialogResult(context, 'complete'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFFEC407A,
                                  ).withValues(alpha: 0.95),
                                  const Color(
                                    0xFF7E57C2,
                                  ).withValues(alpha: 0.92),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEC407A,
                                  ).withValues(alpha: 0.35),
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
                                  const Color(
                                    0xFFFFB74D,
                                  ).withValues(alpha: 0.22),
                                  const Color(
                                    0xFFE65100,
                                  ).withValues(alpha: 0.15),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(
                                  0xFFFFB74D,
                                ).withValues(alpha: 0.55),
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
                          onTap: () =>
                              _schedulePopDialogResult(context, 'resume'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.splashMint,
                                  Color(0xFF26C6DA),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.splashMint.withValues(
                                    alpha: 0.35,
                                  ),
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
                          onTap: () =>
                              _schedulePopDialogResult(context, 'complete'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFFEC407A,
                                  ).withValues(alpha: 0.95),
                                  const Color(
                                    0xFF7E57C2,
                                  ).withValues(alpha: 0.92),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEC407A,
                                  ).withValues(alpha: 0.35),
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
                              color: AppColors.accentPink.withValues(
                                alpha: 0.15,
                              ),
                              border: Border.all(
                                color: AppColors.accentPink.withValues(
                                  alpha: 0.5,
                                ),
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
                                onTap: () =>
                                    _schedulePopDialogResult(context, false),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
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
                                onTap: () =>
                                    _schedulePopDialogResult(context, true),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFFEC407A,
                                        ).withValues(alpha: 0.95),
                                        const Color(
                                          0xFF7E57C2,
                                        ).withValues(alpha: 0.9),
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
