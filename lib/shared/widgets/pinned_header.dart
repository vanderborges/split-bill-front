import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass.dart';

/// Campos fixos no topo da tela (ex.: Grupo/Evento do Extrato) num painel
/// de vidro logo abaixo da barra superior: a lista rola por trás dele. O
/// painel mede a própria altura e [builder] recebe o padding de cima que a
/// lista precisa pra começar abaixo dele.
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
        if (header != null)
          Positioned(
            top: top,
            left: 12,
            right: 12,
            child: _SizeReporter(
              onSize: (size) {
                if (size.height != _headerHeight) {
                  setState(() => _headerHeight = size.height);
                }
              },
              child: GlassSurface(
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                padding: const EdgeInsets.all(10),
                child: header,
              ),
            ),
          ),
      ],
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
