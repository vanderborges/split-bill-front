import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Esconde o botão "+" enquanto a pessoa rola a tela pra baixo (lendo a
/// lista) e traz de volta ao rolar pra cima — o padrão de Gmail/WhatsApp.
/// Fica sempre na árvore (mesmo sem botão) pra a tela não ser recriada
/// quando o botão aparece/some (ex.: Despesas com evento fechado).
class HideFabOnScroll extends StatefulWidget {
  const HideFabOnScroll({
    super.key,
    required this.fab,
    required this.body,
    required this.builder,
  });

  final Widget? fab;
  final Widget body;
  final Widget Function(Widget? fab, Widget body) builder;

  @override
  State<HideFabOnScroll> createState() => _HideFabOnScrollState();
}

class _HideFabOnScrollState extends State<HideFabOnScroll> {
  var _visible = true;

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final visible = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _visible,
    };
    if (visible != _visible) {
      setState(() => _visible = visible);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final fab = widget.fab;
    return widget.builder(
      fab == null
          ? null
          : IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: fab,
                ),
              ),
            ),
      NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.body,
      ),
    );
  }
}
