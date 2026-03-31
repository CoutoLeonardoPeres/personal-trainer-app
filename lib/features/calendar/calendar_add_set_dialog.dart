import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const _pink = Color(0xFFFF6B8A);
  static const _mintField = Color(0xFF7FFFD4);
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Material(
        color: _dialogBg,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 12, 16 + bottomInset),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
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
                const SizedBox(height: 22),
                _OutlinedNumberSlot(
                  label: 'Carga',
                  accent: _pink,
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
                const SizedBox(height: 20),
                _OutlinedNumberSlot(
                  label: 'Repetições',
                  accent: _mintField,
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
                const SizedBox(height: 28),
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
