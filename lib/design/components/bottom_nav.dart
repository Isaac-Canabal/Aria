import 'package:flutter/widgets.dart';

import '../icons/syroda_icon.dart';
import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'pressable.dart';

/// Una pestana de `.bottom-nav`.
class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});

  final SyrodaIconData icon;
  final String label;
}

/// `.bottom-nav` — las cuatro secciones de la app movil. La activa recupera
/// la opacidad completa y toma el acento.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  /// Las cuatro de los mockups: enviar, recibir, historial, perfil.
  static const List<BottomNavItem> syrodaItems = <BottomNavItem>[
    BottomNavItem(icon: SyrodaIcons.send, label: 'Enviar'),
    BottomNavItem(icon: SyrodaIcons.receive, label: 'Recibir'),
    BottomNavItem(icon: SyrodaIcons.clock, label: 'Historial'),
    BottomNavItem(icon: SyrodaIcons.user, label: 'Perfil'),
  ];

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: NocturneColors.divider)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            _NavButton(
              item: items[i],
              active: i == currentIndex,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? NocturneColors.accent
        : NocturneColors.onText(0.55);

    return Pressable(
      onTap: onTap,
      builder: (BuildContext context, bool hovered, bool pressed) => Semantics(
        selected: active,
        button: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: <Widget>[
            SyrodaIcon(item.icon, size: 20, color: color),
            Text(
              item.label,
              style: NocturneType.at(10, color: color, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
