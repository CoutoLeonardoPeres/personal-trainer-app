import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Abas principais (da esquerda para a direita na barra):
/// Performance, Calendário, Planejamento, Cadastro.
enum MainNavTab { performance, calendar, planning, cadastro }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selected,
    required this.onSelect,
    this.tabsInOrder,
  });

  final MainNavTab selected;
  final ValueChanged<MainNavTab> onSelect;
  /// Abas visíveis (ordem na barra). Null = todas.
  final List<MainNavTab>? tabsInOrder;

  static const double barHeight = 39.0 * 1.15 * 1.15;

  static const _items = <({MainNavTab tab, IconData icon, String label})>[
    (tab: MainNavTab.performance, icon: Icons.show_chart_rounded, label: 'Performance'),
    (tab: MainNavTab.calendar, icon: Icons.calendar_today_rounded, label: 'Calendário'),
    (tab: MainNavTab.planning, icon: Icons.fitness_center_rounded, label: 'Planejamento'),
    (tab: MainNavTab.cadastro, icon: Icons.app_registration_rounded, label: 'Cadastro'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final order = tabsInOrder ??
        MainNavTab.values
            .where((t) => _items.any((i) => i.tab == t))
            .toList();
    final visible = <({MainNavTab tab, IconData icon, String label})>[];
    for (final t in order) {
      for (final item in _items) {
        if (item.tab == t) {
          visible.add(item);
          break;
        }
      }
    }
    return Container(
      height: barHeight + bottomInset,
      decoration: BoxDecoration(
        color: AppColors.barBackground.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: AppColors.accentGreen.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final item in visible)
              _NavItem(
                icon: item.icon,
                label: item.label,
                selected: selected == item.tab,
                onTap: () => onSelect(item.tab),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accentGreen.withValues(alpha: selected ? 1 : 0.42);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
