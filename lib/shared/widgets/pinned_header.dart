import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass.dart';

/// Campos fixos no topo da tela (ex.: Grupo/Evento do Extrato) logo abaixo
/// da barra superior, soltos (sem painel). Atrás deles, de lado a lado, o
/// mesmo desfoque da barra superior continua até embaixo dos campos e some
/// em degradê: a lista rola por trás. O cabeçalho mede a própria altura e
/// [builder] recebe o padding de cima que a lista precisa.
///
/// Sem [header] (ex.: sem grupos), a lista só desconta a barra superior.
class PinnedHeaderLayout extends StatefulWidget {
  const PinnedHeaderLayout({
    super.key,
    required this.header,
    required this.builder,
  });

  final Widget? header;
  final Widget Function(BuildContext context, double topPadding) builder;

  @override
  State<PinnedHeaderLayout> createState() => _PinnedHeaderLayoutState();
}

class _PinnedHeaderLayoutState extends State<PinnedHeaderLayout> {
  // Altura do degradê abaixo dos campos (o desfoque some aos poucos).
  static const double _fade = 28;

  double _headerHeight = 0;

  @override
  Widget build(BuildContext context) {
    final top = topBarInset(context) + 8;
    final header = widget.header;
    final listTop =
        header == null ? top + 8 : top + _headerHeight + AppPinnedGap.below;
    return Stack(
      children: [
        Positioned.fill(child: widget.builder(context, listTop)),
        if (header != null) ...[
          // Fundo desfocado de lado a lado, do topo da tela até embaixo dos
          // campos, sumindo em degradê.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + _headerHeight + _fade,
            child: const _PinnedBackdrop(fade: _fade),
          ),
          Positioned(
            top: top,
            left: 16,
            right: 16,
            child: _SizeReporter(
              onSize: (size) {
                if (size.height != _headerHeight) {
                  setState(() => _headerHeight = size.height);
                }
              },
              child: header,
            ),
          ),
        ],
      ],
    );
  }
}

/// Desfoque + cor do fundo da tela atrás dos campos fixos: cheio até o fim
/// dos campos e sumindo nos últimos [fade] pixels (faixas sobrepostas, como
/// o [TopEdgeBlur] da barra superior).
class _PinnedBackdrop extends StatelessWidget {
  const _PinnedBackdrop({required this.fade});

  final double fade;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        final solid = height - fade;
        Widget band(double bandHeight, double sigma) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bandHeight,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),
            );
        return Stack(
          children: [
            band(solid, 6),
            band(solid + fade * 0.5, 2.5),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      background.withValues(alpha: 0.88),
                      background.withValues(alpha: 0.82),
                      background.withValues(alpha: 0),
                    ],
                    stops: [0, height <= 0 ? 0 : solid / height, 1],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Respiro entre o painel fixo e o começo da lista.
abstract final class AppPinnedGap {
  static const double below = 12;
}

/// Avisa o tamanho do filho depois de cada layout (a altura dos campos
/// muda com o tamanho do texto do celular).
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
      BuildContext context, _RenderSizeReporter renderObject) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (_last != size) {
      _last = size;
      final reported = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
    }
  }
}
