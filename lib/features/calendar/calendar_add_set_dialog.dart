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
    barrierColor: Colors.black.withValues(alpha: 0.55),
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

  static const _fieldAccent = Color(0xFF7FFFD4);
  static const _dialogBg = Color(0xFF16161C);

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Material(
        color: _dialogBg,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 14, 12, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carga e repetições',
                            style: TextStyle(
                              color: Color(0xFF5DEDE0),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.exerciseName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Altere o registro desta série.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _saving
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OutlinedNumberSlot(
                  label: 'Carga',
                  accent: _fieldAccent,
                  backgroundColor: _dialogBg,
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
                const SizedBox(height: 16),
                _OutlinedNumberSlot(
                  label: 'Repetições',
                  accent: _fieldAccent,
                  backgroundColor: _dialogBg,
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
                const SizedBox(height: 20),
                _GlowGradientButton(
                  label: 'Salvar alterações',
                  onPressed: _saving ? null : _submit,
                  busy: _saving,
                ),
              ],
            ),
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
  var _saving = false;

  /// Borda + label dos dois campos (mesmo visual que “Repetições”).
  static const _fieldAccent = Color(0xFF7FFFD4);
  static const _dialogBg = Color(0xFF16161C);

  @override
  void initState() {
    super.initState();
    final performed = DayWorkoutPerformedSetCodec.decode(widget.line.performedSetsJson);
    final last = performed.isNotEmpty ? performed.last : null;
    final loadSeed = last?.loadKg ?? widget.line.loadKg;
    _cargaCtrl = TextEditingController(
      text: loadSeed != null
          ? (loadSeed == loadSeed.roundToDouble()
              ? '${loadSeed.toInt()}'
              : '$loadSeed'.replaceAll('.', ','))
          : '',
    );
    _repsCtrl = TextEditingController(text: '${widget.line.reps}');
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
    // Margem extra evita overflow de alguns px quando o teclado reduz o espaço (Flexible + min intrinsic).
    final maxDialogH =
        (screenH * 0.88 - bottomInset - 16).clamp(240.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Material(
        color: _dialogBg,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogH),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 14, 12, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adicionar Série',
                            style: TextStyle(
                              color: Color(0xFF5DEDE0),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.exerciseName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _saving
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OutlinedNumberSlot(
                  label: 'Carga',
                  accent: _fieldAccent,
                  backgroundColor: _dialogBg,
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
                const SizedBox(height: 16),
                _OutlinedNumberSlot(
                  label: 'Repetições',
                  accent: _fieldAccent,
                  backgroundColor: _dialogBg,
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
                const SizedBox(height: 20),
                _GlowGradientButton(
                  label: 'Adicionar Série',
                  onPressed: _saving ? null : _submit,
                  busy: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedNumberSlot extends StatelessWidget {
  const _OutlinedNumberSlot({
    required this.label,
    required this.accent,
    required this.backgroundColor,
    required this.controller,
    required this.keyboardType,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final Color accent;
  final Color backgroundColor;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent, width: 1.4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
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
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '0',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 28,
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: backgroundColor,
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowGradientButton extends StatelessWidget {
  const _GlowGradientButton({
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF40E0D0).withValues(alpha: 0.55),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5DEDE0),
                  Color(0xFF0D9B8C),
                ],
              ),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black87,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
