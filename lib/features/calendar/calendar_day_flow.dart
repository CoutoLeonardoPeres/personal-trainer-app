import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/combo_line_grouping_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../core/utils/student_archive_display_utils.dart';
import '../../core/ui/app_modal_sheet.dart';
import '../../core/widgets/exercise_prescription_edit_dialog.dart';
import '../../core/widgets/exercise_registry_list_row.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../data/exercise_name_similarity.dart';
import '../../data/local/app_database.dart';
import '../../data/models/programmable_bundle.dart';
import '../../data/models/week_schedule_row.dart';
import '../../data/repositories/app_data_repository.dart';
import '../../core/workout/active_workout_sheet_coordinator.dart';
import '../../core/widgets/modern_loading.dart';
import 'calendar_day_exercises_sheet.dart';

/// Fluxo do dia: programar a partir da semana, iniciar treino, timer, trocar programado.
class CalendarDayFlow {
  static bool _openingWorkoutSheet = false;
  static bool _openingDaySheet = false;

  static Future<T> _runWithWorkoutOpeningLoading<T>(
    BuildContext context,
    Future<T> Function() task, {
    /// Zero: overlay aparece já no 1º frame — melhor quando abrir a modal demora.
    Duration delay = Duration.zero,
  }) async {
    OverlayEntry? entry;
    final timer = Timer(delay, () {
      if (!context.mounted) return;
      final overlay = Overlay.of(context, rootOverlay: true);
      entry = OverlayEntry(
        builder: (_) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.42),
          child: const Center(
            child: FuturisticLoadingView(size: 68),
          ),
        ),
      );
      overlay.insert(entry!);
    });

    try {
      return await task();
    } finally {
      timer.cancel();
      entry?.remove();
    }
  }

  static Future<void> open(
    BuildContext context,
    DateTime date,
    List<DayWorkoutEntity> dayWorkouts,
  ) async {
    if (_openingDaySheet) return;
    _openingDaySheet = true;
    final repo = context.read<AppDataRepository>();
    final day = DateTime(date.year, date.month, date.day);
    final label =
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';

    try {
      if (dayWorkouts.isEmpty && isCalendarDateBeforeToday(day)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível agendar treinos em datas passadas.'),
            ),
          );
        }
        return;
      }

      if (dayWorkouts.isEmpty) {
        await _openEmptyDay(context, repo, day, label);
      } else {
        await _openDayWithWorkouts(context, repo, day, label, dayWorkouts);
      }
    } finally {
      _openingDaySheet = false;
    }
  }

  /// Deep link / atalho: abre a folha de exercícios do treino (mesmo UI que programado/concluído).
  ///
  /// Live Activity / widget no ecrã bloqueado: não mostra overlay nem bloqueia em
  /// [refreshDayWorkoutFromCloud] — o treino `started` já está no SQLite local; o
  /// pull à nuvem continua disponível ao abrir pelo calendário.
  static Future<void> openDayWorkoutSheetById(
    BuildContext context,
    AppDataRepository repo,
    String dayWorkoutId, {
    bool preferRestTimerOverlay = false,
  }) async {
    if (!context.mounted) return;
    // Se a sheet desse mesmo treino já está aberta (ex.: popup de descanso ativa),
    // ignora o pedido duplicado do widget ao desbloquear para não fechar overlays.
    if (ActiveWorkoutSheetCoordinator.isWorkoutOpen(dayWorkoutId)) {
      return;
    }
    // Desbloqueio / Live Activity: não deixar Configurações (ou outras pushes)
    // por cima do MainShell — a folha de treino deve ser a única overlay na raiz.
    ActiveWorkoutSheetCoordinator.dismissCurrent();
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    if (!context.mounted) return;
    final w = await repo.getDayWorkout(dayWorkoutId);
    if (w == null) {
      final raw = await repo.getDayWorkoutLocalRow(dayWorkoutId);
      if (raw != null && context.mounted) {
        final st = await repo.getStudentById(raw.studentId);
        if (!context.mounted) return;
        if (st != null &&
            !isArchivedStudentWorkoutVisibleOnCalendarDay(
              isArchived: st.isArchived,
              archivedAt: st.archivedAt,
              workoutCalendarDay: weekScheduleLocalCalendarDate(raw.dayDate),
            )) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este treino não está disponível — o aluno está inativo a partir desta data. '
                'Reative em Cadastro › Alunos, se for o caso.',
              ),
            ),
          );
        }
      }
      return;
    }
    if (!context.mounted) return;
    final calDay = weekScheduleLocalCalendarDate(w.dayDate);
    await _onWorkoutSelected(
      context,
      repo,
      calDay,
      w,
      skipCloudPrewarmAndLoader: true,
      showRestTimerOverlayFromLive: preferRestTimerOverlay,
    );
  }

  static Future<void> _openEmptyDay(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    String label,
  ) async {
    if (isCalendarDateBeforeToday(day)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não é possível agendar treinos em datas passadas.'),
          ),
        );
      }
      return;
    }
    List<StudentEntity> students = const <StudentEntity>[];
    await _runWithWorkoutOpeningLoading(
      context,
      () async {
        students = await repo.getStudentsWithProgrammableWeek(day);
      },
    );
    if (!context.mounted) return;

    await showAppModalSheet<void>(
      context: context,
      title: label,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => FuturisticBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Text(
                'Sem treino neste dia. Escolha um aluno com planejamento válido na semana (séries e repetições preenchidas) para programar.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Nenhum aluno tem treinos agendados válidos nesta semana.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayModalStudentCard(
                            name: s.name,
                            subtitle: 'Toque para escolher o que programar',
                            onTap: () async {
                              Navigator.pop(ctx);
                              final bundles = await repo.getProgrammableBundles(
                                s.id,
                                day,
                              );
                              if (!context.mounted) return;
                              await _pickBundleAndProgram(
                                context,
                                repo,
                                s.id,
                                day,
                                bundles,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickBundleAndProgram(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime day,
    List<ProgrammableBundle> bundles,
  ) async {
    if (bundles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há treinos prontos para programar nesta semana.'),
        ),
      );
      return;
    }
    if (isCalendarDateBeforeToday(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível agendar treinos em datas passadas.'),
        ),
      );
      return;
    }

    await showAppModalSheet<void>(
      context: context,
      title: 'O que programar?',
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => FuturisticBackground(
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: bundles.length,
          itemBuilder: (_, i) {
            final b = bundles[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DayModalBundleCard(
                title: b.title,
                exerciseCount: b.rows.length,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _reviewSnapshotModal(context, repo, studentId, day, b);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<void> _reviewSnapshotModal(
    BuildContext context,
    AppDataRepository repo,
    String studentId,
    DateTime day,
    ProgrammableBundle bundle,
  ) async {
    await showAppModalSheet<void>(
      context: context,
      title: 'Ajustes (só neste dia)',
      subtitle:
          'Alterações valem só para este dia no calendário. '
          'Deslize o card do exercício para a esquerda para excluir.',
      futuristicChrome: true,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => _ProgramSnapshotEditor(
        scrollController: scroll,
        repo: repo,
        bundle: bundle,
        onConfirm: (rows) async {
          try {
            await repo.createProgrammedDayWorkout(
              studentId: studentId,
              day: day,
              rows: rows,
              sourceWorkoutGroupId: bundle.workoutGroupId,
            );
          } on ArgumentError catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.message ?? 'Não foi possível programar.'),
                ),
              );
            }
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Treino programado no calendário.')),
            );
          }
        },
      ),
    );
  }

  static Future<void> _openDayWithWorkouts(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    String label,
    List<DayWorkoutEntity> dayWorkouts,
  ) async {
    List<StudentEntity> students = const <StudentEntity>[];
    var nameMap = <String, String>{};
    var visibleStudentIds = <String>{};
    final byStudent = <String, List<DayWorkoutEntity>>{};
    var inactiveByStudentId = <String, bool>{};
    var sids = <String>[];

    final canProgramAnother =
        !repo.session.isStudent && !isCalendarDateBeforeToday(day);
    // Não bloquear a abertura da modal: este passo pode puxar muitas semanas na nuvem.
    final othersProgrammableFuture = canProgramAnother
        ? repo
              .getStudentsWithProgrammableWeek(day)
              .timeout(
                const Duration(seconds: 14),
                onTimeout: () => <StudentEntity>[],
              )
              .then(
                (list) => list.where((s) => !byStudent.containsKey(s.id)).toList(),
              )
        : Future<List<StudentEntity>>.value(const []);

    await _runWithWorkoutOpeningLoading(
      context,
      () async {
        students = await repo.watchStudentsAlphabetical().first;
        nameMap = {for (final s in students) s.id: s.name};
        visibleStudentIds = students.map((s) => s.id).toSet();
        for (final w in dayWorkouts) {
          byStudent.putIfAbsent(w.studentId, () => []).add(w);
        }
        // Treinos em dias anteriores à inativação podem referenciar alunos fora da lista ativa.
        final missingNameIds = byStudent.keys.where((id) {
          final n = nameMap[id];
          return n == null || n.trim().isEmpty;
        }).toList();
        inactiveByStudentId = <String, bool>{
          for (final sid in byStudent.keys) sid: !visibleStudentIds.contains(sid),
        };
        if (missingNameIds.isNotEmpty) {
          final fetched = await Future.wait(
            missingNameIds.map(repo.getStudentById),
          );
          for (var i = 0; i < missingNameIds.length; i++) {
            final row = fetched[i];
            final id = missingNameIds[i];
            if (row != null) {
              inactiveByStudentId[id] = row.isArchived;
            }
            final label = row?.name.trim();
            if (label != null && label.isNotEmpty) {
              nameMap[id] = label;
            }
          }
        }
        // Estado «inativo» na UI deve refletir só [isArchived], não «falta na lista»
        // (primeira emissão do stream ou timeout de rede).
        final dayStudentIds = byStudent.keys.toList(growable: false);
        if (dayStudentIds.isNotEmpty) {
          final rows = await Future.wait(
            dayStudentIds.map(
              (id) => repo
                  .getStudentById(id)
                  .timeout(const Duration(milliseconds: 2800), onTimeout: () => null),
            ),
          );
          for (var i = 0; i < dayStudentIds.length; i++) {
            final row = rows[i];
            final id = dayStudentIds[i];
            if (row != null) {
              nameMap[id] = row.name;
              inactiveByStudentId[id] = row.isArchived;
            } else {
              inactiveByStudentId[id] = false;
              nameMap.putIfAbsent(id, () => id);
            }
          }
        }
        String dayModalSortLabel(String sid) {
          final raw = nameMap[sid] ?? sid;
          final inactive = inactiveByStudentId[sid] ?? false;
          final label = inactive ? studentNameWithoutArchivePrefix(raw) : raw;
          return label.toLowerCase();
        }

        sids = byStudent.keys.toList()
          ..sort((a, b) => dayModalSortLabel(a).compareTo(dayModalSortLabel(b)));
      },
    );

    if (!context.mounted) return;

    var studentTapLocked = false;

    Future<DayWorkoutEntity?> pickWorkoutFromStudentDayList(
      String studentId,
      List<DayWorkoutEntity> list,
    ) async {
      if (list.isEmpty) return null;
      if (list.length == 1) return list.single;

      // Ordena de forma estável (mesma regra do “prioritário”).
      final sorted = List<DayWorkoutEntity>.from(list)
        ..sort((a, b) {
          int priority(String status) => switch (status) {
            'started' => 0,
            'programmed' => 1,
            'scheduled' => 2,
            'completed' => 3,
            _ => 4,
          };
          final c = priority(a.status).compareTo(priority(b.status));
          if (c != 0) return c;
          return a.id.compareTo(b.id);
        });

      // Pré-carrega rótulos/selos (best effort) para mostrar todos os grupos.
      final badges = <String, String?>{};
      await Future.wait(
        sorted.map((w) async {
          try {
            final b = await repo
                .getDayWorkoutGroupBadgeLabel(w)
                .timeout(const Duration(milliseconds: 900), onTimeout: () => null);
            badges[w.id] = b;
          } catch (_) {
            badges[w.id] = null;
          }
        }),
      );

      if (!context.mounted) return null;
      final picked = await showAppModalSheet<DayWorkoutEntity>(
        context: context,
        futuristicChrome: true,
        title: 'Treinos do dia',
        subtitle: 'Escolha qual treino abrir para este aluno.',
        initialChildSize: 0.72,
        maxChildSize: 0.85,
        builder: (ctx, scroll) => FuturisticBackground(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final w = sorted[i];
              final badge = badges[w.id]?.trim();
              final statusLabel = switch (w.status) {
                'started' => 'Em andamento',
                'programmed' => 'Programado',
                'scheduled' => 'Agendado',
                'completed' => 'Concluído',
                _ => w.status,
              };
              final subtitle = badge != null && badge.isNotEmpty
                  ? '$statusLabel · $badge'
                  : statusLabel;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DayModalStudentCard(
                  name: 'Treino ${i + 1}',
                  subtitle: subtitle,
                  onTap: () => Navigator.pop(ctx, w),
                ),
              );
            },
          ),
        ),
      );
      return picked;
    }

    Future<void> openStudentWorkout(String studentKey) async {
      final list = List<DayWorkoutEntity>.from(byStudent[studentKey] ?? const []);
      if (list.isEmpty) return;

      // Local-first: abre imediatamente usando snapshot local (rápido) e
      // sincroniza da nuvem em background para convergência entre dispositivos.
      final w = await pickWorkoutFromStudentDayList(studentKey, list);
      if (w == null) return;
      if (!context.mounted) return;
      await _onWorkoutSelected(
        context,
        repo,
        day,
        w,
        // Mantém abertura rápida da modal; sincronismo fino acontece em background.
        skipCloudPrewarmAndLoader: true,
      );
      unawaited(
        Future.wait(
          list.map(
            (x) => repo
                .refreshDayWorkoutFromCloud(x.id)
                .timeout(const Duration(milliseconds: 1200), onTimeout: () {}),
          ),
        ),
      );
    }

    final isAdmin = repo.session.hasFullOrgAccess;

    await showAppModalSheet<void>(
      context: context,
      title: label,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => FuturisticBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alunos com treino neste dia',
                    style: TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Admin: deslize o card para a esquerda para excluir todos os treinos deste aluno neste dia.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SlidableAutoCloseBehavior(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // `for (var i …); sids[i]` dentro de um [Builder] partilha o mesmo
                    // `i` em todas as closures — ao construir a lista, abria o aluno errado
                    // ou falhava. Usar `for (final sid in sids)` fixa o id por cartão.
                    for (final sid in sids) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DayModalStudentListTile(
                          sid: sid,
                          inactiveByStudentId: inactiveByStudentId,
                          nameMap: nameMap,
                          byStudent: byStudent,
                          isAdmin: isAdmin,
                          sheetContext: ctx,
                          parentContext: context,
                          repo: repo,
                          day: day,
                          onOpenStudent: () {
                            if (studentTapLocked) return;
                            studentTapLocked = true;
                            Navigator.pop(ctx);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!context.mounted) {
                                studentTapLocked = false;
                                return;
                              }
                              unawaited(() async {
                                try {
                                  await openStudentWorkout(sid);
                                } finally {
                                  studentTapLocked = false;
                                }
                              }());
                            });
                          },
                        ),
                      ),
                    ],
                    FutureBuilder<List<StudentEntity>>(
                      future: othersProgrammableFuture,
                      // Não nomear este [BuildContext] de «context»: sombreia o
                      // [context] do calendário; após [Navigator.pop] da folha o
                      // filho desmonta e «!context.mounted» bloqueava o fluxo.
                      builder: (_, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
                            child: Center(
                              child: ModernLoadingIndicator(size: 28),
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                            child: Text(
                              'Não foi possível carregar a lista para programar.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        final othersProgrammable = snap.data ?? const [];
                        if (othersProgrammable.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                              child: Text(
                                'Programar outro aluno neste dia',
                                style: TextStyle(
                                  color: AppColors.accentGreen.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                              child: Text(
                                'Com planejamento na semana, mas sem treino neste dia:',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            for (final s in othersProgrammable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DayModalStudentCard(
                                  name: s.name,
                                  subtitle: 'Toque para escolher o que programar',
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final bundles =
                                        await repo.getProgrammableBundles(
                                      s.id,
                                      day,
                                    );
                                    if (!context.mounted) return;
                                    await _pickBundleAndProgram(
                                      context,
                                      repo,
                                      s.id,
                                      day,
                                      bundles,
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> _confirmAdminDeleteDayWorkouts(
    BuildContext context, {
    required String studentName,
    required int workoutCount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0D1A2F).withValues(alpha: 0.97),
                const Color(0xFF19172C).withValues(alpha: 0.97),
              ],
            ),
            border: Border.all(
              color: AppColors.accentPink.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPink.withValues(alpha: 0.16),
                blurRadius: 26,
                spreadRadius: 1,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: AppColors.danger.withValues(alpha: 0.22),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.danger.withValues(alpha: 0.95),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excluir treino(s) do dia?',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ação crítica de administrador',
                            style: TextStyle(
                              color: AppColors.accentPink.withValues(alpha: 0.88),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Serão apagados permanentemente $workoutCount treino(s) de '
                  '$studentName nesta data, incluindo concluídos, com todas as séries, tempos e scores. '
                  'Os dados serão removidos do aparelho e da nuvem após sincronizar.\n\n'
                  'Não é possível desfazer.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 13.7,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.82),
                          side: BorderSide(
                            color: AppColors.accentGreen.withValues(alpha: 0.46),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Excluir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _onWorkoutSelected(
    BuildContext context,
    AppDataRepository repo,
    DateTime day,
    DayWorkoutEntity w, {
    bool skipCloudPrewarmAndLoader = false,
    bool showRestTimerOverlayFromLive = false,
  }) async {
    if (!context.mounted) return;
    if (_openingWorkoutSheet) return;
    _openingWorkoutSheet = true;

    Future<void> Function(BuildContext sheetContext)? onSwap;
    String studentName = 'Aluno';
    var studentInactive = false;
    DayWorkoutEntity workout = w;
    String? badge;
    try {
      await _runWithWorkoutOpeningLoading(context, () async {
        if (!skipCloudPrewarmAndLoader) {
          // Atualização pontual antes de abrir para diminuir estado "atrasado"
          // quando o treino mudou noutro dispositivo há poucos segundos.
          await repo
              .refreshDayWorkoutFromCloud(w.id)
              .timeout(const Duration(milliseconds: 1200), onTimeout: () {});
          await repo
              .prewarmCompletedHistoryForWorkout(w.id, limit: 60)
              .timeout(const Duration(milliseconds: 1600), onTimeout: () {});
        }
        if (!context.mounted) return;
        final refreshed = await repo.getDayWorkout(w.id);
        workout = refreshed ?? w;

        final found = await repo
            .getStudentById(workout.studentId)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        if (found != null) {
          studentName = found.name;
          studentInactive = found.isArchived;
        } else {
          // Timeout/rede: não tratar como «inativo» — só falta o nome.
          studentInactive = false;
        }
        if (studentInactive) {
          studentName = studentNameWithoutArchivePrefix(studentName);
        }
        if (!context.mounted) return;
        badge = await repo.getDayWorkoutGroupBadgeLabel(workout);
        if (!context.mounted) return;

        if (workout.status == 'programmed') {
          onSwap = (sheetCtx) => _runSwapWorkoutFromSheet(
            sheetContext: sheetCtx,
            parentContext: context,
            repo: repo,
            day: day,
            workout: workout,
          );
        }
      }).timeout(const Duration(seconds: 8), onTimeout: () {});

      if (!context.mounted) return;
      await showProgrammedDayExercisesSheet(
        context: context,
        repo: repo,
        workout: workout,
        studentName: studentName,
        studentInactive: studentInactive,
        day: day,
        workoutBadgeLabel: badge,
        onSwapWorkout: onSwap,
        showRestTimerOverlayFromLive: showRestTimerOverlayFromLive,
      );
    } finally {
      _openingWorkoutSheet = false;
    }
  }

  /// Substitui o treino programado: fecha a sheet, apaga o dia e abre escolha de bundle.
  static Future<void> _runSwapWorkoutFromSheet({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required AppDataRepository repo,
    required DateTime day,
    required DayWorkoutEntity workout,
  }) async {
    if (isCalendarDateBeforeToday(day)) {
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Não é possível substituir treino em data passada.'),
          ),
        );
      }
      return;
    }
    final ok = await repo.deleteProgrammedDayWorkout(workout.id);
    if (!parentContext.mounted) return;
    if (!ok) return;
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    final bundles = await repo.getProgrammableBundles(workout.studentId, day);
    if (!parentContext.mounted) return;
    await _pickBundleAndProgram(
      parentContext,
      repo,
      workout.studentId,
      day,
      bundles,
    );
  }
}

/// Uma linha da lista “alunos com treino neste dia” — [sid] fixo por instância
/// (evita o bug do `for (var i)` + [Builder] que partilhava o índice).
class _DayModalStudentListTile extends StatelessWidget {
  const _DayModalStudentListTile({
    required this.sid,
    required this.inactiveByStudentId,
    required this.nameMap,
    required this.byStudent,
    required this.isAdmin,
    required this.sheetContext,
    required this.parentContext,
    required this.repo,
    required this.day,
    required this.onOpenStudent,
  });

  final String sid;
  final Map<String, bool> inactiveByStudentId;
  final Map<String, String> nameMap;
  final Map<String, List<DayWorkoutEntity>> byStudent;
  final bool isAdmin;
  final BuildContext sheetContext;
  final BuildContext parentContext;
  final AppDataRepository repo;
  final DateTime day;
  final VoidCallback onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final inactive = inactiveByStudentId[sid] ?? false;
    final rawName = nameMap[sid] ?? sid;
    final displayName = inactive
        ? studentNameWithoutArchivePrefix(rawName)
        : rawName;
    final n = byStudent[sid]!.length;
    final subtitle = n == 1
        ? 'Toque para abrir o treino'
        : '$n treinos no dia — abre o prioritário (em andamento → programado → concluído)';

    final card = _DayModalStudentCard(
      name: displayName,
      isInactiveStudent: inactive,
      subtitle: subtitle,
      onTap: onOpenStudent,
    );

    if (!isAdmin) return card;

    return Slidable(
      key: ValueKey('day_modal_student_$sid'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.36,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final ok = await CalendarDayFlow._confirmAdminDeleteDayWorkouts(
                sheetContext,
                studentName: displayName,
                workoutCount: n,
              );
              if (ok != true || !sheetContext.mounted) return;
              try {
                final removed = await repo
                    .adminHardDeleteAllDayWorkoutsForStudent(
                      studentId: sid,
                      day: day,
                    );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        removed == 0
                            ? 'Nenhum treino removido.'
                            : '$removed treino(s) de $displayName removido(s). '
                                  'A exclusão será enviada à nuvem em seguida.',
                      ),
                    ),
                  );
                }
              } on ArgumentError catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(e.message ?? 'Não foi possível excluir.'),
                    ),
                  );
                }
              } catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e')),
                  );
                }
              }
            },
            backgroundColor: AppColors.danger.withValues(alpha: 0.92),
            foregroundColor: Colors.white,
            icon: Icons.delete_forever_rounded,
            label: 'Excluir\ndia',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
          ),
        ],
      ),
      child: card,
    );
  }
}

