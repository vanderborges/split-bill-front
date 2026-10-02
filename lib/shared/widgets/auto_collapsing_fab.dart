import 'dart:async';

import 'package:flutter/material.dart';

/// Botão de ação flutuante que nasce expandido mostrando um rótulo (ex.:
/// "Nova despesa") e, depois de alguns segundos, anima até virar só o
/// ícone "+" — um aceno rápido do que o botão faz ao entrar na tela, sem
/// ficar ocupando espaço depois. Clicável em ambos os estados, e tocar
/// nele a qualquer momento cancela o timer e já colapsa na hora.
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

class _AutoCollapsingFabState extends State<AutoCollapsingFab> {
  var _expanded = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.collapseAfter, _collapse);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _collapse() {
    _timer?.cancel();
    if (mounted && _expanded) {
      setState(() => _expanded = false);
    }
  }

  void _handlePressed() {
    _collapse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _expanded
          ? FloatingActionButton.extended(
              key: const ValueKey('expanded'),
              onPressed: _handlePressed,
              icon: Icon(widget.icon),
              label: Text(widget.label),
            )
          : FloatingActionButton(
              key: const ValueKey('collapsed'),
              onPressed: _handlePressed,
              child: Icon(widget.icon),
            ),
    );
  }
}
