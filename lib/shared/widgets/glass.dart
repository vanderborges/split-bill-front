import 'dart:ui';

import 'package:flutter/material.dart';

/// Superfície "liquid glass" (estilo WhatsApp/iOS 26): fundo translúcido
/// com desfoque do que está atrás, borda clara fina e sombra suave.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // Leve brilho de cima pra baixo, como vidro.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: dark ? 0.42 : 0.55),
                  scheme.surface.withValues(alpha: dark ? 0.30 : 0.40),
                ],
              ),
              border: Border.all(
                color: (dark ? Colors.white : Colors.white)
                    .withValues(alpha: dark ? 0.14 : 0.70),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Listas de seleção (menu aberto dos dropdowns) no estilo vidro: fundo
/// translúcido e cantos bem arredondados. O menu do dropdown não aceita
/// desfoque do que está atrás, então a transparência é leve pra o texto
/// continuar legível.
const BorderRadius glassMenuRadius = BorderRadius.all(Radius.circular(24));

Color glassMenuColor(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final base = dark
      ? theme.colorScheme.surfaceContainerHigh
      : theme.colorScheme.surfaceContainerLowest;
  return base.withValues(alpha: dark ? 0.90 : 0.86);
}

/// Espaço extra no fim das listas pra o último item não ficar escondido
/// atrás da pílula do menu inferior (o conteúdo rola por trás dela).
///
/// As telas chamam isso com o context da PÁGINA, que fica acima do
/// Scaffold: ali o MediaQuery só tem a margem do aparelho, sem a pílula —
/// o fim da lista ficava escondido atrás do menu. Por isso, fora do
/// Scaffold, soma a altura da [GlassNavBar] calculada pelos mesmos
/// tamanhos que ela usa. Dentro do Scaffold (extendBody) o padding já
/// inclui a barra.
double bottomBarInset(BuildContext context) {
  final devicePadding = MediaQuery.paddingOf(context).bottom;
  if (MediaQuery.sizeOf(context).width >= 600 ||
      Scaffold.maybeOf(context) != null) {
    return devicePadding;
  }
  final labelStyle = Theme.of(context).textTheme.labelSmall;
  final labelHeight =
      MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 11) *
          (labelStyle?.height ?? 1.45);
  // SafeArea (mínimo 8) + Padding 4+4 + borda 1+1 + padding 5+5 +
  // botão (6+6 + ícone 24 + 2 + rótulo) + folga de 8.
  return (devicePadding < 8 ? 8 : devicePadding) +
      8 +
      2 +
      10 +
      12 +
      24 +
      2 +
      labelHeight +
      8;
}

/// Item da barra de navegação em pílula.
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra de navegação inferior flutuante, numa pílula de vidro; o item
/// selecionado ganha uma pílula interna destacada (padrão do WhatsApp).
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: GlassSurface(
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _GlassNavButton(
                    item: items[index],
                    selected: index == selectedIndex,
                    color: scheme.primary,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavButton extends StatelessWidget {
  const _GlassNavButton({
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? color : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? color.withValues(alpha: 0.14) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.selectedIcon : item.icon,
                  color: foreground, size: 24),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra superior "liquid glass": título à esquerda e as ações agrupadas
/// numa pílula de vidro à direita (como no WhatsApp).
PreferredSizeWidget glassAppBar(
  BuildContext context, {
  required String title,
  required List<Widget> actions,
  bool showDrawerButton = false,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: showDrawerButton,
    titleSpacing: showDrawerButton ? 0 : 16,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
    actions: [
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GlassSurface(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
    ],
  );
}
