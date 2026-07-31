import 'package:flutter/material.dart' show TextField, InputDecoration;
import 'package:flutter/widgets.dart';

import '../nocturne.dart';
import 'pressable.dart';

/// `.field` — etiqueta pequena sobre un control.
class SyrodaField extends StatelessWidget {
  const SyrodaField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 5,
    children: <Widget>[
      Text(
        label,
        style: NocturneType.at(12, color: NocturneColors.label, height: 1.35),
      ),
      child,
    ],
  );
}

/// `.input`
class SyrodaInput extends StatefulWidget {
  const SyrodaInput({
    super.key,
    this.controller,
    this.onChanged,
    this.readOnly = false,
    this.keyboardType,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextAlign textAlign;

  @override
  State<SyrodaInput> createState() => _SyrodaInputState();
}

class _SyrodaInputState extends State<SyrodaInput> {
  final FocusNode _focus = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  /// `FocusNode.dispose()` desata el nodo y avisa a sus oyentes, y eso ocurre
  /// mientras este `State` se esta desmontando: sin la guarda, el `setState`
  /// llega tarde y rompe el desmontaje del subarbol entero. Solo se alcanza
  /// en movil, donde tocar el campo abre el teclado y el foco es real; en
  /// escritorio se puede confirmar con el raton sin haberlo enfocado nunca.
  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color border = _focus.hasFocus
        ? NocturneColors.accent
        : _hovered
        ? NocturneColors.onText(0.45)
        : NocturneColors.divider;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NocturneColors.surface,
          border: Border.all(color: border),
          borderRadius: NocturneRadius.brMd,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          textAlign: widget.textAlign,
          cursorColor: NocturneColors.accent,
          style: NocturneType.at(14, height: 1.4),
          decoration: const InputDecoration.collapsed(hintText: null),
        ),
      ),
    );
  }
}

/// `.seg` — control segmentado. La opcion elegida toma el acento y un filo
/// interior del mismo color.
class SyrodaSegmented extends StatelessWidget {
  const SyrodaSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: NocturneColors.divider),
        borderRadius: NocturneRadius.brMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < options.length; i++)
            // Ancho natural, como el `inline-flex` del CSS. Nada de repartir
            // el ancho a partes iguales: la opcion mas larga manda.
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(left: BorderSide(color: NocturneColors.divider)),
              ),
              child: Pressable(
                onTap: () => onChanged(i),
                builder: (BuildContext context, bool hovered, bool pressed) {
                  final bool active = i == selected;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: !active && hovered
                          ? NocturneColors.hoverNeutral
                          : null,
                      border: active
                          ? Border.all(color: NocturneColors.accent)
                          : null,
                    ),
                    child: Text(
                      options[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NocturneType.at(
                        13,
                        color: active
                            ? NocturneColors.accent
                            : NocturneColors.text,
                        height: 1.35,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
