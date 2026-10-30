import 'package:flutter/material.dart';

import 'glass.dart';

/// Altura do campo de busca de vidro (a lista reserva esse espaço no topo).
const double glassSearchFieldHeight = 48;

/// Campo de busca no vidro do app (mesma cor/transparência dos botões da
/// barra superior): filtra enquanto digita; o "x" limpa.
class GlassSearchField extends StatefulWidget {
  const GlassSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Buscar',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    const none = InputBorder.none;
    return GlassSurface(
      child: SizedBox(
        height: glassSearchFieldHeight,
        child: Center(
          child: TextField(
            controller: _controller,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: false,
              border: none,
              enabledBorder: none,
              focusedBorder: none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _changed('');
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista com o campo de busca sempre visível no topo: a lista rola por
/// trás dele (e da barra superior). A lista soma [searchListTopInset] no
/// padding de cima.
class SearchOverlay extends StatelessWidget {
  const SearchOverlay({super.key, required this.search, required this.child});

  final Widget search;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: topBarInset(context) + 8,
          left: 16,
          right: 16,
          child: search,
        ),
      ],
    );
  }
}

/// Espaço no topo da lista: barra superior + campo de busca + respiro.
double searchListTopInset(BuildContext context) =>
    topBarInset(context) + 8 + glassSearchFieldHeight + 8;
