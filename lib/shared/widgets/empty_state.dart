import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Estado vazio do Design System do DividiAí: ícone + mensagem + CTA
/// opcional, para nunca deixar uma lista vazia sem orientar o próximo
/// passo (regra da Fase 12 do roteiro de UX).
///
/// Dentro de um [AppScaffold] a mensagem fica no centro da área visível da
/// tela (entre a barra de cima e o menu), no mesmo ponto em todas as
/// telas, mesmo com filtros acima dela. [centerOnScreen] false = fica no
/// lugar onde foi colocada (mensagem dentro de uma seção, não da tela).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.centerOnScreen = true,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centerOnScreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurface.withValues(alpha: 0.35)),
          const SizedBox(height: AppSpacing.md),
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
    final body = centerOnScreen ? ScreenBodyScope.maybeOf(context) : null;
    return Center(
      child:
          body == null ? content : _CenterOnScreen(body: body, child: content),
    );
  }
}

/// Marca a área do corpo da tela (posto pelo AppScaffold) pra o
/// [EmptyState] achar o centro da tela.
class ScreenBodyScope extends InheritedWidget {
  const ScreenBodyScope(
      {super.key, required this.bodyKey, required super.child});

  final GlobalKey bodyKey;

  static GlobalKey? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenBodyScope>()?.bodyKey;

  @override
  bool updateShouldNotify(ScreenBodyScope oldWidget) =>
      oldWidget.bodyKey != bodyKey;
}

/// Desloca o filho até o centro da área visível do corpo da tela. Mede
/// depois do layout (fica invisível até medir, pra não pular na tela).
class _CenterOnScreen extends StatefulWidget {
  const _CenterOnScreen({required this.body, required this.child});

  final GlobalKey body;
  final Widget child;

  @override
  State<_CenterOnScreen> createState() => _CenterOnScreenState();
}

class _CenterOnScreenState extends State<_CenterOnScreen> {
  final _anchor = GlobalKey();
  Offset _shift = Offset.zero;
  bool _measured = false;

  void _measure() {
    if (!mounted) {
      return;
    }
    final bodyBox = widget.body.currentContext?.findRenderObject();
    final ownBox = _anchor.currentContext?.findRenderObject();
    if (bodyBox is! RenderBox ||
        ownBox is! RenderBox ||
        !bodyBox.hasSize ||
        !ownBox.hasSize) {
      if (!_measured) {
        setState(() => _measured = true);
      }
      return;
    }
    // Área visível: o corpo menos o que fica atrás do menu de baixo.
    final bottomInset =
        MediaQuery.paddingOf(widget.body.currentContext!).bottom;
    final bodyTop = bodyBox.localToGlobal(Offset.zero);
    final visibleCenterY = bodyTop.dy + (bodyBox.size.height - bottomInset) / 2;
    // A posição medida já inclui o deslocamento atual.
    final ownCenter = ownBox.localToGlobal(ownBox.size.center(Offset.zero));
    final shift = _shift + Offset(0, visibleCenterY - ownCenter.dy);
    if (!_measured || (shift - _shift).distance > 0.5) {
      setState(() {
        _shift = shift;
        _measured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Opacity(
      opacity: _measured ? 1 : 0,
      child: Transform.translate(
        offset: _shift,
        child: KeyedSubtree(key: _anchor, child: widget.child),
      ),
    );
  }
}
