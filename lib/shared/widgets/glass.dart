import 'dart:ui';

import 'package:flutter/material.dart';

/// Superfície "liquid glass" (iOS 26): fundo translúcido com desfoque do
/// que está atrás, brilho de luz na borda (forte em cima à esquerda,
/// fraco embaixo à direita), reflexo suave no topo e sombra leve.
///
/// [tint]: vidro colorido (ex.: botão "+" verde) em vez do vidro neutro.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.padding,
    this.opacity = 1,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Multiplica a opacidade do fundo: < 1 deixa o vidro mais transparente
  /// (barra de menus).
  final double opacity;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = this.tint;
    final colors = tint == null
        ? [
            scheme.surface.withValues(alpha: (dark ? 0.42 : 0.55) * opacity),
            scheme.surface.withValues(alpha: (dark ? 0.30 : 0.40) * opacity),
          ]
        : [
            tint.withValues(alpha: 0.82 * opacity),
            tint.withValues(alpha: 0.66 * opacity),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: (tint ?? Colors.black)
                .withValues(alpha: tint != null ? 0.30 : (dark ? 0.35 : 0.10)),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CustomPaint(
            foregroundPainter: LiquidHighlightPainter(
              borderRadius: borderRadius,
              strength: dark ? 0.55 : 1,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Brilho do "liquid glass" por cima da superfície: a borda reflete luz
/// vinda de cima à esquerda (clara ali, quase sumindo do outro lado) e o
/// topo tem um reflexo suave, como a curvatura de um vidro.
class LiquidHighlightPainter extends CustomPainter {
  const LiquidHighlightPainter({
    required this.borderRadius,
    this.strength = 1,
  });

  final BorderRadius borderRadius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.6);

    // Reflexo do topo: faixa clara que some até o meio.
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.22 * strength),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, sheen);

    // Borda com luz: forte em cima/esquerda, fraca embaixo/direita.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.95 * strength),
          Colors.white.withValues(alpha: 0.25 * strength),
          Colors.white.withValues(alpha: 0.55 * strength),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, rim);
  }

  @override
  bool shouldRepaint(LiquidHighlightPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strength != strength;
}

/// Listas de seleção (menu aberto dos dropdowns) no estilo vidro: fundo
/// translúcido e cantos bem arredondados. O menu do dropdown não aceita
/// desfoque do que está atrás, então a transparência é leve pra o texto
/// continuar legível.
const BorderRadius glassMenuRadius = BorderRadius.all(Radius.circular(24));

/// Altura máxima da lista aberta dos dropdowns: 6 itens e meio (o meio
/// item cortado mostra que dá pra rolar) + o respiro de 8 do menu.
const double glassMenuMaxHeight = 6.5 * kMinInteractiveDimension + 8;

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

/// Azul do item selecionado na barra de menus (padrão do app Trello).
Color navSelectedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF579DFF)
        : const Color(0xFF0C66E4);

