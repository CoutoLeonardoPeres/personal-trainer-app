import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/widgets/inter_set_rest_modal.dart';
import '../../core/preferences/workout_runtime_prefs.dart';
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';
import 'exercise_completion_comparison_dialog.dart';

/// Abre o diálogo "Adicionar Série" (carga + repetições) para uma linha do treino do dia.
Future<void> showCalendarAddSetDialog({
  required BuildContext context,
  required AppDataRepository repo,
  required DayWorkoutExerciseEntity line,
  required String exerciseName,

  /// Contexto ainda montado após fechar o diálogo (ex.: folha do calendário) — modal de descanso.
  required BuildContext restFlowContext,

  /// Treino `started`: carga (kg) e repetições obrigatórias.
  bool requireAllMetricFields = false,
}) async {
  // Evita pull da nuvem a competir com o commit da série (loading infinito no modal).
  repo.muteDayWorkoutCloudPullFor(const Duration(seconds: 30));
  var initialSeed = repo.cachedLastPerformedSetSeedForLine(line.id);
  if (initialSeed == null) {
    try {
      initialSeed = await repo
          .lastPerformedSetSeedForLine(line.id)
          .timeout(const Duration(milliseconds: 180), onTimeout: () => null);
    } catch (_) {
      initialSeed = null;
    }
  }
  if (!context.mounted) return;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _AddSetDialog(
      repo: repo,
      line: line,
      exerciseName: exerciseName,
      restFlowContext: restFlowContext,
      requireAllMetricFields: requireAllMetricFields,
      initialSeed: initialSeed,
    ),
  );
}

/// Edita carga/reps de uma série já registrada (índice na lista JSON).
Future<void> showCalendarEditPerformedSetDialog({
  required BuildContext context,
  required AppDataRepository repo,
  required String lineId,
  required int performedIndex,
  required DayWorkoutPerformedSet initial,
  required String exerciseName,
  bool requireAllMetricFields = false,
}) {
  repo.muteDayWorkoutCloudPullFor(const Duration(seconds: 30));
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => _EditPerformedSetDialog(
      repo: repo,
      lineId: lineId,
      performedIndex: performedIndex,
      initial: initial,
      exerciseName: exerciseName,
      requireAllMetricFields: requireAllMetricFields,
    ),
  );
}

/// Confirma exclusão de uma série já registrada (modal futurista).
Future<bool?> showFuturisticDeletePerformedSeriesDialog(
  BuildContext context, {
  required String detailLine,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) => _FuturisticDeleteSeriesDialog(detailLine: detailLine),
  );
}

class _EditPerformedSetDialog extends StatefulWidget {
  const _EditPerformedSetDialog({
    required this.repo,
    required this.lineId,
    required this.performedIndex,
    required this.initial,
    required this.exerciseName,
    this.requireAllMetricFields = false,
  });

  final AppDataRepository repo;
  final String lineId;
  final int performedIndex;
  final DayWorkoutPerformedSet initial;
  final String exerciseName;
  final bool requireAllMetricFields;

  @override
  State<_EditPerformedSetDialog> createState() =>
      _EditPerformedSetDialogState();
}

