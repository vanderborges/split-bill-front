import 'package:flutter/services.dart';

/// Máscara de telefone brasileiro enquanto digita: aceita só números (até
/// 11, DDD + celular) e formata como "(11) 98765-4321" ou, com 10
/// dígitos, "(11) 3456-7890".
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  static String format(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    if (digits.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('(');
    buffer.write(digits.substring(0, digits.length.clamp(0, 2)));
    if (digits.length <= 2) {
      return buffer.toString();
    }
    buffer.write(') ');
    final rest = digits.substring(2);
    // Celular (9 dígitos) quebra depois do 5º; fixo, depois do 4º.
    final split = rest.length > 8 ? 5 : 4;
    if (rest.length <= split) {
      buffer.write(rest);
    } else {
      buffer
        ..write(rest.substring(0, split))
        ..write('-')
        ..write(rest.substring(split));
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Apagando o caractere da máscara (")", " " ou "-"): apaga o dígito
    // antes dele, senão a máscara voltava e o apagar travava.
    var raw = newValue.text;
    final removedMaskOnly = oldValue.text.length - raw.length == 1 &&
        raw.replaceAll(RegExp(r'\D'), '') ==
            oldValue.text.replaceAll(RegExp(r'\D'), '');
    if (removedMaskOnly) {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      raw = digits.isEmpty ? '' : digits.substring(0, digits.length - 1);
    }
    final text = format(raw);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
