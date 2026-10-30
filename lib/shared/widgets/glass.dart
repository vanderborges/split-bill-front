import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Superfície de vidro no padrão do Threads: modo dia branco translúcido
/// (~70%) com contorno cinza fino; modo noite cinza-escuro (~65%). O que
/// passa por trás continua legível, só levemente desfocado (como entre os
/// botões da barra do Threads), com brilho suave na borda e sem sombra.
///
/// [tint]: vidro colorido (ex.: botão "+" verde) em vez do vidro neutro.
/// Cinza-escuro do vidro no modo noite (barra do Threads).
const Color _darkGlass = Color(0xFF2A2A2C);

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.padding,
    this.opacity = 1,
    this.tint,
    this.blurSigma = 8,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Multiplica a opacidade do fundo: < 1 deixa o vidro mais transparente
  /// (barra de menus).
  final double opacity;
  final Color? tint;

  /// Desfoque do que está atrás: menor deixa o conteúdo mais reconhecível
  /// (barra de menus, como no iOS 26).
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = this.tint;
    final colors = tint == null
        ? [
            (dark ? _darkGlass : Colors.white)
                .withValues(alpha: (dark ? 0.68 : 0.72) * opacity),
            (dark ? _darkGlass : Colors.white)
                .withValues(alpha: (dark ? 0.62 : 0.66) * opacity),
          ]
        : [
            tint.withValues(alpha: 0.82 * opacity),
            tint.withValues(alpha: 0.66 * opacity),
          ];
    // Sem sombra (como o vidro do WhatsApp no iOS 26): o destaque vem só
    // do desfoque e do brilho da borda.
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: CustomPaint(
          foregroundPainter: LiquidHighlightPainter(
            borderRadius: borderRadius,
            strength: dark ? 0.35 : 0.6,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // Contorno fino (cinza no dia, claro e discreto à noite).
              border: tint != null
                  ? null
                  : Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.10)),
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

/// Limite antigo da lista aberta dos dropdowns (6 itens e meio). Desde
/// 30/10/2026 a lista vai até antes da barra de menus; fica só como
/// referência de tamanho nos testes.
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

