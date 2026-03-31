import 'package:flutter/material.dart';

import '../constants/brazil_states.dart';
import '../theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

/// Select de UF (lista alfabética por nome do estado).
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
    return DropdownButtonFormField<String>(
      key: ValueKey(valueUf ?? '__none__'),
      initialValue: valueUf != null && valueUf!.isNotEmpty ? valueUf : null,
      isExpanded: true,
      dropdownColor: AppColors.barBackground,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
      ),
      items: [
        for (final s in kBrazilStates)
          DropdownMenuItem(
            value: s.uf,
            child: Text(s.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
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
