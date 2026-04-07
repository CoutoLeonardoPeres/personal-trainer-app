import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/day_workout_performed_set.dart';
import '../../data/repositories/app_data_repository.dart';

/// Abre o diálogo "Adicionar Série" (carga + repetições) para uma linha do treino do dia.
Future<void> showCalendarAddSetDialog({
  required BuildContext context,
  required AppDataRepository repo,
  required DayWorkoutExerciseEntity line,
  required String exerciseName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _AddSetDialog(
      repo: repo,
      line: line,
      exerciseName: exerciseName,
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
}) {
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
  });

  final AppDataRepository repo;
  final String lineId;
  final int performedIndex;
  final DayWorkoutPerformedSet initial;
  final String exerciseName;

  @override
  State<_EditPerformedSetDialog> createState() => _EditPerformedSetDialogState();
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
      loadKg = null;
    } else {
      loadKg = double.tryParse(cargaRaw);
      if (loadKg == null || loadKg < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga inválida.')),
        );
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxDialogH =
        (screenH * 0.88 - bottomInset - 16).clamp(240.0, 560.0);
    final seriesLabel = 'Série ${widget.performedIndex + 1}';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
        child: _FuturisticSetMetricDialogChrome(
          title: 'Carga e repetições',
          exerciseName: widget.exerciseName,
          subtitle: 'Altere o registro desta série.',
          seriesBadge: seriesLabel,
          saving: _saving,
          onClose: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          bottomInset: bottomInset,
          scrollableChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FuturisticMetricField(
                label: 'Carga (kg)',
                hint: 'Opcional',
                icon: Icons.monitor_weight_outlined,
                controller: _cargaCtrl,
                focusNode: _cargaFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_repsFocus);
                },
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
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
                onPressed: _saving ? null : _submit,
                busy: _saving,
              ),
            ],
          ),
        ),
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
                                  color: AppColors.danger.withValues(alpha: 0.2),
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
  });

  final AppDataRepository repo;
  final DayWorkoutExerciseEntity line;
  final String exerciseName;

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
    if (currentPerformed.isNotEmpty) return;

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
    final loadSeed = last?.loadKg ?? widget.line.loadKg;
    final repsSeed = last?.reps ?? widget.line.reps;
    _cargaCtrl = TextEditingController(
      text: _formatLoadText(loadSeed),
    );
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
      loadKg = null;
    } else {
      loadKg = double.tryParse(cargaRaw);
      if (loadKg == null || loadKg < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga inválida.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await widget.repo.appendDayWorkoutExercisePerformedSet(
        lineId: widget.line.id,
        loadKg: loadKg,
        reps: reps,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Série registrada.')),
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxDialogH =
        (screenH * 0.88 - bottomInset - 16).clamp(240.0, 560.0);
    final performed = DayWorkoutPerformedSetCodec.decode(
      widget.line.performedSetsJson,
    );
    final nextSeries = performed.length + 1;
    final seriesLabel = 'Série $nextSeries';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
        child: _FuturisticSetMetricDialogChrome(
          title: 'Registrar série',
          exerciseName: widget.exerciseName,
          subtitle: 'Informe carga e repetições desta execução.',
          seriesBadge: seriesLabel,
          saving: _saving,
          onClose: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          bottomInset: bottomInset,
          scrollableChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FuturisticMetricField(
                label: 'Carga (kg)',
                hint: 'Opcional',
                icon: Icons.monitor_weight_outlined,
                controller: _cargaCtrl,
                focusNode: _cargaFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_repsFocus);
                },
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
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
                onPressed: _saving ? null : _submit,
                busy: _saving,
              ),
            ],
          ),
        ),
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
    required this.bottomInset,
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
  final double bottomInset;
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
                            color: AppColors.accentGreen.withValues(alpha: 0.92),
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
                padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + bottomInset),
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
              scrollPadding: const EdgeInsets.only(bottom: 120, top: 24),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF0A0A12),
                      ),
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
