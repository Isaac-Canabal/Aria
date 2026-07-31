import 'package:flutter/widgets.dart';

import '../icons/aria_icon.dart';
import '../icons/aria_icons.dart';
import '../nocturne.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// `.row-icon` y sus tintes.
enum AriaRowIconStyle { accent, neutral, quiet, empty }

/// Las tres medidas de fila que usan los mockups: la normal, la comprimida
/// del historial movil (`.row-sm`) y la del carril de escritorio
/// (`.desk-rail .row`).
enum AriaRowDensity { normal, small, rail }

/// El cuadro con el simbolo que abre cada fila.
class AriaRowIcon extends StatelessWidget {
  const AriaRowIcon(
    this.icon, {
    super.key,
    this.style = AriaRowIconStyle.accent,
    this.size = 36,
    this.iconSize = 16,
  });

  final AriaIconData? icon;
  final AriaRowIconStyle style;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (style == AriaRowIconStyle.empty) {
      return SizedBox.square(
        dimension: size,
        child: DashedBorder(
          color: NocturneColors.divider,
          width: 1,
          radius: NocturneRadius.md,
          child: const SizedBox.expand(),
        ),
      );
    }

    final (Color background, Color foreground) = switch (style) {
      AriaRowIconStyle.accent => (
        NocturneColors.accent900,
        NocturneColors.accent200,
      ),
      AriaRowIconStyle.neutral => (
        NocturneColors.neutral800,
        NocturneColors.neutral300,
      ),
      AriaRowIconStyle.quiet => (
        NocturneColors.neutral800,
        NocturneColors.neutral400,
      ),
      AriaRowIconStyle.empty => throw StateError('resuelto arriba'),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: NocturneRadius.brMd,
      ),
      child: icon == null
          ? null
          : AriaIcon(icon!, size: iconSize, color: foreground),
    );
  }
}

/// `.row` — un dispositivo, un archivo o una entrada de historial: simbolo,
/// dos lineas de texto y una ranura al final.
class AriaRow extends StatelessWidget {
  const AriaRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconStyle = AriaRowIconStyle.accent,
    this.trailing,
    this.density = AriaRowDensity.normal,
    this.muted = false,
    this.onTap,
  }) : scanning = false;

  /// `.row-plain` con `.row-scan`: la fila de "Buscando mas dispositivos".
  const AriaRow.scanning(
    this.title, {
    super.key,
    this.density = AriaRowDensity.normal,
  }) : subtitle = null,
       icon = null,
       iconStyle = AriaRowIconStyle.empty,
       trailing = null,
       muted = false,
       onTap = null,
       scanning = true;

  final String title;
  final String? subtitle;
  final AriaIconData? icon;
  final AriaRowIconStyle iconStyle;
  final Widget? trailing;
  final AriaRowDensity density;

  /// `.row-muted`: la entrada de historial que fallo.
  final bool muted;

  /// `.row-plain`: sin fondo y a media opacidad.
  final bool scanning;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final _RowMetrics m = _RowMetrics.of(density);

    return Pressable(
      onTap: onTap,
      builder: (BuildContext context, bool hovered, bool pressed) {
        Widget row = Container(
          padding: m.padding,
          decoration: BoxDecoration(
            // La fila es opaca, asi que el realce se mezcla sobre la
            // superficie en vez de reemplazarla.
            color: scanning
                ? null
                : pressed
                ? Color.alphaBlend(
                    NocturneColors.activeNeutral,
                    NocturneColors.surface,
                  )
                : hovered
                ? Color.alphaBlend(
                    NocturneColors.hoverNeutral,
                    NocturneColors.surface,
                  )
                : NocturneColors.surface,
            borderRadius: NocturneRadius.brMd,
          ),
          child: Row(
            spacing: m.gap,
            children: <Widget>[
              AriaRowIcon(
                icon,
                style: iconStyle,
                size: m.iconBox,
                iconSize: m.iconGlyph,
              ),
              Expanded(
                child: scanning
                    ? Text(
                        title,
                        style: NocturneType.at(m.scan, height: 1.4),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NocturneType.at(
                              m.title,
                              weight: NocturneType.medium,
                              height: 1.35,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NocturneType.at(
                                m.subtitle,
                                color: NocturneColors.onText(0.55),
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
              ),
              ?trailing,
            ],
          ),
        );

        if (scanning) {
          row = Opacity(opacity: 0.5, child: row);
        } else if (muted) {
          row = Opacity(opacity: 0.75, child: row);
        }
        return row;
      },
    );
  }
}

/// Las medidas de cada densidad, tomadas de `css/aria.css`.
class _RowMetrics {
  const _RowMetrics({
    required this.padding,
    required this.gap,
    required this.iconBox,
    required this.iconGlyph,
    required this.title,
    required this.subtitle,
    required this.scan,
  });

  final EdgeInsets padding;
  final double gap;
  final double iconBox;
  final double iconGlyph;
  final double title;
  final double subtitle;
  final double scan;

  static _RowMetrics of(AriaRowDensity density) => switch (density) {
    AriaRowDensity.normal => const _RowMetrics(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 12,
      iconBox: 36,
      iconGlyph: 16,
      title: 14,
      subtitle: 12,
      scan: 13,
    ),
    AriaRowDensity.small => const _RowMetrics(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 12,
      iconBox: 34,
      iconGlyph: 15,
      title: 13.5,
      subtitle: 11.5,
      scan: 13,
    ),
    AriaRowDensity.rail => const _RowMetrics(
      padding: EdgeInsets.all(10),
      gap: 10,
      iconBox: 32,
      iconGlyph: 14,
      title: 13,
      subtitle: 11,
      scan: 12,
    ),
  };
}
