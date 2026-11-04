import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/brazil_states.dart';
import '../theme/app_colors.dart';
import 'brazil_state_picker_sheet.dart';

/// Espaço vertical entre campos nos modais de cadastro.
const double kCadastroFieldGap = 14;

/// Cartão de campo: borda azul e preenchimento azul bem levemente translúcido.
InputDecoration cadastroFieldInputDecoration({
  String? labelText,
  bool requiredField = false,
  String? hintText,
  Widget? suffixIcon,
}) {
  final blue = AppColors.cadastroCardBorder;
  final r = BorderRadius.circular(14);
  final edge = BorderSide(color: blue.withValues(alpha: 0.44));
  return InputDecoration(
    labelText: labelText == null
        ? null
        : (requiredField ? '$labelText *' : labelText),
    hintText: hintText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: blue.withValues(alpha: 0.048),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: r, borderSide: edge),
    enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: edge),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: blue.withValues(alpha: 0.78), width: 1.1),
    ),
    labelStyle: TextStyle(
      color: AppColors.splashMint.withValues(alpha: 0.82),
      fontSize: 14,
    ),
    floatingLabelStyle: TextStyle(
      color: blue.withValues(alpha: 0.88),
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
    ),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
  );
}

/// Campo de busca nos modais de cadastro: preenchimento e borda mais visíveis que [cadastroFieldInputDecoration].
InputDecoration cadastroSearchFieldInputDecoration({
  required String labelText,
  String? hintText,
  Widget? suffixIcon,
}) {
  final blue = AppColors.cadastroCardBorder;
  final r = BorderRadius.circular(14);
  final borderColor = blue.withValues(alpha: 0.72);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF141C2C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: borderColor, width: 1.35),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: borderColor, width: 1.35),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(
        color: AppColors.splashMint.withValues(alpha: 0.9),
        width: 1.4,
      ),
    ),
    labelStyle: TextStyle(
      color: AppColors.registrySectionBlueLight.withValues(alpha: 0.95),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: TextStyle(
      color: blue.withValues(alpha: 0.95),
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
  );
}

class AppCadastroSearchField extends StatelessWidget {
  const AppCadastroSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      cursorColor: AppColors.splashMint,
      onChanged: onChanged,
      decoration: cadastroSearchFieldInputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.splashMint.withValues(alpha: 0.88),
          size: 22,
        ),
      ),
    );
  }
}

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
    this.onChanged,
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
  final ValueChanged<String>? onChanged;
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
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: cadastroFieldInputDecoration(
        labelText: label,
        requiredField: required,
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
          decoration: cadastroFieldInputDecoration(
            labelText: label,
            requiredField: requiredField,
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
                color: selected != null
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontWeight: selected != null
                    ? FontWeight.w500
                    : FontWeight.w400,
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
              icon: Icon(
                icon,
                size: 22,
                color: onPressed == null ? Colors.black54 : Colors.black,
              ),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            )
          : ElevatedButton(
              style: style,
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }
}
