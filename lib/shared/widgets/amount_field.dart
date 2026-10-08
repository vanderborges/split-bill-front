import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'keyboard_done_bar.dart';

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
  _CurrencyTextInputFormatter({this.rawDigits});

  /// Quando retorna true, aceita só dígitos sem máscara de moeda — usado
  /// no segundo operando de × e ÷ (um multiplicador, não um valor em R$).
  final bool Function()? rawDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (rawDigits?.call() ?? false) {
      final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final value = int.parse(digitsOnly) / 100;
    final formatted = _fieldFormat.format(value).replaceAll(' ', ' ').trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Campo de entrada de valor monetário do Design System do DividiAí:
/// teclado numérico, máscara BRL ao vivo e prefixo "R\$" fixo.
///
/// Com o teclado virtual aberto, a barra acima dele traz uma calculadora
/// simples (+ − × ÷ =): o operador guarda o valor atual e limpa o campo
/// pro próximo número. Em × e ÷ o segundo número é um multiplicador
/// inteiro (sem máscara de R\$). A conta pendente é resolvida no "=", no
/// "OK" ou quando o campo perde o foco — assim `controller.text` sempre
/// termina com um valor em R\$ válido.
///
/// O valor numérico é lido com [parseAmountFieldText] a partir de
/// `controller.text` — o controller continua sendo a fonte da verdade, este
/// widget só cuida de exibição/máscara.
class AmountField extends StatefulWidget {
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
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  final _calculatorState = ValueNotifier<int>(0);
  final _focusNode = FocusNode();
  double? _pendingValue;
  String? _pendingOperator;

  bool get _multiplierMode =>
      _pendingOperator == '×' || _pendingOperator == '÷';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _resolve();
      }
    });
  }

  @override
  void dispose() {
    _calculatorState.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double? _currentOperand() {
    final text = widget.controller.text;
    if (_multiplierMode) {
      return double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    return parseAmountFieldText(text);
  }

  void _notify() {
    _calculatorState.value++;
    if (mounted) {
      setState(() {});
    }
  }

  void _setAmount(double value) {
    final cents = (value * 100).round().clamp(0, 1 << 52);
    final text = cents == 0
        ? ''
        : _fieldFormat.format(cents / 100).replaceAll(' ', ' ').trim();
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
  }

  /// Aplica a operação pendente com o número que está no campo.
  void _resolve() {
    final pending = _pendingValue;
    final operator = _pendingOperator;
    if (pending == null || operator == null) {
      return;
    }
    final operand = _currentOperand();
    _pendingValue = null;
    _pendingOperator = null;
    final double result;
    if (operand == null) {
      result = pending;
    } else {
      result = switch (operator) {
        '+' => pending + operand,
        '−' => pending - operand,
        '×' => pending * operand,
        '÷' => operand == 0 ? pending : pending / operand,
        _ => pending,
      };
    }
    _setAmount(result < 0 ? 0 : result);
    _notify();
  }

  void _onOperator(String operator) {
    if (_pendingOperator != null && widget.controller.text.isEmpty) {
      // Trocou de operador sem digitar o segundo número.
      _pendingOperator = operator;
      _notify();
      return;
    }
    _resolve();
    _pendingValue = parseAmountFieldText(widget.controller.text) ?? 0;
    _pendingOperator = operator;
    widget.controller.clear();
    _notify();
  }

  String? get _pendingLabel {
    final pending = _pendingValue;
    final operator = _pendingOperator;
    if (pending == null || operator == null) {
      return null;
    }
    return 'R\$ ${_fieldFormat.format(pending).replaceAll(' ', ' ').trim()} $operator';
  }

  Widget _buildToolbar(BuildContext context) {
    final label = _pendingLabel;
    Widget key(String symbol, VoidCallback onPressed) => SizedBox(
          width: 44,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onPressed,
            child: Text(symbol,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
        );
    return Row(
      children: [
        for (final operator in const ['+', '−', '×', '÷'])
          key(operator, () => _onOperator(operator)),
        key('=', _resolve),
        if (label != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingLabel = _pendingLabel;
    return KeyboardDoneBar(
      toolbarBuilder: _buildToolbar,
      refresh: _calculatorState,
      onDone: _resolve,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        // Folga extra embaixo pra barra do "OK" não cobrir o campo.
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          _CurrencyTextInputFormatter(rawDigits: () => _multiplierMode),
        ],
        onChanged: widget.onChanged,
        style: widget.style ??
            Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: _multiplierMode ? '' : 'R\$ ',
          helperText: pendingLabel == null ? null : '$pendingLabel …',
        ),
      ),
    );
  }
}
