import 'package:flutter/material.dart';

/// Envolve um campo de texto numérico e, enquanto ele estiver focado com o
/// teclado virtual aberto, mostra uma barra com botão "OK" logo acima do
/// teclado. O teclado numérico do iOS não tem tecla de "concluir", então
/// sem isso não há como fechá-lo depois de digitar o valor.
///
/// A barra só aparece quando há teclado virtual de fato
/// (`viewInsets.bottom > 0`) — em desktop/web com teclado físico fica
/// escondida.
class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  OverlayEntry? _entry;

  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      _show();
    } else {
      _hide();
    }
  }

  void _show() {
    if (_entry != null) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(builder: (context) => const _DoneBar());
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: widget.child,
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar();

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardHeight <= 0) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardHeight,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        elevation: 2,
        child: SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
