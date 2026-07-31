import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons/syroda_icons.dart';
import '../nocturne.dart';
import 'syroda_card.dart';
import 'syroda_row.dart';

/// `.pbar` — la barra determinada de 5px. Cuando la transferencia falla, el
/// relleno pierde el acento y se queda en gris.
class TransferProgress extends StatelessWidget {
  const TransferProgress({
    super.key,
    required this.value,
    this.failed = false,
    this.height = 5,
  });

  /// De 0 a 1.
  final double value;
  final bool failed;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: NocturneRadius.brPill,
    child: SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: ColoredBox(color: NocturneColors.neutral800),
          ),
          // Positioned.fill para que el relleno herede la altura de la
          // barra: suelto dentro del Stack se quedaria en cero.
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(
                color: failed
                    ? NocturneColors.neutral500
                    : NocturneColors.accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// El anillo de la pantalla "Enviando": 150px, radio 66, trazo 8, con el
/// porcentaje al centro. Arranca arriba y avanza en sentido horario.
class TransferRing extends StatelessWidget {
  const TransferRing({
    super.key,
    required this.value,
    this.size = 150,
    this.strokeWidth = 8,
  });

  final double value;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(value: value.clamp(0.0, 1.0), strokeWidth: strokeWidth),
      child: Center(
        child: Text(
          '${(value * 100).round()}%',
          style: NocturneType.at(
            30,
            weight: NocturneType.medium,
            height: 1.1,
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.strokeWidth});

  final double value;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // El mockup dibuja r=66 en un lienzo de 150: el trazo queda hacia
    // adentro del borde, no centrado en el.
    final double radius = size.width * (66 / 150);
    final Offset center = size.center(Offset.zero);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = NocturneColors.neutral800
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = NocturneColors.accent
      ..isAntiAlias = true;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.strokeWidth != strokeWidth;
}

/// `.card.transfer` — la fila de la cola de escritorio: simbolo, nombre y
/// porcentaje, barra, detalle, y una accion al final.
class TransferCard extends StatelessWidget {
  const TransferCard({
    super.key,
    required this.name,
    required this.status,
    required this.value,
    required this.detail,
    this.icon = SyrodaIcons.file,
    this.iconStyle = SyrodaRowIconStyle.accent,
    this.failed = false,
    this.trailing,
  });

  final String name;

  /// El texto de la derecha: "73%", "100%" o "Fallido".
  final String status;
  final double value;
  final String detail;
  final SyrodaIconData icon;
  final SyrodaRowIconStyle iconStyle;
  final bool failed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SyrodaCard(
    child: Row(
      spacing: 12,
      children: <Widget>[
        SyrodaRowIcon(icon, style: iconStyle),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 12,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NocturneType.at(
                        13.5,
                        weight: NocturneType.medium,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Text(
                    status,
                    style: NocturneType.at(
                      13.5,
                      color: failed
                          ? NocturneColors.neutral300
                          : NocturneColors.onText(0.6),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TransferProgress(value: value, failed: failed),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NocturneType.at(
                    11.5,
                    color: NocturneColors.onText(0.55),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
