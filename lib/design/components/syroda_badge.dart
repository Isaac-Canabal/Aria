import 'package:flutter/widgets.dart';

import '../icons/syroda_icon.dart';
import '../icons/syroda_icons.dart';
import '../nocturne.dart';

/// `.badge`, `.badge-neutral`, `.badge-quiet`.
enum SyrodaBadgeStyle { accent, neutral, quiet }

/// Disco con un simbolo o unas iniciales dentro. El tamano y el tinte
/// cambian por instancia: 52 en la zona de soltar, 64 en el estado vacio,
/// 76 en las pantallas de resultado, 56 en el perfil.
class SyrodaBadge extends StatelessWidget {
  const SyrodaBadge({
    super.key,
    required this.child,
    this.size = 52,
    this.style = SyrodaBadgeStyle.accent,
  });

  /// Con un simbolo del sprite dentro.
  SyrodaBadge.icon(
    SyrodaIconData icon, {
    super.key,
    this.size = 52,
    this.style = SyrodaBadgeStyle.accent,
    double iconSize = 22,
    double strokeWidth = 1.6,
  }) : child = SyrodaIcon(
         icon,
         size: iconSize,
         strokeWidth: strokeWidth,
         color: _foregroundOf(style),
       );

  /// `.profile-avatar`: iniciales en lugar de simbolo.
  SyrodaBadge.initials(
    String initials, {
    super.key,
    this.size = 56,
    this.style = SyrodaBadgeStyle.accent,
  }) : child = Text(
         initials,
         style: NocturneType.at(
           18,
           weight: NocturneType.medium,
           color: NocturneColors.accent100,
           height: 1.2,
         ),
       );

  final Widget child;
  final double size;
  final SyrodaBadgeStyle style;

  static Color _foregroundOf(SyrodaBadgeStyle style) => switch (style) {
    SyrodaBadgeStyle.accent => NocturneColors.accent,
    SyrodaBadgeStyle.neutral => NocturneColors.neutral300,
    SyrodaBadgeStyle.quiet => NocturneColors.neutral400,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (style) {
        SyrodaBadgeStyle.accent => NocturneColors.accent900,
        SyrodaBadgeStyle.neutral => NocturneColors.neutral800,
        SyrodaBadgeStyle.quiet => NocturneColors.surface,
      },
    ),
    child: child,
  );
}