class _EditPerformedSetDialogState extends State<_EditPerformedSetDialog> {
  late final TextEditingController _cargaCtrl;
  late final TextEditingController _repsCtrl;
  late final FocusNode _cargaFocus;
  late final FocusNode _repsFocus;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final load = widget.initial.loadKg;
    _cargaCtrl = TextEditingController(
      text: load != null
          ? (load == load.roundToDouble()
                ? '${load.toInt()}'
                : '$load'.replaceAll('.', ','))
          : '',
    );
    _repsCtrl = TextEditingController(text: '${widget.initial.reps}');
    _cargaFocus = FocusNode();
    _repsFocus = FocusNode();
  }

  @override
  void dispose() {
    _cargaCtrl.dispose();
    _repsCtrl.dispose();
    _cargaFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryTap() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Em alguns devices, o primeiro toque fecha teclado/foco e não dispara
    // persistência de imediato; aguarda 1 frame para garantir commit dos campos.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted || _saving) return;
    await _submit();
  }

  Future<void> _submit() async {
    final repsRaw = _repsCtrl.text.trim();
    final reps = int.tryParse(repsRaw);
    if (reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe repetições válidas (≥ 1).')),
      );
      return;
    }

    final cargaRaw = _cargaCtrl.text.trim().replaceAll(',', '.');
    double? loadKg;
    if (cargaRaw.isEmpty) {
      if (widget.requireAllMetricFields) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe a carga (kg) — obrigatório durante o treino.',
            ),
          ),
        );
        return;
      }
      loadKg = null;
    } else {
      loadKg = double.tryParse(cargaRaw);
      if (loadKg == null || loadKg < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Carga inválida.')));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await widget.repo.updateDayWorkoutExercisePerformedSetAt(
        lineId: widget.lineId,
        performedIndex: widget.performedIndex,
        loadKg: loadKg,
        reps: reps,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Série atualizada.')),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível salvar.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesLabel = 'Série ${widget.performedIndex + 1}';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // [Dialog] remove os viewInsets do MediaQuery filho; a altura útil vem
          // das constraints (já desconta teclado via AnimatedPadding interno).
          final maxDialogH = (constraints.maxHeight - 8).clamp(240.0, 560.0);
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
            child: _FuturisticSetMetricDialogChrome(
              title: 'Carga e repetições',
              exerciseName: widget.exerciseName,
              subtitle: widget.requireAllMetricFields
                  ? 'Com o treino em execução, carga (kg) e repetições são obrigatórias.'
                  : 'Altere o registro desta série.',
              seriesBadge: seriesLabel,
              saving: _saving,
              onClose: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
              scrollableChild: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FuturisticMetricField(
                    label: 'Carga (kg)',
                    hint: widget.requireAllMetricFields
                        ? 'Obrigatório'
                        : 'Opcional',
                    icon: Icons.monitor_weight_outlined,
                    controller: _cargaCtrl,
                    focusNode: _cargaFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_repsFocus);
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FuturisticMetricField(
                    label: 'Repetições',
                    hint: 'Por série',
                    icon: Icons.repeat_rounded,
                    controller: _repsCtrl,
                    focusNode: _repsFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handlePrimaryTap(),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 24),
                  _FuturisticPrimaryCta(
                    label: 'Salvar alterações',
                    icon: Icons.save_rounded,
                    onPressed: _saving ? null : _handlePrimaryTap,
                    busy: _saving,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FuturisticDeleteSeriesDialog extends StatelessWidget {
  const _FuturisticDeleteSeriesDialog({required this.detailLine});

  final String detailLine;

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
                  Color(0xFF1A1018),
                  Color(0xFF0A1220),
                ],
              ),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: -4,
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
                        AppColors.danger.withValues(alpha: 0.95),
                        AppColors.accentPink.withValues(alpha: 0.85),
                        AppColors.splashMint.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.danger.withValues(alpha: 0.25),
                                  AppColors.accentPink.withValues(alpha: 0.15),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.delete_forever_rounded,
                                color: AppColors.danger,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Excluir série?',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        detailLine,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Esta ação não pode ser desfeita.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _FuturisticDeleteCancelCta(
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(height: 12),
                      _FuturisticDeleteConfirmCta(
                        onPressed: () => Navigator.pop(context, true),
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

class _FuturisticDeleteCancelCta extends StatelessWidget {
  const _FuturisticDeleteCancelCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A1424).withValues(alpha: 0.95),
            border: Border.all(
              color: AppColors.splashMint.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.splashMint.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.close_rounded,
                color: AppColors.splashMint.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Cancelar',
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
    );
  }
}

class _FuturisticDeleteConfirmCta extends StatelessWidget {
  const _FuturisticDeleteConfirmCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.danger,
                AppColors.danger.withValues(alpha: 0.78),
                AppColors.accentPink.withValues(alpha: 0.88),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Excluir',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.98),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddSetDialog extends StatefulWidget {
  const _AddSetDialog({
    required this.repo,
    required this.line,
    required this.exerciseName,
    required this.restFlowContext,
    this.requireAllMetricFields = false,
    this.initialSeed,
  });

  final AppDataRepository repo;
  final DayWorkoutExerciseEntity line;
  final String exerciseName;
  final BuildContext restFlowContext;
  final bool requireAllMetricFields;
  final DayWorkoutPerformedSet? initialSeed;

  @override
  State<_AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<_AddSetDialog> {
  late final TextEditingController _cargaCtrl;
  late final TextEditingController _repsCtrl;
  late final FocusNode _cargaFocus;
  late final FocusNode _repsFocus;
  late final String _initialLoadText;
  late final String _initialRepsText;
  var _saving = false;

  String _formatLoadText(double? load) {
    if (load == null) return '';
    if (load == load.roundToDouble()) return '${load.toInt()}';
    return '$load'.replaceAll('.', ',');
  }

  Future<void> _seedFromPreviousStudentRecord() async {
    final currentPerformed = DayWorkoutPerformedSetCodec.decode(
      widget.line.performedSetsJson,
    );
    if (currentPerformed.isNotEmpty || widget.initialSeed != null) return;

    final previous = await widget.repo.lastPerformedSetSeedForLine(
      widget.line.id,
    );
    if (!mounted || previous == null) return;

    final canApplyLoad = _cargaCtrl.text.trim() == _initialLoadText.trim();
    final canApplyReps = _repsCtrl.text.trim() == _initialRepsText.trim();
    if (canApplyLoad) {
      _cargaCtrl.text = _formatLoadText(previous.loadKg);
    }
    if (canApplyReps) {
      _repsCtrl.text = '${previous.reps}';
    }
  }

  @override
  void initState() {
    super.initState();
    final performed = DayWorkoutPerformedSetCodec.decode(
      widget.line.performedSetsJson,
    );
    final last = performed.isNotEmpty ? performed.last : null;
    final seed = widget.initialSeed;
    final loadSeed = last?.loadKg ?? seed?.loadKg ?? widget.line.loadKg;
    final repsSeed = last?.reps ?? seed?.reps ?? widget.line.reps;
    _cargaCtrl = TextEditingController(text: _formatLoadText(loadSeed));
    _repsCtrl = TextEditingController(text: '$repsSeed');
    _initialLoadText = _cargaCtrl.text;
    _initialRepsText = _repsCtrl.text;
    _cargaFocus = FocusNode();
    _repsFocus = FocusNode();
    _seedFromPreviousStudentRecord();
  }

  @override
  void dispose() {
    _cargaCtrl.dispose();
    _repsCtrl.dispose();
    _cargaFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryTap() async {
    if (_saving) return;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    // Evita “primeiro toque não registra” em aparelhos onde o foco/teclado
    // consome o primeiro evento de toque.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    try {
      await _submit();
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final repsRaw = _repsCtrl.text.trim();
    final reps = int.tryParse(repsRaw);
    if (reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe repetições válidas (≥ 1).')),
      );
      return;
    }

    final cargaRaw = _cargaCtrl.text.trim().replaceAll(',', '.');
    double? loadKg;
    if (cargaRaw.isEmpty) {
      if (widget.requireAllMetricFields) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe a carga (kg) — obrigatório durante o treino.',
            ),
          ),
        );
        return;
      }
      loadKg = null;
    } else {
      loadKg = double.tryParse(cargaRaw);
      if (loadKg == null || loadKg < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Carga inválida.')));
        return;
      }
    }

    final performedBefore = DayWorkoutPerformedSetCodec.decode(
      widget.line.performedSetsJson,
    ).length;
    final willCompleteExercise =
        widget.line.sets > 0 && performedBefore + 1 >= widget.line.sets;

    final dayWorkoutId = widget.line.dayWorkoutId;
    final lineId = widget.line.id;
    final planned = widget.line.sets;
    final restSec = widget.line.restBetweenSetsSec;
    var saved = false;
    Object? saveError;
    final expectedSets = performedBefore + 1;
    try {
      debugPrint(
        '[add_set] submit start line=$lineId reps=$reps load=${loadKg?.toString() ?? 'null'}',
      );
      await widget.repo.appendDayWorkoutExercisePerformedSet(
        lineId: lineId,
        loadKg: loadKg,
        reps: reps,
      );
      saved = true;
      debugPrint('[add_set] submit local_saved line=$lineId');
    } on ArgumentError catch (e) {
      saveError = e;
      debugPrint('[add_set] submit argument_error line=$lineId error=$e');
    } catch (e) {
      saveError = e;
      debugPrint('[add_set] submit error line=$lineId error=$e');
    }

    if (!saved) {
      saved = await _waitForLocalSetCommit(
        lineId: lineId,
        expectedMinSets: expectedSets,
        timeout: const Duration(milliseconds: 1200),
      );
      if (saved) {
        debugPrint('[add_set] submit local_saved_after_check line=$lineId');
      }
    }

    if (saved) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Série registrada.')),
        );
      }
    } else if (mounted) {
      if (saveError case final ArgumentError ae) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ae.message ?? 'Não foi possível salvar.')),
        );
      } else if (saveError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlySaveError(saveError))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A série não foi gravada localmente. Tente confirmar novamente.',
            ),
          ),
        );
      }
    }

    final restCtx = widget.restFlowContext;
    if (!saved || !restCtx.mounted) return;
    unawaited(
      _runPostSaveFlow(
        repo: widget.repo,
        restFlowContext: restCtx,
        dayWorkoutId: dayWorkoutId,
        lineId: lineId,
        plannedSets: planned,
        restSec: restSec,
        willCompleteExercise: willCompleteExercise,
      ),
    );
  }

  Future<void> _runPostSaveFlow({
    required AppDataRepository repo,
    required BuildContext restFlowContext,
    required String dayWorkoutId,
    required String lineId,
    required int plannedSets,
    required int restSec,
    required bool willCompleteExercise,
  }) async {
    try {
      if (willCompleteExercise) {
        await Future<void>.delayed(Duration.zero);
        final summary = await repo.getExerciseSessionComparison(lineId);
        if (summary != null && restFlowContext.mounted) {
          await showExerciseCompletionComparisonDialog(
            context: restFlowContext,
            data: summary,
          );
        }
        return;
      }

      await _runPostSaveRestFlow(
        repo: repo,
        restFlowContext: restFlowContext,
        dayWorkoutId: dayWorkoutId,
        lineId: lineId,
        plannedSets: plannedSets,
        restSec: restSec,
      );
    } catch (_) {
      // A série já foi gravada; descanso/relatório são pós-fluxo best effort.
    }
  }

  Future<bool> _waitForLocalSetCommit({
    required String lineId,
    required int expectedMinSets,
    Duration timeout = const Duration(milliseconds: 3200),
  }) async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      try {
        final row = await widget.repo
            .getDayWorkoutExerciseById(lineId)
            .timeout(const Duration(milliseconds: 500));
        if (row != null) {
          final sets = DayWorkoutPerformedSetCodec.decode(
            row.performedSetsJson,
          ).length;
          if (sets >= expectedMinSets) return true;
        }
      } catch (_) {
        // best effort, tenta novamente dentro da janela.
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return false;
  }

  String _friendlySaveError(Object e) {
    if (e is TimeoutException) {
      return 'O registo demorou demasiado (base de dados ocupada). '
          'Feche esta janela e tente outra vez.';
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('database is locked') ||
        msg.contains('database table is locked') ||
        msg.contains('sqlite_busy') ||
        msg.contains('busy')) {
      return 'Banco ocupado no momento. Tente confirmar a série novamente.';
    }
    return 'Não foi possível salvar.';
  }

  Future<void> _runPostSaveRestFlow({
    required AppDataRepository repo,
    required BuildContext restFlowContext,
    required String dayWorkoutId,
    required String lineId,
    required int plannedSets,
    required int restSec,
  }) async {
    try {
      final restIntervalEnabled =
          await WorkoutRuntimePrefs.isRestIntervalEnabled();
      if (!restIntervalEnabled) return;
      final lines = await repo.getDayWorkoutExercises(dayWorkoutId);
      DayWorkoutExerciseEntity? current;
      for (final l in lines) {
        if (l.id == lineId) {
          current = l;
          break;
        }
      }
      if (current == null) return;
      final doneCount = DayWorkoutPerformedSetCodec.decode(
        current.performedSetsJson,
      ).length;
      if (doneCount >= plannedSets) return;
      final lastInCombo = await repo.isLastLineInExerciseCombo(lineId);
      if (doneCount < plannedSets &&
          restSec > 0 &&
          lastInCombo &&
          restFlowContext.mounted) {
        final metrics = await showInterSetRestModal(
          context: restFlowContext,
          prescribedSec: restSec,
        );
        if (metrics != null && restFlowContext.mounted) {
          await repo.patchLastPerformedSetRestTelemetry(
            lineId: lineId,
            prescribedSec: metrics.prescribedSec,
            countdownElapsedMs: metrics.countdownElapsedMs,
            postPhaseMs: metrics.postPhaseMs,
          );
        }
      }
    } catch (_) {
      // O registro da série já foi salvo; não falhar UX por erro de telemetria/descanso.
    }
  }

  @override
  Widget build(BuildContext context) {
    final performed = DayWorkoutPerformedSetCodec.decode(
      widget.line.performedSetsJson,
    );
    final nextSeries = performed.length + 1;
    final seriesLabel = 'Série $nextSeries';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDialogH = (constraints.maxHeight - 8).clamp(240.0, 560.0);
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
            child: _FuturisticSetMetricDialogChrome(
              title: 'Registrar série',
              exerciseName: widget.exerciseName,
              subtitle: widget.requireAllMetricFields
                  ? 'Com o treino em execução, carga (kg) e repetições são obrigatórias.'
                  : 'Informe carga e repetições desta execução.',
              seriesBadge: seriesLabel,
              saving: _saving,
              onClose: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
              scrollableChild: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FuturisticMetricField(
                    label: 'Carga (kg)',
                    hint: widget.requireAllMetricFields
                        ? 'Obrigatório'
                        : 'Opcional',
                    icon: Icons.monitor_weight_outlined,
                    controller: _cargaCtrl,
                    focusNode: _cargaFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_repsFocus);
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FuturisticMetricField(
                    label: 'Repetições',
                    hint: 'Por série',
                    icon: Icons.repeat_rounded,
                    controller: _repsCtrl,
                    focusNode: _repsFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handlePrimaryTap(),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 24),
                  _FuturisticPrimaryCta(
                    label: 'Confirmar série',
                    icon: Icons.add_task_rounded,
                    onPressed: _saving ? null : _handlePrimaryTap,
                    busy: _saving,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shell visual compartilhado (gradiente, borda neon, faixa superior).
class _FuturisticSetMetricDialogChrome extends StatelessWidget {
  const _FuturisticSetMetricDialogChrome({
    required this.title,
    required this.exerciseName,
    required this.saving,
    required this.onClose,
    required this.scrollableChild,
    this.subtitle,
    this.seriesBadge,
  });

  final String title;
  final String exerciseName;
  final String? subtitle;
  final String? seriesBadge;
  final bool saving;
  final VoidCallback onClose;
  final Widget scrollableChild;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.barBackground,
              AppColors.backgroundDeep,
              const Color(0xFF050508),
            ],
          ),
          border: Border.all(
            color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGreen.withValues(alpha: 0.14),
              blurRadius: 28,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.headerGradientPink.withValues(alpha: 0.95),
                    AppColors.cadastroCardBorder.withValues(alpha: 0.9),
                    AppColors.headerGradientMint.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentGreen.withValues(alpha: 0.45),
                      ),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentGreen.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.15),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.accentGreen,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.accentGreen.withValues(
                              alpha: 0.92,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exerciseName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    onPressed: saving ? null : onClose,
                  ),
                ],
              ),
            ),
            if (seriesBadge != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cadastroCardBorder.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      color: AppColors.accentGreen.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 17,
                          color: AppColors.cadastroCardBorder,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          seriesBadge!,
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                child: scrollableChild,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuturisticMetricField extends StatelessWidget {
  const _FuturisticMetricField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.keyboardType,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.cadastroCardBorder.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.accentGreen.withValues(alpha: 0.8),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cadastroCardBorder.withValues(alpha: 0.75),
                AppColors.accentGreen.withValues(alpha: 0.45),
                AppColors.headerGradientMint.withValues(alpha: 0.35),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGreen.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.35),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.8),
              color: const Color(0xFF0C0C12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              inputFormatters: inputFormatters,
              textAlign: TextAlign.center,
              scrollPadding: const EdgeInsets.only(bottom: 220, top: 24),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                hintText: '0',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.14),
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FuturisticPrimaryCta extends StatelessWidget {
  const _FuturisticPrimaryCta({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.busy,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.headerGradientMint.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? [
                        AppColors.headerGradientMint,
                        AppColors.accentGreen.withValues(alpha: 0.88),
                        AppColors.headerGradientPink.withValues(alpha: 0.75),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.08),
                      ],
              ),
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: ModernLoadingIndicator(size: 28),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: enabled
                              ? const Color(0xFF0A0A12)
                              : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            color: enabled
                                ? const Color(0xFF0A0A12)
                                : Colors.white38,
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
      ),
    );
  }
}
