import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../ui/keyboard_bottom_inset.dart';
import '../../data/local/app_database.dart';
import 'app_form_fields.dart';

/// Seletor de grupo muscular em sheet (estilo futurista + confirmação com OK).
Future<String?> showFuturisticMuscleGroupPickerSheet(
  BuildContext context, {
  required List<MuscleGroupEntity> groups,
  required String? selectedId,
}) {
  if (groups.isEmpty) return Future.value(null);
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => KeyboardBottomInsetPadding(
      child: _MuscleGroupPickerSheetBody(
        groups: groups,
        selectedId: selectedId,
      ),
    ),
  );
}

class _MuscleGroupPickerSheetBody extends StatefulWidget {
  const _MuscleGroupPickerSheetBody({
    required this.groups,
    required this.selectedId,
  });

  final List<MuscleGroupEntity> groups;
  final String? selectedId;

  @override
  State<_MuscleGroupPickerSheetBody> createState() =>
      _MuscleGroupPickerSheetBodyState();
}

class _MuscleGroupPickerSheetBodyState
    extends State<_MuscleGroupPickerSheetBody> {
  final _search = TextEditingController();
  late String? _pendingId;

  @override
  void initState() {
    super.initState();
    _pendingId = widget.selectedId;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MuscleGroupEntity> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.groups;
    return widget.groups
        .where((g) => g.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final sheetH = (mq.height * 0.62).clamp(300.0, mq.height - 28);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: sheetH,
        child: ClipRRect(
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
                  color: AppColors.cadastroCardBorder.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withValues(alpha: 0.12),
                    blurRadius: 26,
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: AppColors.splashMint.withValues(alpha: 0.1),
                    blurRadius: 36,
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
                            AppColors.headerGradientPink.withValues(
                              alpha: 0.95,
                            ),
                            AppColors.cadastroCardBorder.withValues(
                              alpha: 0.85,
                            ),
                            AppColors.headerGradientMint.withValues(
                              alpha: 0.88,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.splashMint.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            gradient: RadialGradient(
                              colors: [
                                AppColors.splashMint.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: AppColors.registrySectionBlueLight,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    LinearGradient(
                                      colors: [
                                        AppColors.splashMint,
                                        AppColors.headerGradientMint,
                                        AppColors.accentPink.withValues(
                                          alpha: 0.92,
                                        ),
                                      ],
                                    ).createShader(
                                      Rect.fromLTWH(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    ),
                                child: const Text(
                                  'Grupo muscular',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.35,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Escolha um grupo e confirme com OK',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  height: 1.2,
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
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: TextField(
                      controller: _search,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      cursorColor: AppColors.splashMint,
                      decoration: InputDecoration(
                        hintText: 'Filtrar por nome do grupo…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.splashMint.withValues(alpha: 0.85),
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.32),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.cadastroCardBorder.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.cadastroCardBorder.withValues(
                              alpha: 0.45,
                            ),
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final g = _filtered[i];
                        final selected = _pendingId == g.id;
                        return _MuscleGroupRowTile(
                          name: g.name,
                          selected: selected,
                          onTap: () => setState(() => _pendingId = g.id),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppPrimaryButton(
                          label: 'OK',
                          icon: Icons.check_rounded,
                          onPressed: _pendingId == null
                              ? null
                              : () => Navigator.of(context).pop(_pendingId),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MuscleGroupRowTile extends StatelessWidget {
  const _MuscleGroupRowTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.splashMint.withValues(alpha: 0.88)
                  : AppColors.cadastroCardBorder.withValues(alpha: 0.35),
              width: selected ? 1.65 : 1.1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppColors.splashMint.withValues(alpha: 0.16),
                      AppColors.registrySectionBlueLight.withValues(
                        alpha: 0.08,
                      ),
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
                      color: AppColors.splashMint.withValues(alpha: 0.2),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(
                Icons.layers_rounded,
                size: 22,
                color: selected
                    ? AppColors.splashMint.withValues(alpha: 0.95)
                    : AppColors.registrySectionBlueLight.withValues(
                        alpha: 0.65,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.radio_button_checked_rounded,
                  color: AppColors.splashMint.withValues(alpha: 0.95),
                  size: 24,
                )
              else
                Icon(
                  Icons.radio_button_off_rounded,
                  color: Colors.white.withValues(alpha: 0.22),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo que abre [showFuturisticMuscleGroupPickerSheet] (substitui dropdown).
class MuscleGroupPickerField extends StatelessWidget {
  const MuscleGroupPickerField({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.onPick,
  });

  final List<MuscleGroupEntity> groups;
  final String? selectedId;
  final ValueChanged<String> onPick;

  String? _labelFor(String? id) {
    if (id == null) return null;
    for (final g in groups) {
      if (g.id == id) return g.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = _labelFor(selectedId);
    final blue = AppColors.cadastroCardBorder;
    final r = BorderRadius.circular(14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Grupo muscular *',
          style: TextStyle(
            color: AppColors.splashMint.withValues(alpha: 0.82),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: groups.isEmpty
                ? null
                : () async {
                    final id = await showFuturisticMuscleGroupPickerSheet(
                      context,
                      groups: groups,
                      selectedId: selectedId,
                    );
                    if (id != null) onPick(id);
                  },
            borderRadius: r,
            splashColor: AppColors.splashMint.withValues(alpha: 0.1),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: r,
                color: blue.withValues(alpha: 0.048),
                border: Border.all(color: blue.withValues(alpha: 0.44)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      color: AppColors.registrySectionBlueLight.withValues(
                        alpha: 0.88,
                      ),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name ?? 'Toque para escolher o grupo…',
                        style: TextStyle(
                          color: name != null
                              ? AppColors.textPrimary
                              : Colors.white.withValues(alpha: 0.42),
                          fontSize: 15,
                          fontWeight: name != null
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
