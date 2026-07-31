import 'package:flutter/widgets.dart';

import '../icons/syroda_icon.dart';
import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// `.row-icon` y sus tintes.
enum SyrodaRowIconStyle { accent, neutral, quiet, empty }

/// Las tres medidas de fila que usan los mockups: la normal, la comprimida
/// del historial movil (`.row-sm`) y la del carril de escritorio
/// (`.desk-rail .row`).
enum SyrodaRowDensity { normal, small, rail }

/// El cuadro con el simbolo que abre cada fila.
class SyrodaRowIcon extends StatelessWidget {
  const SyrodaRowIcon(
    this.icon, {
    super.key,
    this.style = SyrodaRowIconStyle.accent,
    this.size = 36,
    this.iconSize = 16,
  });

  final SyrodaIconData? icon;
  final SyrodaRowIconStyle style;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (style == SyrodaRowIconStyle.empty) {
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
      SyrodaRowIconStyle.accent => (
        NocturneColors.accent900,
        NocturneColors.accent200,
      ),
      SyrodaRowIconStyle.neutral => (
        NocturneColors.neutral800,
        NocturneColors.neutral300,
      ),
      SyrodaRowIconStyle.quiet => (
        NocturneColors.neutral800,
        NocturneColors.neutral400,
      ),
      SyrodaRowIconStyle.empty => throw StateError('resuelto arriba'),
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
          : SyrodaIcon(icon!, size: iconSize, color: foreground),
    );
  }
}

/// `.row` — un dispositivo, un archivo o una entrada de historial: simbolo,
/// dos lineas de texto y una ranura al final.
class SyrodaRow extends StatelessWidget {
  const SyrodaRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconStyle = SyrodaRowIconStyle.accent,
    this.trailing,
    this.density = SyrodaRowDensity.normal,
    this.muted = false,
    this.onTap,
  }) : scanning = false;

  /// `.row-plain` con `.row-scan`: la fila de "Buscando mas dispositivos".
  const SyrodaRow.scanning(
    this.title, {
    super.key,
    this.density = SyrodaRowDensity.normal,
  }) : subtitle = null,
       icon = null,
       iconStyle = SyrodaRowIconStyle.empty,
       trailing = null,
       muted = false,
       onTap = null,
       scanning = true;

  final String title;
  final String? subtitle;
  final SyrodaIconData? icon;
  final SyrodaRowIconStyle iconStyle;
  final Widget? trailing;
  final SyrodaRowDensity density;

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
              SyrodaRowIcon(
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

/// Las medidas de cada densidad, tomadas de `css/syroda.css`.
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

  static _RowMetrics of(SyrodaRowDensity density) => switch (density) {
    SyrodaRowDensity.normal => const _RowMetrics(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 12,
      iconBox: 36,
      iconGlyph: 16,
      title: 14,
      subtitle: 12,
      scan: 13,
    ),
    SyrodaRowDensity.small => const _RowMetrics(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 12,
      iconBox: 34,
      iconGlyph: 15,
      title: 13.5,
      subtitle: 11.5,
      scan: 13,
    ),
    SyrodaRowDensity.rail => const _RowMetrics(
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
