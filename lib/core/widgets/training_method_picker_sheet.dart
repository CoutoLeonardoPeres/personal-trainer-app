import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../theme/app_colors.dart';
import '../ui/keyboard_bottom_inset.dart';
import 'app_form_fields.dart';

/// Resultado ao confirmar em [showFuturisticTrainingMethodPickerSheet].
/// [methodId] `null` significa "Nenhum". O future devolve `null` se o sheet foi
/// fechado sem OK (X, arrastar, barrier).
class TrainingMethodPickerChoice {
  const TrainingMethodPickerChoice({required this.methodId});

  final String? methodId;
}

/// Bottom sheet futurista para escolher método de treino (ou nenhum).
Future<TrainingMethodPickerChoice?> showFuturisticTrainingMethodPickerSheet(
  BuildContext context, {
  required List<TrainingMethodEntity> methods,
  required String? selectedId,
  String? orphanId,
}) {
  return showModalBottomSheet<TrainingMethodPickerChoice?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => KeyboardBottomInsetPadding(
      child: _TrainingMethodPickerSheetBody(
        methods: methods,
        selectedId: selectedId,
        orphanId: orphanId,
      ),
    ),
  );
}

class _TrainingMethodPickerSheetBody extends StatefulWidget {
  const _TrainingMethodPickerSheetBody({
    required this.methods,
    required this.selectedId,
    this.orphanId,
  });

  final List<TrainingMethodEntity> methods;
  final String? selectedId;
  final String? orphanId;

  @override
  State<_TrainingMethodPickerSheetBody> createState() =>
      _TrainingMethodPickerSheetBodyState();
}

class _TrainingMethodPickerSheetBodyState
    extends State<_TrainingMethodPickerSheetBody> {
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

  bool get _hasOrphan =>
      widget.orphanId != null &&
      !widget.methods.any((m) => m.id == widget.orphanId);

  List<TrainingMethodEntity> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.methods;
    return widget.methods
        .where(
          (m) =>
              m.method.toLowerCase().contains(q) ||
              m.description.toLowerCase().contains(q),
        )
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
                    color: AppColors.accentPink.withValues(alpha: 0.1),
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
                              color: AppColors.accentPink.withValues(
                                alpha: 0.42,
                              ),
                            ),
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accentPink.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.auto_graph_rounded,
                              color: AppColors.headerGradientMint,
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
                                  'Método de treino',
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
                                'Toque para selecionar ou confirme com OK',
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
                        hintText: 'Filtrar por nome ou descrição…',
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
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      children: [
                        _TrainingMethodNoneTile(
                          selected: _pendingId == null,
                          onTap: () => setState(() => _pendingId = null),
                        ),
                        if (_hasOrphan) ...[
                          const SizedBox(height: 8),
                          _TrainingMethodOrphanTile(
                            selected: _pendingId == widget.orphanId,
                            onTap: () =>
                                setState(() => _pendingId = widget.orphanId),
                          ),
                        ],
                        ..._filtered.expand(
                          (m) => [
                            const SizedBox(height: 8),
                            _TrainingMethodRowTile(
                              title: m.method,
                              subtitle: m.description,
                              selected: _pendingId == m.id,
                              onTap: () => setState(() => _pendingId = m.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: AppPrimaryButton(
                      label: 'OK',
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(TrainingMethodPickerChoice(methodId: _pendingId)),
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

class _TrainingMethodNoneTile extends StatelessWidget {
  const _TrainingMethodNoneTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TrainingMethodTileShell(
      selected: selected,
      onTap: onTap,
      leadingIcon: Icons.block_rounded,
      title: 'Nenhum',
      subtitle: 'Sem método associado a esta prescrição',
    );
  }
}

class _TrainingMethodOrphanTile extends StatelessWidget {
  const _TrainingMethodOrphanTile({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TrainingMethodTileShell(
      selected: selected,
      onTap: onTap,
      leadingIcon: Icons.link_off_rounded,
      title: 'Método (não encontrado no cadastro)',
      subtitle: 'Referência antiga — escolha outro método ou Nenhum',
      dangerAccent: true,
    );
  }
}

class _TrainingMethodRowTile extends StatelessWidget {
  const _TrainingMethodRowTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TrainingMethodTileShell(
      selected: selected,
      onTap: onTap,
      leadingIcon: Icons.tune_rounded,
      title: title,
      subtitle: subtitle,
    );
  }
}

class _TrainingMethodTileShell extends StatelessWidget {
  const _TrainingMethodTileShell({
    required this.selected,
    required this.onTap,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.dangerAccent = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final bool dangerAccent;

  @override
  Widget build(BuildContext context) {
    final accent = dangerAccent ? AppColors.danger : AppColors.splashMint;
    final secondary = dangerAccent
        ? AppColors.danger.withValues(alpha: 0.75)
        : AppColors.registrySectionBlueLight.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: AppColors.accentPink.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.88)
                  : AppColors.cadastroCardBorder.withValues(alpha: 0.35),
              width: selected ? 1.65 : 1.1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      accent.withValues(alpha: 0.14),
                      AppColors.registrySectionBlueLight.withValues(
                        alpha: 0.06,
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
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                leadingIcon,
                size: 22,
                color: selected ? accent.withValues(alpha: 0.95) : secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Colors.white.withValues(
                            alpha: selected ? 0.52 : 0.38,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? accent.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.22),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo que abre [showFuturisticTrainingMethodPickerSheet] (substitui dropdown).
class TrainingMethodPickerField extends StatelessWidget {
  const TrainingMethodPickerField({
    super.key,
    required this.methods,
    required this.selectedId,
    required this.onPick,
  });

  final List<TrainingMethodEntity> methods;
  final String? selectedId;
  final ValueChanged<String?> onPick;

  String? _titleFor(String? id) {
    if (id == null) return null;
    for (final m in methods) {
      if (m.id == id) return m.method;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final known = {for (final m in methods) m.id};
    final orphan = selectedId != null && !known.contains(selectedId);
    final title = _titleFor(selectedId);
    final blue = AppColors.cadastroCardBorder;
    final r = BorderRadius.circular(14);

    TrainingMethodEntity? selectedMethod;
    if (selectedId != null) {
      for (final m in methods) {
        if (m.id == selectedId) {
          selectedMethod = m;
          break;
        }
      }
    }

    String display;
    if (selectedId == null) {
      display = 'Nenhum';
    } else if (orphan) {
      display = 'Método (não encontrado no cadastro)';
    } else {
      display = title ?? 'Toque para escolher…';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Método de treino',
          style: TextStyle(
            color: AppColors.accentGreen.withValues(alpha: 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final choice = await showFuturisticTrainingMethodPickerSheet(
                context,
                methods: methods,
                selectedId: selectedId,
                orphanId: orphan ? selectedId : null,
              );
              if (choice == null) return;
              onPick(choice.methodId);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      color: AppColors.headerGradientMint.withValues(
                        alpha: 0.88,
                      ),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            style: TextStyle(
                              color: selectedId == null
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (selectedMethod != null &&
                              selectedMethod.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                selectedMethod.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                              ),
                            ),
                        ],
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
