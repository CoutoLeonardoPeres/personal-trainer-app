import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/brazil_states.dart';
import '../theme/app_colors.dart';

/// Abre o seletor de UF com visual futurista (gradiente, busca, chips).
/// Use em todos os fluxos que escolhem estado brasileiro.
Future<void> showBrazilStatePickerSheet(
  BuildContext context, {
  required String? selectedUf,
  required ValueChanged<String?> onSelected,
  String title = 'Estados brasileiros',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) {
      final mq = MediaQuery.sizeOf(ctx);
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      final sheetH = (mq.height * 0.88).clamp(320.0, mq.height - 24);
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: sheetH,
            child: _BrazilStateSheetBody(
              title: title,
              selectedUf: selectedUf,
              onPick: (uf) {
                Navigator.of(ctx).pop();
                onSelected(uf);
              },
            ),
          ),
        ),
      );
    },
  );
}

class _BrazilStateSheetBody extends StatefulWidget {
  const _BrazilStateSheetBody({
    required this.title,
    required this.selectedUf,
    required this.onPick,
  });

  final String title;
  final String? selectedUf;
  final ValueChanged<String?> onPick;

  @override
  State<_BrazilStateSheetBody> createState() => _BrazilStateSheetBodyState();
}

class _BrazilStateSheetBodyState extends State<_BrazilStateSheetBody> {
  final _search = TextEditingController();
  final _listScroll = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() => _query = _search.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  List<BrazilState> get _filtered {
    if (_query.isEmpty) return kBrazilStates;
    return kBrazilStates.where((s) {
      final n = s.name.toLowerCase();
      final u = s.uf.toLowerCase();
      return n.contains(_query) || u.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.backgroundDeep.withValues(alpha: 0.97),
                const Color(0xFF0A1020).withValues(alpha: 0.98),
                AppColors.barBackground.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(
              color: AppColors.splashMint.withValues(alpha: 0.35),
              width: 1.2,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPink.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppColors.splashMint.withValues(alpha: .12),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.splashMint.withValues(alpha: 0.9),
                        AppColors.headerGradientPink.withValues(alpha: 0.85),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.splashMint.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) =>
                            LinearGradient(
                              colors: [
                                AppColors.splashMint,
                                AppColors.headerGradientMint,
                                AppColors.accentPink.withValues(alpha: 0.95),
                              ],
                            ).createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                            ),
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Text(
                  'Busque por nome ou sigla — toque para confirmar',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.25,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  cursorColor: AppColors.splashMint,
                  decoration: InputDecoration(
                    hintText: 'Ex.: São Paulo, SP…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    prefixIcon: Icon(
                      Icons.travel_explore_rounded,
                      color: AppColors.splashMint.withValues(alpha: 0.85),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.35),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.accentPink.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.accentPink.withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.splashMint,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _listScroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = _filtered[i];
                    final isSelected =
                        widget.selectedUf != null &&
                        widget.selectedUf!.toUpperCase() == s.uf;
                    return _StateRowTile(
                      state: s,
                      selected: isSelected,
                      onTap: () => widget.onPick(s.uf),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateRowTile extends StatelessWidget {
  const _StateRowTile({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final BrazilState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.splashMint.withValues(alpha: 0.12),
        highlightColor: AppColors.accentPink.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.splashMint.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 1.6 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppColors.splashMint.withValues(alpha: 0.14),
                      AppColors.accentPink.withValues(alpha: 0.1),
                      Colors.transparent,
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.02),
                    ],
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.splashMint.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.headerGradientMint.withValues(alpha: 0.65),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.splashMint.withValues(alpha: 0.18),
                      AppColors.accentPink.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Text(
                  state.uf,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.4,
                    color: AppColors.headerGradientMint,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  state.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.splashMint.withValues(alpha: 0.95),
                  size: 22,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.22),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
