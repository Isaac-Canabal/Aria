import 'package:flutter/widgets.dart';

import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'syroda_badge.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// `.dropzone` — el destino de archivos. En movil es "toca para elegir"; en
/// escritorio, "arrastra archivos aqui".
class Dropzone extends StatelessWidget {
  const Dropzone({
    super.key,
    required this.title,
    required this.hint,
    this.icon = SyrodaIcons.send,
    this.onTap,
  }) : badgeSize = 52,
       iconSize = 22,
       gap = 10,
       titleSize = 15,
       hintSize = 12.5,
       action = null,
       stacked = false;

  /// La variante de escritorio: simbolo mas grande, las dos lineas juntas en
  /// un bloque y un boton debajo.
  const Dropzone.desktop({
    super.key,
    required this.title,
    required this.hint,
    this.icon = SyrodaIcons.send,
    this.action,
    this.onTap,
  }) : badgeSize = 60,
       iconSize = 26,
       gap = 14,
       titleSize = 16,
       hintSize = 13,
       stacked = true;

  final String title;
  final String hint;
  final SyrodaIconData icon;
  final Widget? action;
  final VoidCallback? onTap;
  final double badgeSize;
  final double iconSize;
  final double gap;
  final double titleSize;
  final double hintSize;

  /// En escritorio el titulo y la pista van pegados dentro de un bloque; en
  /// movil los separa el hueco de la columna.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final Widget titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: NocturneType.at(
        titleSize,
        weight: NocturneType.medium,
        height: 1.35,
      ),
    );
    final Widget hintText = Text(
      hint,
      textAlign: TextAlign.center,
      style: NocturneType.at(
        hintSize,
        color: NocturneColors.onText(0.6),
        height: 1.4,
      ),
    );

    return Pressable(
      onTap: onTap,
      builder: (BuildContext context, bool hovered, bool pressed) => DashedBorder(
        color: NocturneColors.divider,
        radius: NocturneRadius.lg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: pressed
                ? NocturneColors.activeNeutral
                : hovered
                ? NocturneColors.hoverNeutral
                : null,
            borderRadius: NocturneRadius.brLg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: <Widget>[
              SyrodaBadge.icon(icon, size: badgeSize, iconSize: iconSize),
              if (stacked)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: <Widget>[titleText, hintText],
                )
              else ...<Widget>[titleText, hintText],
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}