/// Espaço no topo das listas que rolam por trás da barra superior
/// ([AppScaffold.scrollsBehindTopBar]): margem do aparelho + a barra. Com o
/// context da PÁGINA (acima do Scaffold) o MediaQuery não tem a barra, então
/// soma a altura dela; dentro do Scaffold (extendBodyBehindAppBar) já vem.
double topBarInset(BuildContext context) {
  final top = MediaQuery.paddingOf(context).top;
  return Scaffold.maybeOf(context) != null ? top : top + kToolbarHeight;
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

/// Cor dos ícones da barra de menus: monocromática como no Threads (preto
/// no modo dia, branco no modo noite). O selecionado se distingue pelo
/// ícone preenchido e pela pílula cinza.
Color navSelectedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

/// Barra de navegação inferior flutuante no padrão do WhatsApp no iOS 26:
/// cápsula de vidro bem transparente (o conteúdo passa desfocado por
/// trás) e o item selecionado numa pílula de vidro claro, com ícone e nome
/// em azul. Ao trocar de aba a pílula vai até o item novo com efeito mola
/// (passa um pouco e volta) e, no caminho, estica no sentido do movimento e
/// cresce um pouco, como uma gota. Dá pra arrastar o dedo pela barra: a
/// pílula acompanha e, ao soltar, abre o item mais próximo.
///
/// Cada tela monta a própria barra (não há shell), então a posição anterior
/// fica em [_lastPosition] e a barra nova anima a partir dela.
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

  /// Mola da pílula: um pouco "solta" (passa do ponto e volta).
  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 320,
    ratio: 0.68,
  );

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  // Posição da pílula em "índices" (0 = primeiro item; fracionado no meio
  // do caminho). Sem limite: a mola passa um pouco do destino.
  late final AnimationController _position =
      AnimationController.unbounded(vsync: this);
  bool _dragging = false;

  int get _itemCount => widget.items.length;

  bool get _hasSelection =>
      widget.selectedIndex >= 0 && widget.selectedIndex < _itemCount;

  @override
  void initState() {
    super.initState();
    // De onde a pílula parte: a posição da barra da tela anterior. Lida
    // aqui, antes do build gravar a posição nova.
    final from = GlassNavBar._lastPosition;
    if (_hasSelection) {
      final target = widget.selectedIndex.toDouble();
      _position.value = from ?? target;
      if (from != null && from != target) {
        _springTo(target);
      }
    }
  }

  @override
  void didUpdateWidget(GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && _hasSelection) {
      final target = widget.selectedIndex.toDouble();
      if (oldWidget.selectedIndex < 0) {
        _position.value = target;
      } else {
        _springTo(target);
      }
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _springTo(double target, {double velocity = 0}) {
    _position
        .animateWith(SpringSimulation(
            GlassNavBar.spring, _position.value, target, velocity))
        // A mola para "quase" no destino: encaixa certinho no fim.
        .whenCompleteOrCancel(() {
      if (mounted && !_dragging && !_position.isAnimating) {
        _position.value = target;
      }
    });
  }

  double _indexAt(double dx, double itemWidth) =>
      (dx / itemWidth - 0.5).clamp(0, _itemCount - 1).toDouble();

  void _dragStart(DragStartDetails details, double itemWidth) {
    _position.stop();
    setState(() => _dragging = true);
    _position.value = _indexAt(details.localPosition.dx, itemWidth);
  }

  void _dragUpdate(DragUpdateDetails details, double itemWidth) {
    _position.value = _indexAt(details.localPosition.dx, itemWidth);
  }

  void _dragEnd(DragEndDetails details, double itemWidth) {
    setState(() => _dragging = false);
    final index = _position.value.round().clamp(0, _itemCount - 1);
    _springTo(index.toDouble(),
        velocity: details.velocity.pixelsPerSecond.dx / itemWidth);
    if (index != widget.selectedIndex) {
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedIndex;
    final target = _hasSelection ? selected.toDouble() : null;
    if (target == null) {
      GlassNavBar._lastPosition = null;
    }
    final color = navSelectedColor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
          // Vidro do Threads: translúcido, o conteúdo aparece entre os botões.
          child: GlassSurface(
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _itemCount;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: target == null
                      ? null
                      : (details) => _dragStart(details, itemWidth),
                  onHorizontalDragUpdate: target == null
                      ? null
                      : (details) => _dragUpdate(details, itemWidth),
                  onHorizontalDragEnd: target == null
                      ? null
                      : (details) => _dragEnd(details, itemWidth),
                  child: AnimatedBuilder(
                    animation: _position,
                    builder: (context, _) {
                      final position = _position.value;
                      // Onde a pílula está agora: a barra da próxima tela
                      // continua dali (toque ou arraste no meio do caminho).
                      if (target != null) {
                        GlassNavBar._lastPosition = position;
                      }
                      final speed = _position.isAnimating
                          ? _position.velocity.abs()
                          : 0.0;
                      // Gota: estica com a velocidade e cresce um pouco
                      // enquanto se move (ou com o dedo em cima).
                      final stretch = (speed * 0.05).clamp(0.0, 0.45);
                      final grow = _dragging
                          ? 0.12
                          : (speed * 0.03).clamp(0.0, 0.12).toDouble();
                      final width = itemWidth * (1 + stretch);
                      final left = (position + 0.5) * itemWidth - width / 2;
                      // Item debaixo da pílula: durante o arraste, o mais
                      // perto do dedo fica marcado.
                      final active = target == null
                          ? -1
                          : _dragging
                              ? position.round()
                              : selected;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (target != null)
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  key: const ValueKey('nav-pill'),
                                  offset: Offset(left, 0),
                                  child: Transform.scale(
                                    scaleY: 1 + grow - stretch * 0.15,
                                    scaleX: 1 + grow,
                                    child: _GlassPill(
                                      width: width,
                                      dark: dark,
                                      // 0 = parada (cinza), 1 = lente.
                                      motion: _dragging
                                          ? 1
                                          : (speed * 0.2).clamp(0.0, 1.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              for (var index = 0; index < _itemCount; index++)
                                Expanded(
                                  child: _GlassNavButton(
                                    item: widget.items[index],
                                    selected: index == active,
                                    expanded: expanded,
                                    color: color,
                                    // Lente: o ícone debaixo da pílula
                                    // aumenta junto com ela.
                                    lens: (position - index).abs() < 0.5
                                        ? grow
                                        : 0,
                                    onTap: () => widget.onSelected(index),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pílula do item selecionado (padrão Threads): parada é cinza sólida -
/// cinza-claro no dia, um pouco mais escura que a barra à noite. Em
/// movimento ([motion] 1) vira uma lente de vidro clara com brilho na borda.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.width, required this.dark, this.motion = 0});

  final double width;
  final bool dark;
  final double motion;

  static const _restLight = Color(0xFFE4E4E6);
  static const _restDark = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));
    return CustomPaint(
      foregroundPainter: motion <= 0
          ? null
          : LiquidHighlightPainter(
              borderRadius: radius,
              strength: motion * (dark ? 0.6 : 1),
            ),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Color.lerp(
            dark ? _restDark : _restLight,
            dark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.70),
            motion,
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
    required this.expanded,
    required this.color,
    required this.onTap,
    this.lens = 0,
  });

  final GlassNavItem item;
  final bool selected;

  /// 1 = com o nome embaixo do ícone, 0 = só o ícone.
  final double expanded;
  final Color color;
  final VoidCallback onTap;

  /// Quanto o ícone aumenta com a pílula passando por cima (0 = normal).
  final double lens;

  @override
  Widget build(BuildContext context) {
    final foreground = color;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        // A pílula de destaque é desenhada pela barra (desliza entre os
        // itens); aqui só ícone e rótulo.
        child: Transform.scale(
          scale: 1 + lens,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4 + 2 * expanded),
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
  double? titleFontSize,
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
        ?.copyWith(fontWeight: FontWeight.w700, fontSize: titleFontSize),
  );
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    // Sem fundo: o conteúdo que rola por trás fica desfocado em degradê.
    flexibleSpace: const TopEdgeBlur(),
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

/// Fundo da barra superior no padrão do WhatsApp (iOS 26): nada de faixa
/// sólida. O conteúdo que rola por trás fica desfocado e esmaecido em
/// degradê - mais forte na borda de cima da tela, sumindo até a altura dos
/// botões. Parada no topo (nada atrás), a barra fica invisível.
///
/// Desfoque progressivo não existe pronto no Flutter: faixas sobrepostas,
/// cada uma mais curta, somam mais desfoque perto do topo.
class TopEdgeBlur extends StatelessWidget {
  const TopEdgeBlur({super.key});

  static const _bands = [1.0, 0.75, 0.5, 0.3];

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              for (final band in _bands)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: height * band,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              // Esmaece com a cor do fundo da tela (some no fim da barra).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        background.withValues(alpha: 0.85),
                        background.withValues(alpha: 0.55),
                        background.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
