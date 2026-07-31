import 'package:flutter/widgets.dart';

import '../icons/syroda_icon.dart';
import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'pressable.dart';

/// `.win-titlebar` — la barra de titulo propia de la ventana de Windows. Solo
/// pinta: quien la usa conecta los botones con el gestor de ventanas.
class WinTitleBar extends StatelessWidget {
  const WinTitleBar({
    super.key,
    required this.title,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  final String title;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      color: NocturneColors.surface,
      border: Border(bottom: BorderSide(color: NocturneColors.divider)),
    ),
    child: Row(
      children: <Widget>[
        const SizedBox(width: 14),
        const _WinLogo(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NocturneType.at(
              12.5,
              weight: NocturneType.medium,
              height: 1.3,
            ),
          ),
        ),
        _WinControl(icon: SyrodaIcons.winMinimize, onPressed: onMinimize),
        _WinControl(icon: SyrodaIcons.winMaximize, onPressed: onMaximize),
        _WinControl(icon: SyrodaIcons.winClose, onPressed: onClose),
      ],
    ),
  );
}

/// `.win-logo`
class _WinLogo extends StatelessWidget {
  const _WinLogo();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: NocturneColors.accent900,
      borderRadius: NocturneRadius.brSm,
    ),
    child: const SyrodaIcon(
      SyrodaIcons.arrowUp,
      size: 9,
      strokeWidth: 2,
      color: NocturneColors.accent,
    ),
  );
}

/// `.win-controls > span`
class _WinControl extends StatelessWidget {
  const _WinControl({required this.icon, this.onPressed});

  final SyrodaIconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onPressed,
    builder: (BuildContext context, bool hovered, bool pressed) => Container(
      width: 46,
      height: double.infinity,
      alignment: Alignment.center,
      color: pressed
          ? NocturneColors.activeNeutral
          : hovered
          ? NocturneColors.hoverNeutral
          : null,
      child: SyrodaIcon(
        icon,
        size: 10,
        color: NocturneColors.onText(0.65),
      ),
    ),
  );
}
