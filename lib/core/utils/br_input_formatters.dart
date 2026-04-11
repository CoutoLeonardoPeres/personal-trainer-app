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

/// Fixo BR: DDD + 8 dígitos (máx. 10). Máscara `(11) 3456-7890`.
String brFormatPhoneLandlineDisplay(String raw) {
  final d = brDigitsOnly(raw);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final rest = d.substring(2);
  if (rest.isEmpty) return '($ddd) ';
  if (rest.length <= 4) return '($ddd) $rest';
  final r = rest.length > 8 ? rest.substring(0, 8) : rest;
  return '($ddd) ${r.substring(0, 4)}-${r.substring(4)}';
}

/// Celular BR: DDD + 9 dígitos (máx. 11). Máscara `(11) 98765-4321`.
String brFormatPhoneMobileDisplay(String raw) {
  final d = brDigitsOnly(raw);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final rest = d.substring(2);
  if (rest.isEmpty) return '($ddd) ';
  if (rest.length <= 5) return '($ddd) $rest';
  final r = rest.length > 9 ? rest.substring(0, 9) : rest;
  return '($ddd) ${r.substring(0, 5)}-${r.substring(5)}';
}

/// Exibe telefone BR a partir de só dígitos: 11+ como celular, caso contrário como fixo (parcial ou completo).
String brFormatPhoneDisplay(String raw) {
  final d = brDigitsOnly(raw);
  if (d.isEmpty) return '';
  if (d.length >= 11) {
    return brFormatPhoneMobileDisplay(d.substring(0, 11));
  }
  return brFormatPhoneLandlineDisplay(d);
}

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

/// Máscara telefone fixo durante digitação (até 10 dígitos).
class BrPhoneLandlineInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = brDigitsOnly(newValue.text);
    if (d.length > 10) {
      return oldValue;
    }
    final masked = brFormatPhoneLandlineDisplay(d);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

/// Máscara celular durante digitação (até 11 dígitos).
class BrPhoneMobileInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = brDigitsOnly(newValue.text);
    if (d.length > 11) {
      return oldValue;
    }
    final masked = brFormatPhoneMobileDisplay(d);
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
