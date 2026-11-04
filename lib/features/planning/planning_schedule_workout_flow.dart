import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui/futuristic_background.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../core/widgets/exercise_prescription_edit_dialog.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../data/local/app_database.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';

/// Dados para agendar após o usuário confirmar grupo, revisão e quantidade de semanas.
class PlanningScheduleWorkoutRequest {
  const PlanningScheduleWorkoutRequest({
    required this.workoutGroupId,
    required this.groupName,
    required this.weekCount,
    required this.rows,
  });

  final String workoutGroupId;
  final String groupName;
  final int weekCount;
  final List<WeekScheduleRow> rows;
}

/// Diálogo futurista: quantas semanas repetir o grupo a partir da semana atual do planejamento.
Future<int?> showPlanningWeekCountDialog(
  BuildContext context, {
  required String groupName,
}) {
  return showDialog<int>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: _WeekCountDialogContent(groupName: groupName),
    ),
  );
}

class _WeekCountDialogContent extends StatefulWidget {
  const _WeekCountDialogContent({required this.groupName});

  final String groupName;

  @override
  State<_WeekCountDialogContent> createState() =>
      _WeekCountDialogContentState();
}

class _WeekCountDialogContentState extends State<_WeekCountDialogContent>
    with SingleTickerProviderStateMixin {
  int _weeks = 4;

  static const int _min = 1;
  static const int _max = 52;

  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    _open.forward();
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _open, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12182A).withValues(alpha: 0.98),
                const Color(0xFF0A0E18).withValues(alpha: 0.99),
              ],
            ),
            border: Border.all(
              width: 1.5,
              color: AppColors.headerGradientMint.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.headerGradientPink.withValues(alpha: 0.22),
                blurRadius: 28,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.headerGradientMint.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    color: AppColors.headerGradientMint,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Duração no planejamento',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.groupName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.splashMint.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O grupo será incluído na semana visível no planejamento e nas semanas seguintes, '
                'para que o aluno possa programar treinos no calendário.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.35),
                  border: Border.all(
                    color: AppColors.accentPink.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlowIconButton(
                      icon: Icons.remove_rounded,
                      onPressed: _weeks > _min
                          ? () => setState(() => _weeks--)
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Text(
                          '$_weeks',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          _weeks == 1 ? 'semana' : 'semanas',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    _GlowIconButton(
                      icon: Icons.add_rounded,
                      onPressed: _weeks < _max
                          ? () => setState(() => _weeks++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.headerGradientPink.withValues(
                              alpha: 0.85,
                            ),
                            AppColors.headerGradientMint.withValues(
                              alpha: 0.75,
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.headerGradientMint.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, _weeks),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Confirmar',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
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
      ),
    );
  }
}

class _GlowIconButton extends StatelessWidget {
  const _GlowIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? AppColors.headerGradientMint.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.headerGradientMint.withValues(
                        alpha: 0.2,
                      ),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: enabled
                ? AppColors.textPrimary
                : Colors.white.withValues(alpha: 0.2),
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Modal com todos os grupos; só os que têm exercícios no modelo podem ser agendados.
Future<PlanningScheduleWorkoutRequest?> showPlanningScheduleWorkoutSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required String studentId,
  required DateTime weekMonday,
  required String weekLabel,
}) {
  final hostContext = context;
  return showAppModalSheet<PlanningScheduleWorkoutRequest?>(
    context: hostContext,
    title: 'Agendar treino — $weekLabel',
    builder: (sheetCtx, scroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Escolha um grupo que já tenha exercícios no cadastro. O modelo será '
              'disponibilizado no planejamento semanal deste aluno e poderá ser usado no calendário.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<({WorkoutGroupEntity group, int exerciseCount})>>(
              stream: repo.watchWorkoutGroupsSchedulable(),
              builder: (_, snap) {
                final rows = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting &&
                    rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: ModernLoadingIndicator(size: 52),
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum grupo de treinos.\nCadastre em Cadastro → Grupos de treinos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final e = rows[i];
                    final g = e.group;
                    final n = e.exerciseCount;
                    final canSchedule = n > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            if (!canSchedule) {
                              if (!hostContext.mounted) return;
                              ScaffoldMessenger.of(hostContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Este grupo não tem exercícios. Adicione-os em '
                                    'Cadastro → Grupos de treinos antes de agendar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final draft = await repo
                                .buildWorkoutGroupPlanningDraftRows(g.id);
                            if (!hostContext.mounted || !sheetCtx.mounted) {
                              return;
                            }
                            final editedRows =
                                await showPlanningWorkoutDraftEditorSheet(
                                  context: sheetCtx,
                                  repo: repo,
                                  groupName: g.name,
                                  workoutGroupId: g.id,
                                  initialRows: draft,
                                );
                            if (editedRows == null || !hostContext.mounted) {
                              return;
                            }
                            final weeks = await showPlanningWeekCountDialog(
                              hostContext,
                              groupName: g.name,
                            );
                            if (weeks == null || !hostContext.mounted) {
                              return;
                            }
                            final request = PlanningScheduleWorkoutRequest(
                              workoutGroupId: g.id,
                              groupName: g.name,
                              weekCount: weeks,
                              rows: editedRows,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!hostContext.mounted) return;
                              Navigator.of(hostContext).pop(request);
                            });
                          },
                          child: Opacity(
                            opacity: canSchedule ? 1 : 0.55,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentPink.withValues(
                                      alpha: 0.08,
                                    ),
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.cadastroCardBorder
                                      .withValues(
                                        alpha: canSchedule ? 0.5 : 0.28,
                                      ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.layers_rounded,
                                    color: canSchedule
                                        ? AppColors.splashMint
                                        : AppColors.textMuted,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (g.description.isNotEmpty)
                                          Text(
                                            g.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (g.description.isEmpty)
                                          const SizedBox(height: 2),
                                        Text(
                                          canSchedule
                                              ? '$n exercício${n == 1 ? '' : 's'} no modelo'
                                              : 'Sem exercícios no modelo — não pode ser agendado',
                                          style: TextStyle(
                                            color: canSchedule
                                                ? AppColors.headerGradientMint
                                                      .withValues(alpha: 0.85)
                                                : AppColors.danger.withValues(
                                                    alpha: 0.9,
                                                  ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    canSchedule
                                        ? Icons.chevron_right_rounded
                                        : Icons.block_rounded,
                                    color: Colors.white.withValues(
                                      alpha: canSchedule ? 0.35 : 0.28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// Modal para copiar o planejamento semanal de outro aluno para o aluno selecionado.
Future<void> showPlanningCopyWorkoutSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required String targetStudentId,
  required DateTime weekMonday,
  required String weekLabel,
}) {
  final hostContext = context;
  return showAppModalSheet<void>(
    context: hostContext,
    title: 'Copiar treino — $weekLabel',
    builder: (sheetCtx, scroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Escolha um aluno de origem. O planejamento da semana atual desse aluno '
              'será copiado para o aluno selecionado, com opção de repetição por semanas.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentEntity>>(
              stream: repo.watchStudentsAlphabetical(),
              builder: (_, snap) {
                final students = (snap.data ?? [])
                    .where((s) => s.id != targetStudentId)
                    .toList();
                if (snap.connectionState == ConnectionState.waiting &&
                    students.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: ModernLoadingIndicator(size: 52),
                    ),
                  );
                }
                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum outro aluno disponível para copiar treino.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final weeks = await showPlanningWeekCountDialog(
                              hostContext,
                              groupName: 'Treino de ${s.name}',
                            );
                            if (weeks == null || !hostContext.mounted) return;
                            try {
                              final r = await repo
                                  .copyStudentWeekScheduleForWeeks(
                                    sourceStudentId: s.id,
                                    targetStudentId: targetStudentId,
                                    startWeekMonday: weekMonday,
                                    weekCount: weeks,
                                  );
                              if (!hostContext.mounted) return;
                              Navigator.of(hostContext).pop();
                              ScaffoldMessenger.of(hostContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    r.sourceItems == 0
                                        ? 'O aluno de origem não possui treino no planejamento desta semana.'
                                        : r.itemsAdded == 0
                                        ? 'Nada novo: o planejamento já tinha esse(s) grupo(s) ou exercício(s) avulsos.'
                                        : 'Treino copiado em ${r.weeksWithAdds} semana(s) · ${r.itemsAdded} exercício(s) adicionados.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!hostContext.mounted) return;
                              ScaffoldMessenger.of(hostContext).showSnackBar(
                                SnackBar(
                                  content: Text('Não foi possível copiar: $e'),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPink.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.2),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.cadastroCardBorder.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.content_copy_rounded,
                                  color: AppColors.splashMint,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

Future<List<WeekScheduleRow>?> showPlanningWorkoutDraftEditorSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required String groupName,
  required String workoutGroupId,
  required List<WeekScheduleRow> initialRows,
}) {
  return showAppModalSheet<List<WeekScheduleRow>>(
    context: context,
    title: 'Revisar treino',
    subtitle: groupName,
    futuristicChrome: true,
    initialChildSize: 0.88,
    maxChildSize: 0.95,
    builder: (ctx, scroll) => _PlanningWorkoutDraftEditor(
      scrollController: scroll,
      repo: repo,
      groupName: groupName,
      workoutGroupId: workoutGroupId,
      initialRows: initialRows,
    ),
  );
}

class _PlanningWorkoutDraftEditor extends StatefulWidget {
  const _PlanningWorkoutDraftEditor({
    required this.scrollController,
    required this.repo,
    required this.groupName,
    required this.workoutGroupId,
    required this.initialRows,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final String groupName;
  final String workoutGroupId;
  final List<WeekScheduleRow> initialRows;

  @override
  State<_PlanningWorkoutDraftEditor> createState() =>
      _PlanningWorkoutDraftEditorState();
}

class _PlanningWorkoutDraftEditorState
    extends State<_PlanningWorkoutDraftEditor> {
  static const _uuid = Uuid();
  late List<WeekScheduleRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List<WeekScheduleRow>.from(widget.initialRows);
    _renumberSortOrders();
  }

  void _renumberSortOrders() {
    _rows.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      _rows[i] = WeekScheduleRow(
        item: row.item.copyWith(sortOrder: i),
        exerciseName: row.exerciseName,
      );
    }
  }

  Future<void> _editRowAt(int index) async {
    final row = _rows[index];
    final item = row.item;
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: row.exerciseName,
      badgeLabel: 'PLANEJAMENTO',
      descriptionLine:
          'Esses ajustes serão aplicados ao agendar este grupo no planejamento.',
      headerIcon: Icons.view_week_rounded,
      initialSets: item.sets > 0 ? item.sets : 3,
      initialRepsText: weekScheduleRepsDisplay(item).isEmpty
          ? '12-15'
          : weekScheduleRepsDisplay(item),
      initialRestBetweenSetsSec: item.restBetweenSetsSec > 0
          ? item.restBetweenSetsSec
          : 60,
      initialLoadKg: item.loadKg,
      initialTrainingMethodId: item.trainingMethodId,
    );
    if (!mounted || res == null) return;
    setState(() {
      _rows[index] = WeekScheduleRow(
        item: item.copyWith(
          sets: res.sets,
          reps: res.repsHintInt,
          repsText: Value(res.repsText),
          loadKg: Value(res.loadKg),
          needsDetail: false,
          restBetweenSetsSec: res.restBetweenSetsSec,
          trainingMethodId: Value(res.trainingMethodId),
          updatedAt: DateTime.now(),
        ),
        exerciseName: row.exerciseName,
      );
    });
  }

  Future<void> _addExercise() async {
    final picked = await showAppModalSheet<ExerciseEntity>(
      context: context,
      title: 'Adicionar exercício',
      subtitle: 'Entra neste agendamento do planejamento.',
      futuristicChrome: true,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (ctx, scroll) =>
          _PlanningExercisePicker(scrollController: scroll, repo: widget.repo),
    );
    if (!mounted || picked == null) return;

    final now = DateTime.now();
    final item = WeekScheduleItemEntity(
      id: _uuid.v4(),
      blockId: '',
      exerciseId: picked.id,
      sourceWorkoutGroupId: widget.workoutGroupId,
      sortOrder: _rows.length,
      sets: 3,
      reps: 10,
      repsText: '10',
      loadKg: null,
      needsDetail: false,
      restBetweenSetsSec: 60,
      trainingMethodId: null,
      updatedAt: now,
      comboId: null,
    );
    setState(() {
      _rows.add(WeekScheduleRow(item: item, exerciseName: picked.name));
      _renumberSortOrders();
    });
  }

  void _removeAt(int index) {
    if (_rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mantenha pelo menos um exercício para agendar.'),
        ),
      );
      return;
    }
    setState(() {
      _rows.removeAt(index);
      _renumberSortOrders();
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final moved = _rows.removeAt(oldIndex);
      _rows.insert(target, moved);
      _renumberSortOrders();
    });
  }

  void _continue() {
    for (final row in _rows) {
      if (!weekScheduleItemHasValidPrescription(row.item)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toque em "${row.exerciseName}" e preencha séries e repetições.',
            ),
          ),
        );
        return;
      }
    }
    Navigator.pop(context, List<WeekScheduleRow>.from(_rows));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'Revise os exercícios antes de escolher por quantas semanas o treino será incluído.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: FuturisticBackground(
            child: ReorderableListView.builder(
              scrollController: widget.scrollController,
              buildDefaultDragHandles: false,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              itemCount: _rows.length + 1,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex == 0 || newIndex == 0) return;
                _reorder(oldIndex - 1, newIndex - 1);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    key: const ValueKey('planning_draft_add'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DraftActionTile(
                      icon: Icons.add_rounded,
                      title: 'Adicionar exercício',
                      subtitle: 'Escolha na lista de exercícios cadastrados',
                      onTap: _addExercise,
                    ),
                  );
                }
                final rowIndex = index - 1;
                final row = _rows[rowIndex];
                final item = row.item;
                final reps = weekScheduleRepsDisplay(item);
                final subtitle =
                    'Séries: ${item.sets}  Reps: ${reps.isEmpty ? '—' : reps}  '
                    'Carga: ${item.loadKg?.toString() ?? '—'} kg';
                return Padding(
                  key: ValueKey('planning_draft_${item.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.calendarFutureProgrammed.withValues(
                              alpha: 0.2,
                            ),
                            AppColors.cadastroCardBorder.withValues(
                              alpha: 0.11,
                            ),
                            Colors.black.withValues(alpha: 0.26),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.cadastroCardBorder.withValues(
                            alpha: 0.82,
                          ),
                          width: 1.05,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editRowAt(rowIndex),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  6,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      row.exerciseName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.52,
                                        ),
                                        fontSize: 12,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remover',
                            onPressed: () => _removeAt(rowIndex),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger.withValues(alpha: 0.92),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 42,
                              height: 48,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: AppPrimaryButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            onPressed: _rows.isEmpty ? null : _continue,
          ),
        ),
      ],
    );
  }
}

class _DraftActionTile extends StatelessWidget {
  const _DraftActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.splashMint.withValues(alpha: 0.22),
                AppColors.cadastroCardBorder.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(
              color: AppColors.accentGreen.withValues(alpha: 0.55),
              width: 1.05,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.splashMint, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.accentGreen.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanningExercisePicker extends StatefulWidget {
  const _PlanningExercisePicker({
    required this.scrollController,
    required this.repo,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;

  @override
  State<_PlanningExercisePicker> createState() =>
      _PlanningExercisePickerState();
}

class _PlanningExercisePickerState extends State<_PlanningExercisePicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AppTextField(
            controller: _search,
            label: 'Buscar exercício',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ExerciseEntity>>(
            stream: widget.repo.watchExercisesAlphabetical(),
            builder: (context, snap) {
              final q = _search.text.trim().toLowerCase();
              final list = (snap.data ?? <ExerciseEntity>[])
                  .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
                  .toList();
              if (snap.connectionState == ConnectionState.waiting &&
                  list.isEmpty) {
                return const Center(child: ModernLoadingIndicator(size: 42));
              }
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhum exercício encontrado.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final e = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DraftActionTile(
                      icon: Icons.fitness_center_rounded,
                      title: e.name,
                      subtitle: 'Adicionar ao treino',
                      onTap: () => Navigator.pop(context, e),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
