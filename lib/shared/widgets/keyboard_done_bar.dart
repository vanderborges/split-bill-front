import 'package:flutter/material.dart';

/// Envolve um campo de texto numérico e, enquanto ele estiver focado com o
/// teclado virtual aberto, mostra uma barra com botão "OK" logo acima do
/// teclado. O teclado numérico do iOS não tem tecla de "concluir", então
/// sem isso não há como fechá-lo depois de digitar o valor.
///
/// A barra só aparece quando há teclado virtual de fato
/// (`viewInsets.bottom > 0`) — em desktop/web com teclado físico fica
/// escondida.
///
/// [toolbarBuilder] permite colocar ações extras à esquerda do "OK" (ex.:
/// os operadores da calculadora do `AmountField`); [refresh] reconstrói a
/// barra quando o estado dessas ações muda. [onDone] roda antes de fechar o
/// teclado.
class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({
    super.key,
    required this.child,
    this.toolbarBuilder,
    this.refresh,
    this.onDone,
  });

  final Widget child;
  final WidgetBuilder? toolbarBuilder;
  final Listenable? refresh;
  final VoidCallback? onDone;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_rebuildBar);
  }

  @override
  void didUpdateWidget(KeyboardDoneBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_rebuildBar);
      widget.refresh?.addListener(_rebuildBar);
    }
  }

  void _rebuildBar() => _entry?.markNeedsBuild();

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
    _entry = OverlayEntry(
      builder: (context) => _DoneBar(
        toolbarBuilder: widget.toolbarBuilder,
        onDone: widget.onDone,
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_rebuildBar);
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
  const _DoneBar({this.toolbarBuilder, this.onDone});

  final WidgetBuilder? toolbarBuilder;
  final VoidCallback? onDone;

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
      // Toques na barra contam como "dentro" do campo: sem isso, em
      // plataformas que tiram o foco ao tocar fora, apertar um operador
      // fecharia o teclado no meio da conta.
      child: TextFieldTapRegion(
        child: Material(
          color: colorScheme.surfaceContainerHighest,
          elevation: 2,
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                if (toolbarBuilder != null)
                  Expanded(child: toolbarBuilder!(context))
                else
                  const Spacer(),
                TextButton(
                  onPressed: () {
                    onDone?.call();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
