import 'package:flutter/widgets.dart';

import '../nocturne.dart';

/// `.elev-sm` / `.elev-md` / `.elev-lg`.
enum SyrodaElevation { none, sm, md, lg }

/// `.card` — superficie con radio medio. El contenido lo compone quien la
/// usa: los mockups la reutilizan en columna (tarjeta de codigo) y en fila
/// (tarjeta de transferencia).
class SyrodaCard extends StatelessWidget {
  const SyrodaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NocturneSpace.s3),
    this.elevation = SyrodaElevation.none,
    this.color = NocturneColors.surface,
    this.borderRadius = NocturneRadius.brMd,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final SyrodaElevation elevation;
  final Color color;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      boxShadow: switch (elevation) {
        SyrodaElevation.none => null,
        SyrodaElevation.sm => NocturneShadow.sm,
        SyrodaElevation.md => NocturneShadow.md,
        SyrodaElevation.lg => NocturneShadow.lg,
      },
    ),
    child: child,
  );
}
