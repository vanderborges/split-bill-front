import 'package:flutter/material.dart';

/// Tokens de cor base do Design System do DividiAí.
///
/// Ver docs/ux-roadmap-dividiai.md > Design System > Paleta.
/// Estes valores não devem ser usados diretamente nas telas — a tela deve
/// ler cores via `Theme.of(context).colorScheme` (marca/superfícies) ou via
/// `context.semanticColors` (positivo/negativo/atenção/neutro), definidos em
/// `app_theme.dart` e `app_semantic_colors.dart`.
class AppColors {
  const AppColors._();

  // Light
  static const Color primaryLight = Color(0xFF3B5BFA);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color secondaryLight = Color(0xFF0F9E8E);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF7F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFEEF1F6);
  static const Color outlineLight = Color(0xFFD7DCE3);
  static const Color onSurfaceLight = Color(0xFF1A1D22);
  static const Color positiveLight = Color(0xFF1E9E6B);
  static const Color negativeLight = Color(0xFFE5484D);
  static const Color warningLight = Color(0xFFD97706);
  static const Color neutralLight = Color(0xFF6B7280);

  // Dark
  static const Color primaryDark = Color(0xFF8FA5FF);
  static const Color onPrimaryDark = Color(0xFF0B1030);
  static const Color secondaryDark = Color(0xFF5FD9C9);
  static const Color onSecondaryDark = Color(0xFF04211D);
  static const Color backgroundDark = Color(0xFF0F1216);
  static const Color surfaceDark = Color(0xFF181C22);
  static const Color surfaceVariantDark = Color(0xFF232830);
  static const Color outlineDark = Color(0xFF333A44);
  static const Color onSurfaceDark = Color(0xFFE4E6EA);
  static const Color positiveDark = Color(0xFF4ADE94);
  static const Color negativeDark = Color(0xFFFF7A7F);
  static const Color warningDark = Color(0xFFFBBF57);
  static const Color neutralDark = Color(0xFF9AA3AF);
}
