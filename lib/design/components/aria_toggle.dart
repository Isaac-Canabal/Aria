import 'package:flutter/widgets.dart';

import '../nocturne.dart';

/// `.toggle` — 40x24 con un pomo de 18 a 3px de los bordes.
class AriaToggle extends StatelessWidget {
  const AriaToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Duration _duration = Duration(milliseconds: 140);

  @override
  Widget build(BuildContext context) {
    final Widget track = AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOut,
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: value ? NocturneColors.accent : NocturneColors.neutral800,
        borderRadius: NocturneRadius.brPill,
      ),
      child: Stack(
        children: <Widget>[
          AnimatedPositioned(
            duration: _duration,
            curve: Curves.easeOut,
            top: 3,
            left: value ? 19 : 3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? NocturneColors.bg : NocturneColors.neutral400,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );

    if (onChanged == null) return track;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged!(!value),
        child: Semantics(
          toggled: value,
          label: value ? 'Activado' : 'Desactivado',
          child: track,
        ),
      ),
    );
  }
}
