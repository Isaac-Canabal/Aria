import 'package:flutter/widgets.dart';

import '../icons/aria_icon.dart';
import '../icons/aria_icons.dart';
import '../nocturne.dart';
import 'pressable.dart';

/// `.btn` con sus tres variantes.
enum AriaButtonVariant { primary, secondary, ghost }

/// `.btn-sm` baja el tamano del texto; `.btn-icon` es un cuadrado de 36.
enum AriaButtonSize { normal, small, icon }

class AriaButton extends StatelessWidget {
  const AriaButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = AriaButtonVariant.secondary,
    this.size = AriaButtonSize.normal,
    this.icon,
    this.block = false,
    this.enabled = true,
  });

  /// `.btn-icon`: sin texto, solo el simbolo.
  const AriaButton.icon(
    this.icon, {
    super.key,
    this.onPressed,
    this.variant = AriaButtonVariant.ghost,
    this.enabled = true,
  }) : label = '',
       size = AriaButtonSize.icon,
       block = false;

  final String label;
  final VoidCallback? onPressed;
  final AriaButtonVariant variant;
  final AriaButtonSize size;
  final AriaIconData? icon;

  /// `.btn-block`: ancho completo y 5.6px de aire por encima.
  final bool block;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color foreground = switch (variant) {
      AriaButtonVariant.primary || AriaButtonVariant.ghost =>
        NocturneColors.accent,
      AriaButtonVariant.secondary => NocturneColors.text,
    };
    final Color? borderColor = switch (variant) {
      AriaButtonVariant.primary => NocturneColors.accent,
      AriaButtonVariant.secondary => NocturneColors.divider,
      AriaButtonVariant.ghost => null,
    };
    final double fontSize = size == AriaButtonSize.small ? 12.5 : 14;

    final EdgeInsets padding = switch (size) {
      AriaButtonSize.icon => EdgeInsets.zero,
      AriaButtonSize.small => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      AriaButtonSize.normal => EdgeInsets.symmetric(
        // `padding: var(--space-2) calc(var(--space-3) * 1.2)`, salvo el
        // fantasma, que se recoge a `--space-1` en horizontal.
        horizontal: variant == AriaButtonVariant.ghost
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
          width: size == AriaButtonSize.icon ? 36 : null,
          height: size == AriaButtonSize.icon ? 36 : null,
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
                AriaIcon(
                  icon!,
                  size: size == AriaButtonSize.icon ? 15 : 16,
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
        AriaButtonVariant.primary => NocturneColors.activeAccent,
        AriaButtonVariant.secondary => NocturneColors.activeNeutral,
        AriaButtonVariant.ghost => NocturneColors.activeGhost,
      };
    }
    if (hovered) {
      return switch (variant) {
        AriaButtonVariant.primary => NocturneColors.hoverAccent,
        AriaButtonVariant.secondary => NocturneColors.hoverNeutral,
        AriaButtonVariant.ghost => NocturneColors.hoverGhost,
      };
    }
    return null;
  }
}
