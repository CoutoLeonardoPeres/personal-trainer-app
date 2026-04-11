import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../theme/app_colors.dart';
import '../utils/reps_text_utils.dart';
import 'app_form_fields.dart';
import 'training_method_picker_sheet.dart';

/// Valores devolvidos ao salvar [showExercisePrescriptionEditDialog].
class ExercisePrescriptionEditResult {
  const ExercisePrescriptionEditResult({
    required this.sets,
    required this.repsText,
    required this.repsHintInt,
    required this.restBetweenSetsSec,
    required this.loadKg,
    required this.trainingMethodId,
  });

  final int sets;
  final String repsText;
  final int repsHintInt;
  final int restBetweenSetsSec;
  final double? loadKg;
  final String? trainingMethodId;
}

/// Modal unificado: séries, repetições em texto, descanso, carga e método de treino.
Future<ExercisePrescriptionEditResult?> showExercisePrescriptionEditDialog(
  BuildContext context, {
  required AppDataRepository repo,
  required String exerciseName,
  required String badgeLabel,
  required String descriptionLine,
  required IconData headerIcon,
  int initialSets = 3,
  required String initialRepsText,
  required int initialRestBetweenSetsSec,
  double? initialLoadKg,
  String? initialTrainingMethodId,
}) {
  return showDialog<ExercisePrescriptionEditResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _ExercisePrescriptionEditDialog(
      repo: repo,
      exerciseName: exerciseName,
      badgeLabel: badgeLabel,
      descriptionLine: descriptionLine,
      headerIcon: headerIcon,
      initialSets: initialSets,
      initialRepsText: initialRepsText,
      initialRestBetweenSetsSec: initialRestBetweenSetsSec,
      initialLoadKg: initialLoadKg,
      initialTrainingMethodId: initialTrainingMethodId,
    ),
  );
}

class _ExercisePrescriptionEditDialog extends StatefulWidget {
  const _ExercisePrescriptionEditDialog({
    required this.repo,
    required this.exerciseName,
    required this.badgeLabel,
    required this.descriptionLine,
    required this.headerIcon,
    required this.initialSets,
    required this.initialRepsText,
    required this.initialRestBetweenSetsSec,
    required this.initialLoadKg,
    required this.initialTrainingMethodId,
  });

  final AppDataRepository repo;
  final String exerciseName;
  final String badgeLabel;
  final String descriptionLine;
  final IconData headerIcon;
  final int initialSets;
  final String initialRepsText;
  final int initialRestBetweenSetsSec;
  final double? initialLoadKg;
  final String? initialTrainingMethodId;

  @override
  State<_ExercisePrescriptionEditDialog> createState() =>
      _ExercisePrescriptionEditDialogState();
}

class _ExercisePrescriptionEditDialogState
    extends State<_ExercisePrescriptionEditDialog> {
  late final TextEditingController _setsC;
  late final TextEditingController _repsC;
  late final TextEditingController _loadC;
  late final TextEditingController _restSecC;
  String? _methodId;

  @override
  void initState() {
    super.initState();
    _setsC = TextEditingController(
      text: widget.initialSets > 0 ? '${widget.initialSets}' : '',
    );
    _repsC = TextEditingController(text: widget.initialRepsText);
    _loadC = TextEditingController(
      text: widget.initialLoadKg != null
          ? widget.initialLoadKg!.toString()
          : '',
    );
    _restSecC = TextEditingController(
      text: '${widget.initialRestBetweenSetsSec}',
    );
    _methodId = widget.initialTrainingMethodId;
  }

  @override
  void dispose() {
    _setsC.dispose();
    _repsC.dispose();
    _loadC.dispose();
    _restSecC.dispose();
    super.dispose();
  }

  void _submit() {
    final s = int.tryParse(_setsC.text.trim());
    final repsStr = _repsC.text.trim();
    final hint = repsHintIntFromText(repsStr);
    final lRaw = _loadC.text.trim().replaceAll(',', '.');
    final l = lRaw.isEmpty ? null : double.tryParse(lRaw);
    final restSec = int.tryParse(_restSecC.text.trim());
    if (s == null || s <= 0 || repsStr.isEmpty || hint == null || hint <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe séries (> 0) e repetições válidas (ex.: 12 ou 12-15).',
          ),
        ),
      );
      return;
    }
    if (lRaw.isNotEmpty && l == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carga inválida. Use número (ex.: 20 ou 12,5).'),
        ),
      );
      return;
    }
    if (restSec == null || restSec < 0 || restSec > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descanso entre séries: segundos entre 0 e 600.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      ExercisePrescriptionEditResult(
        sets: s,
        repsText: repsStr,
        repsHintInt: hint,
        restBetweenSetsSec: restSec,
        loadKg: l,
        trainingMethodId: _methodId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final padTop = mq.padding.top;
    final maxDialogH = math.min(
      mq.size.height * 0.95,
      mq.size.height - kb - padTop - 16,
    );
    return Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxDialogH),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.barBackground,
                  AppColors.backgroundDeep,
                  Color(0xFF050508),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.cadastroCardBorder.withValues(alpha: 0.52),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.14),
                  blurRadius: 26,
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.cadastroCardBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.registrySectionBlueLight
                                        .withValues(alpha: 0.22),
                                    AppColors.cadastroCardBorder.withValues(
                                      alpha: 0.08,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cadastroCardBorder
                                        .withValues(alpha: 0.14),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  widget.headerIcon,
                                  color: AppColors.registrySectionBlueLight,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.badgeLabel,
                                    style: TextStyle(
                                      color: AppColors.accentGreen.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.exerciseName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.descriptionLine,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _setsC,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.splashMint,
                          decoration: cadastroFieldInputDecoration(
                            labelText: 'Séries',
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(height: kCadastroFieldGap),
                        TextField(
                          controller: _repsC,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.splashMint,
                          decoration: cadastroFieldInputDecoration(
                            labelText: 'Repetições',
                            requiredField: true,
                            hintText: 'Ex.: 12 ou 12-15',
                          ),
                        ),
                        const SizedBox(height: kCadastroFieldGap),
                        TextField(
                          controller: _restSecC,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.splashMint,
                          decoration: cadastroFieldInputDecoration(
                            labelText: 'Intervalo entre séries (segundos)',
                            hintText: 'Padrão 60',
                          ),
                        ),
                        const SizedBox(height: kCadastroFieldGap),
                        TextField(
                          controller: _loadC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.splashMint,
                          decoration: cadastroFieldInputDecoration(
                            labelText: 'Carga (kg)',
                            hintText: 'Opcional',
                          ),
                        ),
                        const SizedBox(height: kCadastroFieldGap),
                        StreamBuilder<List<TrainingMethodEntity>>(
                          stream: widget.repo.watchTrainingMethodsAlphabetical(),
                          builder: (context, snap) {
                            final methods = snap.data ?? [];
                            return TrainingMethodPickerField(
                              methods: methods,
                              selectedId: _methodId,
                              onPick: (id) => setState(() => _methodId = id),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SecondaryCta(
                        label: 'Cancelar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 12),
                      AppPrimaryButton(
                        label: 'Salvar',
                        icon: Icons.check_rounded,
                        onPressed: _submit,
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

class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
