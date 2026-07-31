import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

/// Borde punteado con esquinas redondeadas: `border: 1.5px dashed`. Flutter no
/// trae bordes punteados, asi que el contorno se recorre y se pinta a trozos.
/// El patron sigue la proporcion que usa el navegador para `dashed`: raya y
/// espacio de tres veces el grosor.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.width = 1.5,
    this.radius = 0,
  });

  final Widget child;
  final Color color;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedBorderPainter(
      color: color,
      width: width,
      radius: radius,
    ),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
  });

  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = width / 2;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - width,
        size.height - width,
      ),
      Radius.circular(radius),
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color
      ..isAntiAlias = true;

    final double dash = width * 3;
    final Path outline = Path()..addRRect(rrect);
    for (final PathMetric metric in outline.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = start + dash;
        canvas.drawPath(
          metric.extractPath(start, end.clamp(0, metric.length)),
          paint,
        );
        start = end + dash;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}
