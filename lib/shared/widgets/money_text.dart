import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_semantic_colors.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);

/// Formata um valor em Reais seguindo o padrão brasileiro (separador de
/// milhar `.`, decimal `,`), ex.: `1280.5` -> `R\$ 1.280,50`.
///
/// Centraliza a formatação que hoje está duplicada (e sem separador de
/// milhar) em `_formatMoney` em várias telas.
String formatCurrencyBRL(num value, {bool showSign = false}) {
  // intl inserts a non-breaking space between the symbol and the number;
  // normalize to a regular space so this matches plain-text usage
  // elsewhere (WhatsApp share text, snackbars, etc.).
  final formatted =
      _currencyFormat.format(value.abs()).replaceAll(' ', ' ');
  if (!showSign || value == 0) {
    return value < 0 ? '-$formatted' : formatted;
  }
  return value > 0 ? '+$formatted' : '-$formatted';
}

/// Texto de valor monetário do Design System do DividiAí: algarismos
/// tabulares (não "dançam" ao trocar de dígito) e peso semibold por padrão.
///
/// Use `colorBySign: true` para tingir automaticamente com a cor semântica
/// de positivo/negativo/neutro (ex.: saldo do usuário), em vez de escolher a
/// cor manualmente na tela.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.style,
    this.colorBySign = false,
    this.showSign = false,
  });

  final num value;
  final TextStyle? style;
  final bool colorBySign;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    final resolvedColor = colorBySign ? _signColor(context) : baseStyle?.color;

    return Text(
      formatCurrencyBRL(value, showSign: showSign),
      style: baseStyle?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: resolvedColor,
      ),
    );
  }

  Color _signColor(BuildContext context) {
    final semantic = context.semanticColors;
    if (value > 0) {
      return semantic.positive;
    }
    if (value < 0) {
      return semantic.negative;
    }
    return semantic.neutral;
  }
}
