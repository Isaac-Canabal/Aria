import 'package:flutter/widgets.dart';

import '../icons/syroda_icon.dart';
import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'pressable.dart';

/// `.btn` con sus tres variantes.
enum SyrodaButtonVariant { primary, secondary, ghost }

/// `.btn-sm` baja el tamano del texto; `.btn-icon` es un cuadrado de 36.
enum SyrodaButtonSize { normal, small, icon }

class SyrodaButton extends StatelessWidget {
  const SyrodaButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = SyrodaButtonVariant.secondary,
    this.size = SyrodaButtonSize.normal,
    this.icon,
    this.block = false,
    this.enabled = true,
  });

  /// `.btn-icon`: sin texto, solo el simbolo.
  const SyrodaButton.icon(
    this.icon, {
    super.key,
    this.onPressed,
    this.variant = SyrodaButtonVariant.ghost,
    this.enabled = true,
  }) : label = '',
       size = SyrodaButtonSize.icon,
       block = false;

  final String label;
  final VoidCallback? onPressed;
  final SyrodaButtonVariant variant;
  final SyrodaButtonSize size;
  final SyrodaIconData? icon;

  /// `.btn-block`: ancho completo y 5.6px de aire por encima.
  final bool block;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color foreground = switch (variant) {
      SyrodaButtonVariant.primary || SyrodaButtonVariant.ghost =>
        NocturneColors.accent,
      SyrodaButtonVariant.secondary => NocturneColors.text,
    };
    final Color? borderColor = switch (variant) {
      SyrodaButtonVariant.primary => NocturneColors.accent,
      SyrodaButtonVariant.secondary => NocturneColors.divider,
      SyrodaButtonVariant.ghost => null,
    };
    final double fontSize = size == SyrodaButtonSize.small ? 12.5 : 14;

    final EdgeInsets padding = switch (size) {
      SyrodaButtonSize.icon => EdgeInsets.zero,
      SyrodaButtonSize.small => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      SyrodaButtonSize.normal => EdgeInsets.symmetric(
        // `padding: var(--space-2) calc(var(--space-3) * 1.2)`, salvo el
        // fantasma, que se recoge a `--space-1` en horizontal.
        horizontal: variant == SyrodaButtonVariant.ghost
            ? NocturneSpace.s1
            : NocturneSpace.s3 * 1.2,
        vertical: NocturneSpace.s2,
      ),
    };

    return Pressable(
      onTap: enabled ? onPressed : null,
      builder: (BuildContext context, bool hovered, bool pressed) {
        final Color? fill = _fill(hovered: hovered, pressed: pressed);
        Widget content = Container(
          width: size == SyrodaButtonSize.icon ? 36 : null,
          height: size == SyrodaButtonSize.icon ? 36 : null,
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: borderColor ?? const Color(0x00000000)),
            borderRadius: NocturneRadius.brMd,
          ),
          child: Row(
            mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: icon != null && label.isNotEmpty ? 6 : 0,
            children: <Widget>[
              if (icon != null)
                SyrodaIcon(
                  icon!,
                  size: size == SyrodaButtonSize.icon ? 15 : 16,
                  color: foreground,
                ),
              if (label.isNotEmpty)
                // Flexible para que una etiqueta larga se recorte en vez de
                // desbordar el boton de ancho completo.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NocturneType.control.copyWith(
                      fontSize: fontSize,
                      color: foreground,
                    ),
                  ),
                ),
            ],
          ),
        );

        if (!enabled || onPressed == null) {
          content = Opacity(opacity: 0.45, child: content);
        }
        if (block) {
          // `.btn-block`: ancho completo y `margin-top: var(--space-2)`.
          content = Padding(
            padding: const EdgeInsets.only(top: NocturneSpace.s2),
            child: SizedBox(width: double.infinity, child: content),
          );
        }
        return content;
      },
    );
  }

  Color? _fill({required bool hovered, required bool pressed}) {
    if (pressed) {
      return switch (variant) {
        SyrodaButtonVariant.primary => NocturneColors.activeAccent,
        SyrodaButtonVariant.secondary => NocturneColors.activeNeutral,
        SyrodaButtonVariant.ghost => NocturneColors.activeGhost,
      };
    }
    if (hovered) {
      return switch (variant) {
        SyrodaButtonVariant.primary => NocturneColors.hoverAccent,
        SyrodaButtonVariant.secondary => NocturneColors.hoverNeutral,
        SyrodaButtonVariant.ghost => NocturneColors.hoverGhost,
      };
    }
    return null;
  }
}
