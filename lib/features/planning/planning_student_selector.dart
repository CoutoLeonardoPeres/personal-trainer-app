import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/app_database.dart';

sealed class _StudentPickResult {}

class _PickDismiss extends _StudentPickResult {}

class _PickClear extends _StudentPickResult {}

class _PickStudent extends _StudentPickResult {
  _PickStudent(this.id);
  final String id;
}

/// Seletor de aluno com visual futurista (campo + lista em bottom sheet).
class PlanningFuturisticStudentSelector extends StatelessWidget {
  const PlanningFuturisticStudentSelector({
    super.key,
    required this.students,
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
  });

  final List<StudentEntity> students;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  String get _displayName {
    if (selectedId == null) return 'Selecione o aluno';
    for (final s in students) {
      if (s.id == selectedId) return s.name;
    }
    return 'Selecione o aluno';
  }

  Future<void> _openSheet(BuildContext context) async {
    if (!enabled || students.isEmpty) return;
    final result = await showModalBottomSheet<_StudentPickResult?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StudentPickerSheet(
        students: students,
        selectedId: selectedId,
      ),
    );
    if (!context.mounted) return;
    if (result is _PickStudent) {
      onChanged(result.id);
    } else if (result is _PickClear) {
      onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = enabled && students.isNotEmpty;
    final labelColor = AppColors.accentGreen.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpen ? () => _openSheet(context) : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cadastroCardBorder.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.45),
                AppColors.accentGreen.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: canOpen
                  ? AppColors.cadastroCardBorder.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.25,
            ),
            boxShadow: canOpen
                ? [
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.12),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentGreen.withValues(alpha: 0.35),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentGreen.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.person_search_rounded,
                    color: canOpen
                        ? AppColors.accentGreen
                        : Colors.white.withValues(alpha: 0.25),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALUNO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.35,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        students.isEmpty && enabled
                            ? 'Nenhum aluno cadastrado'
                            : _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: canOpen
                              ? AppColors.textPrimary
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: canOpen
                      ? AppColors.cadastroCardBorder
                      : Colors.white.withValues(alpha: 0.2),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentPickerSheet extends StatelessWidget {
  const _StudentPickerSheet({
    required this.students,
    required this.selectedId,
  });

  final List<StudentEntity> students;
  final String? selectedId;

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.48,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.barBackground,
                    AppColors.backgroundDeep,
                    Colors.black,
                  ],
                ),
                border: Border.all(
                  color: AppColors.cadastroCardBorder.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      color: AppColors.accentGreen.withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Escolher aluno',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context, _PickDismiss()),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.accentGreen.withValues(alpha: 0.35),
                      AppColors.cadastroCardBorder.withValues(alpha: 0.5),
                      AppColors.accentGreen.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 16 + bottom),
                  children: [
                    _SheetTile(
                      title: 'Selecione o aluno',
                      subtitle: 'Limpar seleção atual',
                      icon: Icons.person_off_outlined,
                      isSelected: selectedId == null,
                      dimmed: true,
                      onTap: () => Navigator.pop(context, _PickClear()),
                    ),
                    const SizedBox(height: 6),
                    ...students.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SheetTile(
                          title: s.name,
                          subtitle: 'Planejamento semanal',
                          leadingInitial: _initial(s.name),
                          isSelected: s.id == selectedId,
                          onTap: () =>
                              Navigator.pop(context, _PickStudent(s.id)),
                        ),
                      ),
                    ),
                  ],
                ),
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

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leadingInitial,
    this.icon,
    this.isSelected = false,
    this.dimmed = false,
  });

  final String title;
  final String? subtitle;
  final String? leadingInitial;
  final IconData? icon;
  final bool isSelected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = isSelected
        ? AppColors.accentGreen.withValues(alpha: 0.65)
        : AppColors.cadastroCardBorder.withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected
                ? AppColors.accentGreen.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: border, width: isSelected ? 1.4 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    color: dimmed
                        ? Colors.white.withValues(alpha: 0.45)
                        : AppColors.textMuted,
                    size: 26,
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentGreen.withValues(alpha: 0.4),
                      ),
                      color: AppColors.accentPink.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      leadingInitial ?? '?',
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                        style: TextStyle(
                          color: dimmed
                              ? Colors.white.withValues(alpha: 0.55)
                              : AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accentGreen,
                    size: 26,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
