import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Estados de status usados nas telas de evento/acerto do DividiAí.
/// Ver docs/ux-roadmap-dividiai.md > Design System > Paleta.
enum AppStatus {
  aberto,
  fechado,
  pendente,
  pagamentoInformado,
  confirmado,
  quitado,
}

/// Badge de status do Design System do DividiAí: cor semântica + rótulo em
/// português, para nunca depender só de cor para indicar estado (regra de
/// acessibilidade do roteiro de UX).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label});

  final AppStatus status;

  /// Rótulo customizado; se omitido, usa o texto padrão do status.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final scheme = Theme.of(context).colorScheme;
    final (color, defaultLabel) = switch (status) {
      AppStatus.aberto => (scheme.primary, 'Aberto'),
      AppStatus.fechado => (semantic.neutral, 'Fechado'),
      AppStatus.pendente => (semantic.warning, 'Pendente'),
      AppStatus.pagamentoInformado => (semantic.warning, 'Pagamento informado'),
      AppStatus.confirmado => (semantic.positive, 'Confirmado'),
      AppStatus.quitado => (semantic.positive, 'Quitado'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label ?? defaultLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
