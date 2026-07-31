import 'package:flutter/widgets.dart';

import 'aria_icons.dart';

/// Pinta un simbolo del sprite. Equivale a `<svg class="i">`: hereda el color
/// del texto y el grosor de trazo rueda sobre `--sw`, cuyo valor por defecto
/// es 1.6.
class AriaIcon extends StatelessWidget {
  const AriaIcon(
    this.icon, {
    super.key,
    required this.size,
    this.color,
    this.strokeWidth = 1.6,
  });

  final AriaIconData icon;
  final double size;
  final Color? color;

  /// En unidades del `viewBox`, como en SVG: al escalar el lienzo el trazo
  /// escala con el, igual que en el navegador.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color paint =
        color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFFFFFFFF);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          icon: icon,
          color: paint,
          strokeWidth: icon.strokeWidth ?? strokeWidth,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final AriaIconData icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / icon.viewBox, size.height / icon.viewBox);

    // `.i` fija los remates y las uniones redondeadas para todo el sprite.
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    for (final IconShape shape in icon.shapes) {
      switch (shape) {
        case IconPath(:final void Function(Path) build, :final bool filled):
          final Path path = Path();
          build(path);
          canvas.drawPath(path, filled ? fill : stroke);
        case IconCircle(:final double cx, :final double cy, :final double r):
          canvas.drawCircle(Offset(cx, cy), r, stroke);
        case IconRect(
          :final double x,
          :final double y,
          :final double w,
          :final double h,
          :final double rx,
          :final bool filled,
        ):
          final Rect rect = Rect.fromLTWH(x, y, w, h);
          final Paint paint = filled ? fill : stroke;
          if (rx > 0) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, Radius.circular(rx)),
              paint,
            );
          } else {
            canvas.drawRect(rect, paint);
          }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
