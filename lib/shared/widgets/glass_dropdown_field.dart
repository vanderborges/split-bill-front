import 'package:flutter/material.dart';

import 'glass.dart';

/// Campo de seleção do app: a lista abre logo ABAIXO do campo tocado (o
/// dropdown padrão do Flutter abre por cima, centrado no item escolhido),
/// no vidro translúcido dos menus e com no máximo 6 itens e meio visíveis
/// (rola o resto). Mesmo jeito de usar do `DropdownButtonFormField`.
class GlassDropdownField<T> extends StatefulWidget {
  const GlassDropdownField({
    super.key,
    required this.items,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.onChanged,
    this.selectedItemBuilder,
    this.hint,
    this.isExpanded = true,
  });

  final List<DropdownMenuItem<T>> items;
  final T? initialValue;
  final InputDecoration decoration;

  /// null = campo desabilitado.
  final ValueChanged<T?>? onChanged;

  /// Como mostrar o item escolhido dentro do campo (um widget por item, na
  /// mesma ordem de [items]); sem ele, usa o próprio item.
  final DropdownButtonBuilder? selectedItemBuilder;
  final Widget? hint;

  /// Mantido por compatibilidade: o campo sempre ocupa a largura toda.
  final bool isExpanded;

  @override
  State<GlassDropdownField<T>> createState() => _GlassDropdownFieldState<T>();
}

/// Escolha feita no menu (separa "escolheu o item de valor null" de
/// "fechou sem escolher").
class _Picked<T> {
  const _Picked(this.value);
  final T? value;
}

class _GlassDropdownFieldState<T> extends State<GlassDropdownField<T>> {
  late T? _value = widget.initialValue;
  bool _open = false;

  @override
  void didUpdateWidget(GlassDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _value = widget.initialValue;
    }
  }

  int get _selectedIndex =>
      widget.items.indexWhere((item) => item.value == _value);

  bool get _enabled => widget.onChanged != null && widget.items.isNotEmpty;

  /// Altura que a lista quer: os itens (até 6 e meio) + o respiro do menu.
  double get _desiredMenuHeight {
    final full = widget.items.length * kMinInteractiveDimension + 16;
    return full < glassMenuMaxHeight ? full : glassMenuMaxHeight;
  }

  /// Espaço livre abaixo do campo até logo acima da barra de menus (ou da
  /// barra do celular) — a lista nunca passa por cima nem por trás dela.
  ({Rect field, double below, double above})? _measure(RenderBox overlay) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final field = topLeft & box.size;
    final bottomLimit = overlay.size.height - bottomBarInset(context) - 8;
    final topLimit = MediaQuery.paddingOf(context).top + 8;
    return (
      field: field,
      below: bottomLimit - (field.bottom + 4),
      above: (field.top - 4) - topLimit,
    );
  }

  Future<void> _openMenu() async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    var measured = _measure(overlay);
    if (measured == null) {
      return;
    }
    final desired = _desiredMenuHeight;
    // Pouco espaço embaixo: rola a tela pra subir o campo e caber a lista.
    if (measured.below < desired && Scrollable.maybeOf(context) != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted) {
        return;
      }
      measured = _measure(overlay) ?? measured;
    }
    final field = measured.field;
    final width = field.width;
    // Abaixo do campo; só abre pra cima se embaixo não couber e em cima
    // tiver mais espaço. A altura respeita o limite (rola dentro da lista).
    final openAbove =
        measured.below < desired && measured.above > measured.below;
    final available = openAbove ? measured.above : measured.below;
    final menuHeight = available < desired ? available : desired;
    final top = openAbove ? field.top - 4 - menuHeight : field.bottom + 4;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(field.left, top, width, 0),
      Offset.zero & overlay.size,
    );
    final selectedIndex = _selectedIndex;
    final textTheme = Theme.of(context).textTheme;
    setState(() => _open = true);
    final picked = await showMenu<_Picked<T>>(
      context: context,
      position: position,
      color: glassMenuColor(context),
      shape: const RoundedRectangleBorder(borderRadius: glassMenuRadius),
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: menuHeight < kMinInteractiveDimension
            ? kMinInteractiveDimension
            : menuHeight,
      ),
      items: [
        for (var index = 0; index < widget.items.length; index++)
          PopupMenuItem<_Picked<T>>(
            value: _Picked(widget.items[index].value),
            enabled: widget.items[index].enabled,
            height: kMinInteractiveDimension,
            child: DefaultTextStyle.merge(
              style: index == selectedIndex
                  ? textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
                  : textTheme.bodyLarge,
              child: widget.items[index].child,
            ),
          ),
      ],
    );
    if (!mounted) {
      return;
    }
    setState(() => _open = false);
    if (picked == null) {
      return;
    }
    setState(() => _value = picked.value);
    widget.onChanged?.call(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex;
    final Widget? selected = index < 0
        ? null
        : widget.selectedItemBuilder != null
            ? widget.selectedItemBuilder!(context)[index]
            : widget.items[index].child;
    final decoration = widget.decoration
        .applyDefaults(Theme.of(context).inputDecorationTheme)
        .copyWith(
          enabled: _enabled,
          suffixIcon: Icon(
            _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          ),
        );
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _enabled ? _openMenu : null,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: decoration,
          isFocused: _open,
          isEmpty: selected == null && widget.hint == null,
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: selected ?? widget.hint ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
