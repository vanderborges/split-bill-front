import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _fieldFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: '',
  decimalDigits: 2,
);

/// Converte o texto exibido pelo [AmountField] (ex.: `1.280,50`) de volta
/// para `double` (ex.: `1280.5`). Retorna `null` se estiver vazio/inválido.
double? parseAmountFieldText(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) {
    return null;
  }
  return int.parse(digitsOnly) / 100;
}

/// Formatter que transforma qualquer entrada de dígitos num valor
/// monetário em Reais formatado ao vivo, no estilo "calculadora" (dígitos
/// entram da direita para a esquerda): digitar `1`,`9`,`6`,`4`,`0` vira
/// `1,96`, `19,64`, `196,40`.
class _CurrencyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final value = int.parse(digitsOnly) / 100;
    final formatted =
        _fieldFormat.format(value).replaceAll(' ', ' ').trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Campo de entrada de valor monetário do Design System do DividiAí:
/// teclado numérico, máscara BRL ao vivo e prefixo "R\$" fixo.
///
/// O valor numérico é lido com [parseAmountFieldText] a partir de
/// `controller.text` — o controller continua sendo a fonte da verdade, este
/// widget só cuida de exibição/máscara.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.autofocus = false,
    this.onChanged,
    this.style,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_CurrencyTextInputFormatter()],
      onChanged: onChanged,
      style: style ??
          Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
      ),
    );
  }
}
