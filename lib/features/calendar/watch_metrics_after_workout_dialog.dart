import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/app_data_repository.dart';

double? _parseCaloriesKcal(String raw) {
  final s = raw.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || v < 0 || v > 20000) return null;
  return v;
}

int? _parseAvgHeartRate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final v = int.tryParse(s);
  if (v == null || v < 30 || v > 230) return null;
  return v;
}

/// Após concluir o treino: opcional registrar kcal e FC média (ex.: Apple Watch, Garmin).
Future<void> showWatchMetricsAfterWorkoutDialog({
  required BuildContext context,
  required AppDataRepository repo,
  required String dayWorkoutId,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: const Color(0xD9000000),
    builder: (ctx) =>
        _WatchMetricsAfterWorkoutDialog(repo: repo, dayWorkoutId: dayWorkoutId),
  );
}

class _WatchMetricsAfterWorkoutDialog extends StatefulWidget {
  const _WatchMetricsAfterWorkoutDialog({
    required this.repo,
    required this.dayWorkoutId,
  });

  final AppDataRepository repo;
  final String dayWorkoutId;

  @override
  State<_WatchMetricsAfterWorkoutDialog> createState() =>
      _WatchMetricsAfterWorkoutDialogState();
}

class _WatchMetricsAfterWorkoutDialogState
    extends State<_WatchMetricsAfterWorkoutDialog> {
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _bpmCtrl;

  @override
  void initState() {
    super.initState();
    _kcalCtrl = TextEditingController();
    _bpmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _kcalCtrl.dispose();
    _bpmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final kcal = _parseCaloriesKcal(_kcalCtrl.text);
    final bpm = _parseAvgHeartRate(_bpmCtrl.text);
    final kcalEmpty = _kcalCtrl.text.trim().isEmpty;
    final bpmEmpty = _bpmCtrl.text.trim().isEmpty;

    void snack(String msg) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(msg)));
    }

    if (kcalEmpty && bpmEmpty) {
      snack('Preencha calorias ou FC média, ou toque em Pular.');
      return;
    }
    if (!kcalEmpty && kcal == null) {
      snack('Calorias inválidas (use um número entre 0 e 20000).');
      return;
    }
    if (!bpmEmpty && bpm == null) {
      snack('FC média inválida (número inteiro, ex.: 30–230 bpm).');
      return;
    }

    try {
      await widget.repo.setDayWorkoutWatchMetrics(
        widget.dayWorkoutId,
        caloriesKcal: kcal,
        avgHeartRateBpm: bpm,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      snack('Não foi possível guardar: $e');
    }
  }

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
                color: AppColors.headerGradientMint.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerGradientMint.withValues(alpha: 0.08),
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
                        AppColors.headerGradientMint.withValues(alpha: 0.95),
                        AppColors.accentGreen.withValues(alpha: 0.85),
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
                              color: AppColors.headerGradientMint.withValues(
                                alpha: 0.12,
                              ),
                              border: Border.all(
                                color: AppColors.headerGradientMint.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.watch_rounded,
                                color: AppColors.accentGreen,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Relógio ou app de treino',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Se quiser, registe valores do seu smartwatch (ou app) para este treino. É opcional.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _kcalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Calorias (kcal)',
                          hintText: 'Ex.: 320',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bpmCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Frequência cardíaca média (bpm)',
                          hintText: 'Ex.: 128',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Pular',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Guardar',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
