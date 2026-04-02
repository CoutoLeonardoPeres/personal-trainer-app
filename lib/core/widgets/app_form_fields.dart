import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/brazil_states.dart';
import '../theme/app_colors.dart';
import 'brazil_state_picker_sheet.dart';

/// Espaço vertical entre campos nos modais de cadastro.
const double kCadastroFieldGap = 14;

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.required = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool required;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label == null
            ? null
            : (required ? '$label *' : label),
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }
}

/// Campo de UF: abre o seletor futurista com busca (mesmo padrão em todo o app).
class BrazilStateDropdown extends StatelessWidget {
  const BrazilStateDropdown({
    super.key,
    required this.valueUf,
    required this.onChanged,
    this.label = 'Estado (UF)',
    this.requiredField = false,
  });

  final String? valueUf;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final selected = brazilStateByUf(valueUf);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          showBrazilStatePickerSheet(
            context,
            selectedUf: valueUf,
            onSelected: onChanged,
            title: label,
          );
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.splashMint.withValues(alpha: 0.12),
        highlightColor: AppColors.accentPink.withValues(alpha: 0.06),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: requiredField ? '$label *' : label,
            suffixIcon: Icon(
              Icons.map_rounded,
              color: AppColors.splashMint.withValues(alpha: 0.88),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 1),
            child: Text(
              selected?.label ?? 'Toque para selecionar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: selected != null ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: selected != null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão primário dos modais: mint, texto/ícone pretos, formato pill.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.splashMint,
      foregroundColor: Colors.black,
      disabledBackgroundColor: AppColors.splashMint.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.black54,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      shape: const StadiumBorder(),
    );
    return SizedBox(
      width: double.infinity,
      child: icon != null
          ? ElevatedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 22, color: onPressed == null ? Colors.black54 : Colors.black),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            )
          : ElevatedButton(
              style: style,
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
    );
  }
}