/// Barra de navegação inferior flutuante, numa pílula de vidro. Como no
/// Trello, o item selecionado fica azul e a pílula de destaque desliza de
/// um item pro outro ao trocar de aba. Cada tela monta a própria barra
/// (não há shell), então a posição anterior fica em [_lastPosition] e a
/// barra nova anima a partir dela.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
  });

  final List<GlassNavItem> items;

  /// Rolando a tela pra baixo: some o nome embaixo dos ícones e a barra
  /// fica um pouco menor (iOS 26); rolar pra cima volta ao normal.
  final bool compact;

  /// -1 = nenhum item marcado (ex.: Perfil, Extrato geral).
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static double? _lastPosition;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  // De onde a pílula parte: a posição da barra da tela anterior. Lida no
  // initState, antes do build gravar a posição nova.
  double? _from;

  @override
  void initState() {
    super.initState();
    _from = GlassNavBar._lastPosition;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedIndex;
    final hasSelection = selected >= 0 && selected < widget.items.length;
    final target = hasSelection ? selected.toDouble() : null;
    GlassNavBar._lastPosition = target;
    // Aba nova (veio de outra ou de nenhuma): o item "infla" ao entrar,
    // como nos botões do menu do Trello no iOS.
    final inflateFrom = _from != target ? 1.0 : _navInflatedScale;
    final color = navSelectedColor(context);
    return TweenAnimationBuilder<double>(
      // 1 = normal (com nomes), 0 = compacta (só ícones).
      tween: Tween(end: widget.compact ? 0 : 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, expanded, _) => SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          // Compacta também fica um pouco mais estreita.
          padding: EdgeInsets.fromLTRB(
              16 + 24 * (1 - expanded), 4, 16 + 24 * (1 - expanded), 4),
          // Mais transparente que o vidro da barra de cima.
          child: GlassSurface(
            opacity: 0.5,
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / widget.items.length;
                return Stack(
                  children: [
                    if (target != null)
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: _from ?? target, end: target),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          builder: (context, position, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.translate(
                              key: const ValueKey('nav-pill'),
                              offset: Offset(position * itemWidth, 0),
                              child: _Inflate(
                                from: inflateFrom,
                                child: _LiquidSelectedPill(
                                    width: itemWidth, color: color),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (var index = 0;
                            index < widget.items.length;
                            index++)
                          Expanded(
                            child: _GlassNavButton(
                              item: widget.items[index],
                              selected: index == selected,
                              inflateFrom: inflateFrom,
                              expanded: expanded,
                              color: color,
                              onTap: () => widget.onSelected(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pílula do item selecionado: vidro azul (liquid glass) com o mesmo
/// brilho de borda e reflexo da barra.
class _LiquidSelectedPill extends StatelessWidget {
  const _LiquidSelectedPill({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: LiquidHighlightPainter(
            borderRadius: radius, strength: dark ? 0.5 : 0.9),
      ),
    );
  }
}

class _GlassNavButton extends StatelessWidget {
  const _GlassNavButton({
    required this.item,
    required this.selected,
    required this.inflateFrom,
    required this.expanded,
    required this.color,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final double inflateFrom;

  /// 1 = com o nome embaixo do ícone, 0 = só o ícone.
  final double expanded;
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
        // A pílula de destaque é desenhada pela barra (desliza entre os
        // itens); aqui só ícone e rótulo.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4 + 2 * expanded),
          child: _Inflate(
            from: selected ? inflateFrom : 1,
            to: selected ? _navInflatedScale : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? item.selectedIcon : item.icon,
                    color: foreground, size: 24),
                SizedBox(height: 2 * expanded),
                // O nome encolhe até sumir (barra compacta).
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: expanded,
                    child: Opacity(
                      opacity: expanded,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra superior "liquid glass": título à esquerda e as ações agrupadas
/// numa pílula de vidro à direita (como no WhatsApp).
///
/// [onBack]: seta de voltar colada à esquerda do título (como no WhatsApp).
PreferredSizeWidget glassAppBar(
  BuildContext context, {
  required String title,
  required List<Widget> actions,
  bool showDrawerButton = false,
  VoidCallback? onBack,
}) {
  final titleText = Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.w700),
  );
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: showDrawerButton,
    titleSpacing: showDrawerButton || onBack != null ? 0 : 16,
    title: onBack == null
        ? titleText
        : Row(
            children: [
              GlassBackButton(onPressed: onBack),
              const SizedBox(width: 8),
              Flexible(child: titleText),
            ],
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

/// Botão voltar dentro de uma pílula de vidro (como no iOS). Sem
/// [onPressed], volta a tela anterior da pilha (Navigator.maybePop).
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GlassSurface(
        child: SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: 'Voltar',
            padding: EdgeInsets.zero,
            onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Quanto o item selecionado da barra de menus fica maior.
const double _navInflatedScale = 1.08;

/// Cresce de [from] até [to] com um leve "pulo" (passa um pouco e volta).
class _Inflate extends StatelessWidget {
  const _Inflate({
    required this.from,
    this.to = _navInflatedScale,
    required this.child,
  });

  final double from;
  final double to;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: to),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
