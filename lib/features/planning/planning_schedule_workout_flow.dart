import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';

/// Diálogo futurista: quantas semanas repetir o grupo a partir da semana atual do planejamento.
Future<int?> showPlanningWeekCountDialog(
  BuildContext context, {
  required String groupName,
}) {
  return showDialog<int>(
    context: context,
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
  State<_WeekCountDialogContent> createState() => _WeekCountDialogContentState();
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                            AppColors.headerGradientPink.withValues(alpha: 0.85),
                            AppColors.headerGradientMint.withValues(alpha: 0.75),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.headerGradientMint.withValues(alpha: 0.35),
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
  const _GlowIconButton({
    required this.icon,
    required this.onPressed,
  });

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
                      color: AppColors.headerGradientMint.withValues(alpha: 0.2),
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
Future<void> showPlanningScheduleWorkoutSheet({
  required BuildContext context,
  required AppDataRepository repo,
  required String studentId,
  required DateTime weekMonday,
  required String weekLabel,
}) {
  return showAppModalSheet<void>(
    context: context,
    title: 'Agendar treino — $weekLabel',
    builder: (ctx, scroll) {
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
              builder: (context, snap) {
                final rows = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting && rows.isEmpty) {
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
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Este grupo não tem exercícios. Adicione-os em '
                                    'Cadastro → Grupos de treinos antes de agendar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final weeks = await showPlanningWeekCountDialog(
                              ctx,
                              groupName: g.name,
                            );
                            if (weeks == null || !ctx.mounted) return;
                            try {
                              final r = await repo.scheduleWorkoutGroupForWeeks(
                                studentId: studentId,
                                startWeekMonday: weekMonday,
                                workoutGroupId: g.id,
                                weekCount: weeks,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              final msg = r.itemsAdded == 0
                                  ? 'Este grupo de treino já está no planejamento dessa(s) semana(s).'
                                  : 'Grupo agendado em ${r.weeksWithAdds} semana(s) · ${r.itemsAdded} exercício(s) no planejamento.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            } catch (err) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Não foi possível agendar: $err'),
                                ),
                              );
                            }
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
                                    AppColors.accentPink.withValues(alpha: 0.08),
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.cadastroCardBorder.withValues(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (g.description.isEmpty) const SizedBox(height: 2),
                                        Text(
                                          canSchedule
                                              ? '$n exercício${n == 1 ? '' : 's'} no modelo'
                                              : 'Sem exercícios no modelo — não pode ser agendado',
                                          style: TextStyle(
                                            color: canSchedule
                                                ? AppColors.headerGradientMint
                                                    .withValues(alpha: 0.85)
                                                : AppColors.danger.withValues(alpha: 0.9),
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
  return showAppModalSheet<void>(
    context: context,
    title: 'Copiar treino — $weekLabel',
    builder: (ctx, scroll) {
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
              builder: (context, snap) {
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
                              ctx,
                              groupName: 'Treino de ${s.name}',
                            );
                            if (weeks == null || !ctx.mounted) return;
                            try {
                              final r = await repo.copyStudentWeekScheduleForWeeks(
                                sourceStudentId: s.id,
                                targetStudentId: targetStudentId,
                                startWeekMonday: weekMonday,
                                weekCount: weeks,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              final msg = r.sourceItems == 0
                                  ? 'O aluno de origem não possui treino no planejamento desta semana.'
                                  : r.itemsAdded == 0
                                      ? 'Nada novo: o planejamento já tinha esse(s) grupo(s) ou exercício(s) avulsos.'
                                      : 'Treino copiado em ${r.weeksWithAdds} semana(s) · ${r.itemsAdded} exercício(s) adicionados.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
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
