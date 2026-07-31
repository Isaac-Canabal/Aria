import 'package:flutter/widgets.dart';

import '../nocturne.dart';
import 'pressable.dart';

/// `.setting-list` — apila ajustes y pinta la linea que los separa. La
/// ultima no lleva.
class SettingList extends StatelessWidget {
  const SettingList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < children.length; i++)
        DecoratedBox(
          decoration: BoxDecoration(
            border: i == children.length - 1
                ? null
                : Border(
                    bottom: BorderSide(color: NocturneColors.divider),
                  ),
          ),
          child: children[i],
        ),
    ],
  );
}

/// `.setting` — etiqueta a la izquierda, valor o control a la derecha.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.label,
    this.hint,
    this.value,
    this.trailing,
    this.showChevron = false,
    this.wide = false,
    this.onTap,
  });

  final String label;

  /// Segunda linea, solo en la variante ancha de escritorio.
  final String? hint;

  /// `.setting-value`: el valor en texto, a la derecha.
  final String? value;

  /// Un control en lugar del valor: interruptor, etiqueta, boton.
  final Widget? trailing;

  /// El galon `›` que anuncia que el ajuste abre otra pantalla.
  final bool showChevron;

  /// `.setting-wide`: mas aire vertical y sin sangria lateral.
  final bool wide;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    builder: (BuildContext context, bool hovered, bool pressed) => Container(
      color: hovered ? NocturneColors.hoverNeutral : null,
      padding: wide
          ? const EdgeInsets.symmetric(vertical: 10)
          : const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        spacing: 16,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: <Widget>[
                Text(label, style: NocturneType.at(14, height: 1.35)),
                if (hint != null)
                  Text(
                    hint!,
                    style: NocturneType.at(
                      12,
                      color: NocturneColors.onText(0.55),
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: NocturneType.at(
                13,
                color: NocturneColors.onText(0.55),
                height: 1.35,
              ),
            ),
          ?trailing,
          if (showChevron)
            Text(
              '›',
              style: NocturneType.at(
                15,
                color: NocturneColors.onText(0.4),
                height: 1.2,
              ),
            ),
        ],
      ),
    ),
  );
}
