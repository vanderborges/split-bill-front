import 'dart:async';

import 'package:flutter/material.dart';


/// Espaço que uma lista com botão "+" precisa no fim: 56 do botão + 16 de
/// margem de cada lado. Sem isso o último item (e os botões dele) ficava
/// embaixo do "+", sem como rolar mais.
const double fabClearance = 88;

/// Botão de ação flutuante que nasce expandido mostrando um rótulo (ex.:
/// "Nova despesa") e, depois de alguns segundos, anima até virar só o
/// ícone "+" — um aceno rápido do que o botão faz ao entrar na tela, sem
/// ficar ocupando espaço depois. Clicável em ambos os estados, e tocar
/// nele a qualquer momento cancela o timer e já colapsa na hora.
///
/// É sempre o MESMO botão encolhendo (o rótulo vai sumindo enquanto a
/// largura diminui até virar o quadrado do "+"), em vez de trocar um botão
/// pelo outro com escala/fade — a troca dava um "pulo" no meio.
class AutoCollapsingFab extends StatefulWidget {
  const AutoCollapsingFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    this.collapseAfter = const Duration(seconds: 2),
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Duration collapseAfter;

  @override
  State<AutoCollapsingFab> createState() => _AutoCollapsingFabState();
}

class _AutoCollapsingFabState extends State<AutoCollapsingFab>
    with SingleTickerProviderStateMixin {
  // 1 = expandido (com rótulo), 0 = só o "+".
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  late final Animation<double> _extent = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.collapseAfter, _collapse);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _collapse() {
    _timer?.cancel();
    if (mounted && _controller.value > 0 && !_controller.isAnimating) {
      _controller.reverse();
    }
  }

  void _handlePressed() {
    _collapse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _extent,
      builder: (context, _) {
        final t = _extent.value;
        final scheme = Theme.of(context).colorScheme;
        // Com t = 0: 16 + ícone 24 + 16 = 56, o mesmo tamanho do FAB
        // normal — o fim da animação coincide com o botão "+".
        // Cor lisa (flat), a mesma do botão "Fechar evento".
        final button = Semantics(
          button: true,
          label: widget.label,
          child: Material(
            color: scheme.primary,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _handlePressed,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: 16,
                    end: 16 + 4 * t,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: scheme.onPrimary),
                      SizedBox(width: 8 * t),
                      if (t > 0)
                        ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: t,
                            child: Opacity(
                              opacity: Curves.easeIn.transform(t),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: scheme.onPrimary),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return t < 1 ? Tooltip(message: widget.label, child: button) : button;
      },
    );
  }
}
