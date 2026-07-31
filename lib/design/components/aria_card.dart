import 'package:flutter/widgets.dart';

import '../nocturne.dart';

/// `.elev-sm` / `.elev-md` / `.elev-lg`.
enum AriaElevation { none, sm, md, lg }

/// `.card` — superficie con radio medio. El contenido lo compone quien la
/// usa: los mockups la reutilizan en columna (tarjeta de codigo) y en fila
/// (tarjeta de transferencia).
class AriaCard extends StatelessWidget {
  const AriaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NocturneSpace.s3),
    this.elevation = AriaElevation.none,
    this.color = NocturneColors.surface,
    this.borderRadius = NocturneRadius.brMd,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AriaElevation elevation;
  final Color color;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      boxShadow: switch (elevation) {
        AriaElevation.none => null,
        AriaElevation.sm => NocturneShadow.sm,
        AriaElevation.md => NocturneShadow.md,
        AriaElevation.lg => NocturneShadow.lg,
      },
    ),
    child: child,
  );
}
