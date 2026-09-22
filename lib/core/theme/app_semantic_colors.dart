import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Cores semânticas do DividiAí: positivo (crédito/recebe), negativo
/// (débito/paga), atenção (pendente/em acerto) e neutro (fechado/quitado).
///
/// Nunca usar essas cores como cor de marca — são reservadas para indicar
/// estado financeiro ou de status, para não criar ambiguidade com o
/// `primary`/`secondary` do tema.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.positive,
    required this.negative,
    required this.warning,
    required this.neutral,
  });

  final Color positive;
  final Color negative;
  final Color warning;
  final Color neutral;

  static const light = AppSemanticColors(
    positive: AppColors.positiveLight,
    negative: AppColors.negativeLight,
    warning: AppColors.warningLight,
    neutral: AppColors.neutralLight,
  );

  static const dark = AppSemanticColors(
    positive: AppColors.positiveDark,
    negative: AppColors.negativeDark,
    warning: AppColors.warningDark,
    neutral: AppColors.neutralDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? positive,
    Color? negative,
    Color? warning,
    Color? neutral,
  }) {
    return AppSemanticColors(
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

/// Acesso curto às cores semânticas a partir de um [BuildContext]:
/// `context.semanticColors.positive`.
extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
