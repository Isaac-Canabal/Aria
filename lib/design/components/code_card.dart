import 'package:flutter/widgets.dart';

import '../nocturne.dart';
import 'syroda_card.dart';

/// `.code-card` — el codigo de 6 digitos que el receptor muestra para que el
/// emisor lo teclee.
class CodeCard extends StatelessWidget {
  const CodeCard({
    super.key,
    required this.code,
    this.kicker = 'Tu código',
    this.hint,
  });

  /// Con el espacio de lectura ya puesto: "482 913".
  final String code;
  final String kicker;
  final String? hint;

  @override
  Widget build(BuildContext context) => SyrodaCard(
    elevation: SyrodaElevation.sm,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: <Widget>[
        Text(
          kicker.toUpperCase(),
          style: NocturneType.at(
            11,
            color: NocturneColors.accent,
            letterSpacing: 11 * 0.1,
            height: 1.2,
          ),
        ),
        Text(
          code,
          style: NocturneType.at(
            36,
            weight: NocturneType.medium,
            letterSpacing: 36 * 0.12,
            height: 1.15,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: NocturneType.at(
              12.5,
              color: NocturneColors.onText(0.6),
              height: 1.4,
            ),
          ),
      ],
    ),
  );
}
