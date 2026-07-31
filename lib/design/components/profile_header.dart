import 'package:flutter/widgets.dart';

import '../nocturne.dart';
import 'syroda_badge.dart';

/// `.profile` — las iniciales, el nombre con el que se anuncia el equipo y
/// el modelo del aparato.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.initials,
    required this.name,
    required this.device,
  });

  final String initials;
  final String name;
  final String device;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 14,
    children: <Widget>[
      SyrodaBadge.initials(initials),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              name,
              style: NocturneType.at(
                16,
                weight: NocturneType.medium,
                height: 1.35,
              ),
            ),
            Text(
              device,
              style: NocturneType.at(
                12.5,
                color: NocturneColors.onText(0.6),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