/// Card de aluno nas modais do dia (calendário).
class _DayModalStudentCard extends StatelessWidget {
  const _DayModalStudentCard({
    required this.name,
    this.isInactiveStudent = false,
    required this.subtitle,
    required this.onTap,
  });

  final String name;

  /// Aluno inativo (arquivado): só aparece em dias anteriores à inativação; fora disso some da grade.
  final bool isInactiveStudent;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _inactiveTint = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;
    final avatarMuted = isInactiveStudent
        ? _inactiveTint.withValues(alpha: 0.35)
        : blueSoft.withValues(alpha: 0.28);
    final avatarBorder = isInactiveStudent
        ? _inactiveTint.withValues(alpha: 0.55)
        : blue.withValues(alpha: 0.55);
    final avatarIcon = isInactiveStudent
        ? Icons.person_off_rounded
        : Icons.person_rounded;
    final avatarIconColor = isInactiveStudent
        ? _inactiveTint.withValues(alpha: 0.92)
        : blueSoft.withValues(alpha: 0.95);
    return FuturisticCard(
      onTap: onTap,
      borderColor: blue.withValues(alpha: 0.88),
      borderWidth: 1.15,
      backgroundGradient: [
        blueSoft.withValues(alpha: 0.22),
        blue.withValues(alpha: 0.12),
        Colors.black.withValues(alpha: 0.26),
      ],
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  avatarMuted,
                  blue.withValues(alpha: isInactiveStudent ? 0.1 : 0.16),
                ],
              ),
              border: Border.all(color: avatarBorder),
              boxShadow: [
                BoxShadow(
                  color: (isInactiveStudent ? _inactiveTint : blueSoft)
                      .withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(avatarIcon, color: avatarIconColor, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                if (isInactiveStudent) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 14,
                        color: _inactiveTint.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Aluno inativo',
                        style: TextStyle(
                          color: _inactiveTint.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.accentGreen.withValues(alpha: 0.9),
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Card de bloco (grupo / avulsos) ao programar o dia.
class _DayModalBundleCard extends StatelessWidget {
  const _DayModalBundleCard({
    required this.title,
    required this.exerciseCount,
    required this.onTap,
  });

  final String title;
  final int exerciseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;
    return FuturisticCard(
      onTap: onTap,
      borderColor: blue.withValues(alpha: 0.88),
      borderWidth: 1.15,
      backgroundGradient: [
        blueSoft.withValues(alpha: 0.22),
        blue.withValues(alpha: 0.12),
        Colors.black.withValues(alpha: 0.26),
      ],
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  blueSoft.withValues(alpha: 0.28),
                  blue.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: blue.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.layers_rounded,
                color: blueSoft.withValues(alpha: 0.95),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$exerciseCount exercício${exerciseCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.accentGreen.withValues(alpha: 0.9),
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _ProgramSnapshotEditor extends StatefulWidget {
  const _ProgramSnapshotEditor({
    required this.scrollController,
    required this.repo,
    required this.bundle,
    required this.onConfirm,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;
  final ProgrammableBundle bundle;
  final Future<void> Function(List<WeekScheduleRow> rows) onConfirm;

  @override
  State<_ProgramSnapshotEditor> createState() => _ProgramSnapshotEditorState();
}

class _ProgramSnapshotEditorState extends State<_ProgramSnapshotEditor> {
  static const _uuid = Uuid();
  late List<WeekScheduleRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List<WeekScheduleRow>.from(widget.bundle.rows);
    _renumberSortOrders();
  }

  void _renumberSortOrders() {
    _rows.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
    for (var i = 0; i < _rows.length; i++) {
      final it = _rows[i].item;
      _rows[i] = WeekScheduleRow(
        item: it.copyWith(sortOrder: i),
        exerciseName: _rows[i].exerciseName,
      );
    }
  }

  void _removeBlock(List<WeekScheduleRow> block) {
    if (block.isEmpty) return;
    if (_rows.length - block.length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mantenha pelo menos um exercício para programar o dia, ou feche o painel.',
          ),
        ),
      );
      return;
    }
    final ids = {for (final r in block) r.item.id};
    _rows.removeWhere((r) => ids.contains(r.item.id));
    _renumberSortOrders();
    setState(() {});
  }

  Future<void> _editRowAt(int index) async {
    final r = _rows[index];
    final i = r.item;
    final repsDisp = weekScheduleRepsDisplay(i);
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: r.exerciseName,
      badgeLabel: 'AJUSTES (SÓ NESTE DIA)',
      descriptionLine:
          'Métricas só para programar este dia; o planejamento semanal não é alterado.',
      headerIcon: Icons.today_rounded,
      initialSets: i.sets > 0 ? i.sets : 3,
      initialRepsText: repsDisp.isEmpty ? '10' : repsDisp,
      initialRestBetweenSetsSec: i.restBetweenSetsSec > 0
          ? i.restBetweenSetsSec
          : 60,
      initialLoadKg: i.loadKg,
      initialTrainingMethodId: i.trainingMethodId,
    );
    if (!mounted || res == null) return;
    final newItem = i.copyWith(
      sets: res.sets,
      reps: res.repsHintInt,
      repsText: Value(res.repsText),
      loadKg: Value(res.loadKg),
      restBetweenSetsSec: res.restBetweenSetsSec,
      needsDetail: false,
      trainingMethodId: Value(res.trainingMethodId),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _rows[index] = WeekScheduleRow(
        item: newItem,
        exerciseName: r.exerciseName,
      );
    });
  }

  Future<void> _openAddExercisePicker() async {
    final picked = await showAppModalSheet<ExerciseEntity>(
      context: context,
      title: 'Adicionar exercício',
      subtitle:
          'Entra só neste treino deste dia. O planejamento semanal não é alterado.',
      futuristicChrome: true,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _DaySnapshotAddExercisePicker(
        scrollController: scroll,
        repo: widget.repo,
      ),
    );
    if (!mounted || picked == null) return;

    final template = _rows.first.item;
    final now = DateTime.now();
    final rest = template.restBetweenSetsSec > 0
        ? template.restBetweenSetsSec
        : 60;
    final item = WeekScheduleItemEntity(
      id: _uuid.v4(),
      blockId: template.blockId,
      exerciseId: picked.id,
      sourceWorkoutGroupId: widget.bundle.workoutGroupId,
      sortOrder: _rows.length,
      sets: 3,
      reps: 10,
      repsText: '10',
      loadKg: null,
      needsDetail: false,
      restBetweenSetsSec: rest,
      trainingMethodId: null,
      updatedAt: now,
      comboId: null,
    );
    setState(() {
      _rows.add(WeekScheduleRow(item: item, exerciseName: picked.name));
    });
    _renumberSortOrders();
  }

  Future<void> _combineFromBlock(List<WeekScheduleRow> block) async {
    final anchor = block.last;
    final picked = await showAppModalSheet<ExerciseEntity>(
      context: context,
      title: 'Combinar com exercício',
      subtitle: 'Bloco sem intervalo entre os movimentos neste dia.',
      futuristicChrome: true,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _DaySnapshotAddExercisePicker(
        scrollController: scroll,
        repo: widget.repo,
      ),
    );
    if (!mounted || picked == null) return;
    final res = await showExercisePrescriptionEditDialog(
      context,
      repo: widget.repo,
      exerciseName: picked.name,
      badgeLabel: 'AJUSTES · COMBINAR',
      descriptionLine:
          'Prescrição no bloco; descanso vale após o último exercício do bloco.',
      headerIcon: Icons.merge_type_rounded,
      initialSets: 3,
      initialRepsText: '12-15',
      initialRestBetweenSetsSec: anchor.item.restBetweenSetsSec > 0
          ? anchor.item.restBetweenSetsSec
          : 60,
      initialLoadKg: null,
      initialTrainingMethodId: null,
    );
    if (!mounted || res == null) return;
    final comboId =
        (anchor.item.comboId != null && anchor.item.comboId!.trim().isNotEmpty)
        ? anchor.item.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();
    final idx = _rows.indexWhere((r) => r.item.id == anchor.item.id);
    if (idx < 0) return;
    if (anchor.item.comboId == null || anchor.item.comboId!.trim().isEmpty) {
      final it = _rows[idx].item;
      _rows[idx] = WeekScheduleRow(
        item: it.copyWith(comboId: Value(comboId), updatedAt: now),
        exerciseName: _rows[idx].exerciseName,
      );
    }
    final newItem = WeekScheduleItemEntity(
      id: _uuid.v4(),
      blockId: anchor.item.blockId,
      exerciseId: picked.id,
      sourceWorkoutGroupId: anchor.item.sourceWorkoutGroupId,
      sortOrder: anchor.item.sortOrder + 1,
      sets: res.sets,
      reps: res.repsHintInt,
      repsText: res.repsText,
      loadKg: res.loadKg,
      needsDetail: false,
      restBetweenSetsSec: res.restBetweenSetsSec,
      trainingMethodId: res.trainingMethodId,
      updatedAt: now,
      comboId: comboId,
    );
    _rows.insert(
      idx + 1,
      WeekScheduleRow(item: newItem, exerciseName: picked.name),
    );
    _renumberSortOrders();
    setState(() {});
  }

  void _reorderSnapshotBlocks(
    List<List<WeekScheduleRow>> blocks,
    int oldIndex,
    int newIndex,
  ) {
    if (blocks.length < 2) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= blocks.length) return;

    final reordered = List<List<WeekScheduleRow>>.from(blocks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);

    final next = <WeekScheduleRow>[];
    for (final b in reordered) {
      next.addAll(b);
    }
    _rows
      ..clear()
      ..addAll(next);
    _renumberSortOrders();
    setState(() {});
  }

  Future<void> _editRowWithId(String itemId) async {
    final index = _rows.indexWhere((r) => r.item.id == itemId);
    if (index >= 0) await _editRowAt(index);
  }

  Widget _snapshotDragHandle(int listIndex, {double iconSize = 22}) {
    if (listIndex == 0) return const SizedBox.shrink();
    return ReorderableDragStartListener(
      index: listIndex,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            Icons.drag_indicator_rounded,
            color: Colors.white.withValues(alpha: 0.58),
            size: iconSize,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocks = weekScheduleRowsAsComboBlocks(_rows);
    return StreamBuilder<List<ExerciseEntity>>(
      stream: widget.repo.watchExercisesAlphabetical(),
      builder: (context, exSnap) {
        final idToExercise = <String, ExerciseEntity>{
          for (final e in exSnap.data ?? <ExerciseEntity>[]) e.id: e,
        };
        return Column(
          children: [
            Expanded(
              child: FuturisticBackground(
                child: SlidableAutoCloseBehavior(
                  child: ReorderableListView.builder(
                    scrollController: widget.scrollController,
                    buildDefaultDragHandles: false,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                    itemCount: blocks.length + 1,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex == 0 || newIndex == 0) return;
                      final biOld = oldIndex - 1;
                      final biNew = newIndex - 1;
                      _reorderSnapshotBlocks(blocks, biOld, biNew);
                    },
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          key: const ValueKey('snap_add_exercise_tile'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openAddExercisePicker,
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.splashMint.withValues(
                                        alpha: 0.22,
                                      ),
                                      AppColors.cadastroCardBorder.withValues(
                                        alpha: 0.2,
                                      ),
                                      Colors.black.withValues(alpha: 0.35),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.accentGreen.withValues(
                                      alpha: 0.55,
                                    ),
                                    width: 1.05,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.splashMint.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.splashMint.withValues(
                                              alpha: 0.45,
                                            ),
                                            AppColors.cadastroCardBorder
                                                .withValues(alpha: 0.35),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: AppColors.accentGreen
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: AppColors.textPrimary,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Adicionar exercício',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Só neste dia · abre lista para escolher',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.52,
                                              ),
                                              fontSize: 11,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: AppColors.accentGreen.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final blockIndex = i - 1;
                      final block = blocks[blockIndex];
                      if (block.length == 1) {
                        final r = block.single;
                        final wi = r.item;
                        final repsD = weekScheduleRepsDisplay(wi);
                        final detail =
                            'Séries: ${wi.sets}  Reps: $repsD  '
                            'Carga: ${wi.loadKg?.toString() ?? '—'} kg  ·  '
                            'Descanso: ${wi.restBetweenSetsSec}s';
                        return Padding(
                          key: ValueKey('snap_${r.item.id}'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Slidable(
                            key: ValueKey('snap_slidable_${r.item.id}'),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: 0.56,
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _combineFromBlock(block),
                                  backgroundColor: const Color(0xFF7E57C2),
                                  foregroundColor: Colors.white,
                                  icon: Icons.merge_type_rounded,
                                  label: 'Combinar',
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                SlidableAction(
                                  onPressed: (_) => _removeBlock(block),
                                  backgroundColor: AppColors.danger.withValues(
                                    alpha: 0.92,
                                  ),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Excluir',
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.calendarFutureProgrammed
                                          .withValues(alpha: 0.2),
                                      AppColors.cadastroCardBorder.withValues(
                                        alpha: 0.11,
                                      ),
                                      Colors.black.withValues(alpha: 0.26),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.cadastroCardBorder
                                        .withValues(alpha: 0.82),
                                    width: 1.05,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.calendarFutureProgrammed
                                          .withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _editRowWithId(r.item.id),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            8,
                                            4,
                                            8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                r.exerciseName,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  height: 1.15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                detail,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.52),
                                                  fontSize: 12,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (exerciseEntityHasAnyVideoUrl(
                                      idToExercise[r.item.exerciseId],
                                    ))
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children:
                                            exerciseRegistryVideoTrailingButtons(
                                              context,
                                              idToExercise[r.item.exerciseId],
                                              r.exerciseName,
                                              iconSize: 20,
                                            ),
                                      ),
                                    _snapshotDragHandle(i),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final names = block
                          .map((r) => r.exerciseName)
                          .join(' · ');
                      final detailCombo = StringBuffer();
                      for (var k = 0; k < block.length; k++) {
                        final r = block[k];
                        final wi = r.item;
                        final repsD = weekScheduleRepsDisplay(wi);
                        if (k > 0) detailCombo.write('\n');
                        detailCombo.write(
                          '${r.exerciseName}: ${wi.sets}×$repsD  ·  '
                          '${wi.loadKg?.toString() ?? '—'} kg  ·  '
                          '${wi.restBetweenSetsSec}s',
                        );
                      }
                      return Padding(
                        key: ValueKey(
                          'snap_combo_${block.first.item.comboId}_$blockIndex',
                        ),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Slidable(
                          key: ValueKey(
                            'snap_slidable_combo_${block.first.item.comboId}',
                          ),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.56,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _combineFromBlock(block),
                                backgroundColor: const Color(0xFF7E57C2),
                                foregroundColor: Colors.white,
                                icon: Icons.merge_type_rounded,
                                label: 'Combinar',
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              SlidableAction(
                                onPressed: (_) => _removeBlock(block),
                                backgroundColor: AppColors.danger.withValues(
                                  alpha: 0.92,
                                ),
                                foregroundColor: Colors.white,
                                icon: Icons.delete_outline_rounded,
                                label: 'Excluir',
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            clipBehavior: Clip.antiAlias,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.calendarFutureProgrammed
                                        .withValues(alpha: 0.2),
                                    AppColors.cadastroCardBorder.withValues(
                                      alpha: 0.11,
                                    ),
                                    Colors.black.withValues(alpha: 0.26),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.cadastroCardBorder
                                      .withValues(alpha: 0.82),
                                  width: 1.05,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.calendarFutureProgrammed
                                        .withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final choice =
                                            await showModalBottomSheet<
                                              WeekScheduleRow
                                            >(
                                              context: context,
                                              backgroundColor:
                                                  AppColors.barBackground,
                                              builder: (ctx) => SafeArea(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    const Padding(
                                                      padding: EdgeInsets.all(
                                                        16,
                                                      ),
                                                      child: Text(
                                                        'Editar exercício do bloco',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .textPrimary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    for (final r in block)
                                                      ListTile(
                                                        title: Text(
                                                          r.exerciseName,
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              r,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                        if (!context.mounted ||
                                            choice == null) {
                                          return;
                                        }
                                        await _editRowWithId(choice.item.id);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          8,
                                          4,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Combinação: $names',
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              detailCombo.toString(),
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
                                  if (block.any(
                                    (r) => exerciseEntityHasAnyVideoUrl(
                                      idToExercise[r.item.exerciseId],
                                    ),
                                  ))
                                    IconButton(
                                      tooltip: 'Vídeos do bloco',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 40,
                                            height: 40,
                                          ),
                                      icon: Icon(
                                        Icons.ondemand_video_rounded,
                                        color: kExerciseRegistryRowIconTint,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          showExerciseBlockVideoLinksBottomSheet(
                                            context,
                                            title: 'Vídeos do bloco',
                                            lines: [
                                              for (final r in block)
                                                (
                                                  name: r.exerciseName,
                                                  exercise:
                                                      idToExercise[r
                                                          .item
                                                          .exerciseId],
                                                ),
                                            ],
                                          ),
                                    ),
                                  _snapshotDragHandle(i),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: AppPrimaryButton(
                label: 'Programar no calendário',
                icon: Icons.check_rounded,
                onPressed: _rows.isEmpty
                    ? null
                    : () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        for (final r in _rows) {
                          if (!weekScheduleItemHasValidPrescription(r.item)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Toque em «${r.exerciseName}» e preencha séries e repetições.',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                        await widget.onConfirm(
                          List<WeekScheduleRow>.from(_rows),
                        );
                      },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lista pesquisável de exercícios para incluir no snapshot do dia (modal aninhada).
class _DaySnapshotAddExercisePicker extends StatefulWidget {
  const _DaySnapshotAddExercisePicker({
    required this.scrollController,
    required this.repo,
  });

  final ScrollController scrollController;
  final AppDataRepository repo;

  @override
  State<_DaySnapshotAddExercisePicker> createState() =>
      _DaySnapshotAddExercisePickerState();
}

class _DaySnapshotAddExercisePickerState
    extends State<_DaySnapshotAddExercisePicker> {
  final _queryC = TextEditingController();

  @override
  void dispose() {
    _queryC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = AppColors.cadastroCardBorder;
    final blueSoft = AppColors.calendarFutureProgrammed;

    return FuturisticBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: AppCadastroSearchField(
              controller: _queryC,
              label: 'Buscar por nome',
              hint: 'Digite para filtrar',
              onChanged: (_) => setState(() {}),
              autofocus: true,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ExerciseEntity>>(
              stream: widget.repo.watchExercisesAlphabetical(),
              builder: (context, snap) {
                final all = snap.data ?? [];
                if (all.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum exercício cadastrado.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                final filtered = filterExercisesByNameQuery(
                  _queryC.text.trim(),
                  all,
                );
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Nenhum exercício encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FuturisticCard(
                        onTap: () => Navigator.pop(context, e),
                        borderColor: blue.withValues(alpha: 0.82),
                        borderWidth: 1.1,
                        backgroundGradient: [
                          blueSoft.withValues(alpha: 0.2),
                          blue.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            ...exerciseRegistryVideoTrailingButtons(
                              context,
                              e,
                              e.name,
                            ),
                            Icon(
                              Icons.touch_app_rounded,
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.85,
                              ),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
