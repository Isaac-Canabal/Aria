import 'package:flutter/widgets.dart';

import '../icons/aria_icon.dart';
import '../icons/aria_icons.dart';
import '../nocturne.dart';

/// `.badge`, `.badge-neutral`, `.badge-quiet`.
enum AriaBadgeStyle { accent, neutral, quiet }

/// Disco con un simbolo o unas iniciales dentro. El tamano y el tinte
/// cambian por instancia: 52 en la zona de soltar, 64 en el estado vacio,
/// 76 en las pantallas de resultado, 56 en el perfil.
class AriaBadge extends StatelessWidget {
  const AriaBadge({
    super.key,
    required this.child,
    this.size = 52,
    this.style = AriaBadgeStyle.accent,
  });

  /// Con un simbolo del sprite dentro.
  AriaBadge.icon(
    AriaIconData icon, {
    super.key,
    this.size = 52,
    this.style = AriaBadgeStyle.accent,
    double iconSize = 22,
    double strokeWidth = 1.6,
  }) : child = AriaIcon(
         icon,
         size: iconSize,
         strokeWidth: strokeWidth,
         color: _foregroundOf(style),
       );

  /// `.profile-avatar`: iniciales en lugar de simbolo.
  AriaBadge.initials(
    String initials, {
    super.key,
    this.size = 56,
    this.style = AriaBadgeStyle.accent,
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
  final AriaBadgeStyle style;

  static Color _foregroundOf(AriaBadgeStyle style) => switch (style) {
    AriaBadgeStyle.accent => NocturneColors.accent,
    AriaBadgeStyle.neutral => NocturneColors.neutral300,
    AriaBadgeStyle.quiet => NocturneColors.neutral400,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (style) {
        AriaBadgeStyle.accent => NocturneColors.accent900,
        AriaBadgeStyle.neutral => NocturneColors.neutral800,
        AriaBadgeStyle.quiet => NocturneColors.surface,
      },
    ),
    child: child,
  );
}
