import 'package:flutter/services.dart';

/// Mantém só dígitos (útil antes de persistir CPF/CEP).
String brDigitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Exibe CPF mascarado a partir de até 11 dígitos.
String brFormatCpfDisplay(String raw) {
  final d = brDigitsOnly(raw);
  if (d.isEmpty) return '';
  final b = StringBuffer();
  for (var i = 0; i < d.length && i < 11; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// Exibe CEP mascarado (00000-000).
String brFormatCepDisplay(String raw) {
  final d = brDigitsOnly(raw);
  if (d.isEmpty) return '';
  final b = StringBuffer();
  for (var i = 0; i < d.length && i < 8; i++) {
    if (i == 5) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// Máscara dinâmica CPF durante digitação.
class BrCpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = brDigitsOnly(newValue.text);
    if (d.length > 11) {
      return oldValue;
    }
    final masked = brFormatCpfDisplay(d);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

/// Máscara dinâmica CEP durante digitação.
class BrCepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = brDigitsOnly(newValue.text);
    if (d.length > 8) {
      return oldValue;
    }
    final masked = brFormatCepDisplay(d);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}
