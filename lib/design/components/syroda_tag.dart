import 'package:flutter/widgets.dart';

import '../nocturne.dart';

/// `.tag` — la etiqueta de estado que los mockups repiten en filas, tablas y
/// pantallas de resultado.
enum SyrodaTagVariant { accent, accent2, neutral, outline }

class SyrodaTag extends StatelessWidget {
  const SyrodaTag(
    this.label, {
    super.key,
    this.variant = SyrodaTagVariant.neutral,
    this.fontSize = 11,
  });

  final String label;
  final SyrodaTagVariant variant;

  /// La galeria baja este tamano a 9.5px en sus propias etiquetas; las de la
  /// app se quedan en 11.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (Color? background, Color foreground, Color? border) = switch (variant) {
      SyrodaTagVariant.accent => (
        NocturneColors.accent800,
        NocturneColors.accent100,
        null,
      ),
      SyrodaTagVariant.accent2 => (
        NocturneColors.accent2_800,
        NocturneColors.accent2_100,
        null,
      ),
      SyrodaTagVariant.neutral => (
        NocturneColors.neutral800,
        NocturneColors.neutral100,
        null,
      ),
      SyrodaTagVariant.outline => (
        null,
        NocturneColors.accent,
        NocturneColors.accent,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: border == null ? null : Border.all(color: border),
        // `calc(var(--radius-md) * 0.75)`
        borderRadius: BorderRadius.circular(NocturneRadius.md * 0.75),
      ),
      child: Text(
        label,
        style: NocturneType.at(
          fontSize,
          color: foreground,
          letterSpacing: fontSize * 0.02,
          height: 1.2,
        ),
      ),
    );
  }
}
