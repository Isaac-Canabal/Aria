/// Los iconos del sprite de `index.html`.
///
/// Cada trazo del sprite quedo convertido a llamadas de [Path] una sola vez.
/// El comando SVG original va en el comentario de cada funcion, que es lo que
/// hay que comparar contra el sprite cuando alguno cambie.
library;

import 'dart:ui';

sealed class IconShape {
  const IconShape();
}

/// Un `<path>`. Por defecto va trazado, como `.i` en el CSS.
final class IconPath extends IconShape {
  const IconPath(this.build, {this.filled = false});

  /// Se pasa como referencia a funcion de nivel superior para que los
  /// iconos sigan siendo constantes.
  final void Function(Path path) build;

  final bool filled;
}

/// Un `<circle>`.
final class IconCircle extends IconShape {
  const IconCircle(this.cx, this.cy, this.r);

  final double cx;
  final double cy;
  final double r;
}

/// Un `<rect>`, con esquinas opcionales.
final class IconRect extends IconShape {
  const IconRect(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.rx = 0,
    this.filled = false,
  });

  final double x;
  final double y;
  final double w;
  final double h;
  final double rx;
  final bool filled;
}

/// Un simbolo del sprite: sus figuras y el `viewBox` en el que fueron
/// dibujadas. [strokeWidth] solo lo traen los simbolos que en el sprite
/// llevan su propio `stroke-width`.
final class SyrodaIconData {
  const SyrodaIconData(this.shapes, {this.viewBox = 24, this.strokeWidth});

  final List<IconShape> shapes;
  final double viewBox;
  final double? strokeWidth;
}

abstract final class SyrodaIcons {
  static const SyrodaIconData send = SyrodaIconData(<IconShape>[
    IconPath(_arrowUp),
    IconPath(_tray),
  ]);

  static const SyrodaIconData receive = SyrodaIconData(<IconShape>[
    IconPath(_arrowDown),
    IconPath(_tray),
  ]);

  static const SyrodaIconData arrowUp = SyrodaIconData(<IconShape>[
    IconPath(_arrowUp),
  ]);

  static const SyrodaIconData clock = SyrodaIconData(<IconShape>[
    IconCircle(12, 12, 9),
    IconPath(_clockHands),
  ]);

  static const SyrodaIconData user = SyrodaIconData(<IconShape>[
    IconCircle(12, 8, 4),
    IconPath(_shoulders),
  ]);

  static const SyrodaIconData close = SyrodaIconData(<IconShape>[
    IconPath(_cross),
  ]);

  static const SyrodaIconData checkCircle = SyrodaIconData(<IconShape>[
    IconCircle(12, 12, 9),
    IconPath(_check),
  ]);

  static const SyrodaIconData xCircle = SyrodaIconData(<IconShape>[
    IconCircle(12, 12, 9),
    IconPath(_smallCross),
  ]);

  static const SyrodaIconData phone = SyrodaIconData(<IconShape>[
    IconRect(7, 2, 10, 20, rx: 2),
    IconPath(_speaker),
  ]);

  static const SyrodaIconData desktop = SyrodaIconData(<IconShape>[
    IconRect(4, 4, 16, 16, rx: 2),
    IconPath(_pins),
  ]);

  static const SyrodaIconData image = SyrodaIconData(<IconShape>[
    IconRect(3, 4, 18, 16, rx: 2),
    IconCircle(8.5, 9.5, 1.5),
    IconPath(_mountain),
  ]);

  static const SyrodaIconData file = SyrodaIconData(<IconShape>[
    IconPath(_folder),
  ]);

  static const SyrodaIconData qr = SyrodaIconData(<IconShape>[
    IconRect(3, 3, 6, 6),
    IconRect(15, 3, 6, 6),
    IconRect(3, 15, 6, 6),
    IconPath(_qrMarks),
  ]);

  // Botones de la barra de titulo de Windows.
  static const SyrodaIconData winMinimize = SyrodaIconData(<IconShape>[
    IconRect(0, 4.5, 10, 1, filled: true),
  ], viewBox: 10);

  static const SyrodaIconData winMaximize = SyrodaIconData(
    <IconShape>[IconRect(0.5, 0.5, 9, 9)],
    viewBox: 10,
    strokeWidth: 1,
  );

  static const SyrodaIconData winClose = SyrodaIconData(
    <IconShape>[IconPath(_winCross)],
    viewBox: 10,
    strokeWidth: 1,
  );
}

/// `M12 16V4M12 4l-5 5M12 4l5 5`
void _arrowUp(Path p) {
  p
    ..moveTo(12, 16)
    ..lineTo(12, 4)
    ..moveTo(12, 4)
    ..lineTo(7, 9)
    ..moveTo(12, 4)
    ..lineTo(17, 9);
}

/// `M12 4v12M12 16l-5-5M12 16l5-5`
void _arrowDown(Path p) {
  p
    ..moveTo(12, 4)
    ..lineTo(12, 16)
    ..moveTo(12, 16)
    ..lineTo(7, 11)
    ..moveTo(12, 16)
    ..lineTo(17, 11);
}

/// `M4 16v3a2 2 0 002 2h12a2 2 0 002-2v-3` — la bandeja que comparten enviar
/// y recibir. Las dos esquinas son arcos de radio 2 con `sweep-flag` 0.
void _tray(Path p) {
  const Radius r = Radius.circular(2);
  p
    ..moveTo(4, 16)
    ..lineTo(4, 19)
    ..arcToPoint(const Offset(6, 21), radius: r, clockwise: false)
    ..lineTo(18, 21)
    ..arcToPoint(const Offset(20, 19), radius: r, clockwise: false)
    ..lineTo(20, 16);
}

/// `M12 7v5l3.5 2`
void _clockHands(Path p) {
  p
    ..moveTo(12, 7)
    ..lineTo(12, 12)
    ..lineTo(15.5, 14);
}

/// `M4 20c0-4 3.6-7 8-7s8 3 8 7` — el segundo tramo es una curva suave, con
/// el primer control reflejado del anterior: (16.4, 13).
void _shoulders(Path p) {
  p
    ..moveTo(4, 20)
    ..cubicTo(4, 16, 7.6, 13, 12, 13)
    ..cubicTo(16.4, 13, 20, 16, 20, 20);
}

/// `M6 6l12 12M18 6L6 18`
void _cross(Path p) {
  p
    ..moveTo(6, 6)
    ..lineTo(18, 18)
    ..moveTo(18, 6)
    ..lineTo(6, 18);
}

/// `M8.5 12.5l2.5 2.5 4.5-5`
void _check(Path p) {
  p
    ..moveTo(8.5, 12.5)
    ..lineTo(11, 15)
    ..lineTo(15.5, 10);
}

/// `M9 9l6 6M15 9l-6 6`
void _smallCross(Path p) {
  p
    ..moveTo(9, 9)
    ..lineTo(15, 15)
    ..moveTo(15, 9)
    ..lineTo(9, 15);
}

/// `M11 18h2`
void _speaker(Path p) {
  p
    ..moveTo(11, 18)
    ..lineTo(13, 18);
}

/// `M8 20v-2M16 20v-2M8 6V4M16 6V4M4 8H2M4 16H2M22 8h-2M22 16h-2`
void _pins(Path p) {
  p
    ..moveTo(8, 20)
    ..lineTo(8, 18)
    ..moveTo(16, 20)
    ..lineTo(16, 18)
    ..moveTo(8, 6)
    ..lineTo(8, 4)
    ..moveTo(16, 6)
    ..lineTo(16, 4)
    ..moveTo(4, 8)
    ..lineTo(2, 8)
    ..moveTo(4, 16)
    ..lineTo(2, 16)
    ..moveTo(22, 8)
    ..lineTo(20, 8)
    ..moveTo(22, 16)
    ..lineTo(20, 16);
}

/// `M21 16l-5-5-9 9`
void _mountain(Path p) {
  p
    ..moveTo(21, 16)
    ..lineTo(16, 11)
    ..lineTo(7, 20);
}

/// `M3 6a2 2 0 012-2h4l2 2h8a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V6z`
/// Las cuatro esquinas son arcos de radio 2 con `sweep-flag` 1.
void _folder(Path p) {
  const Radius r = Radius.circular(2);
  p
    ..moveTo(3, 6)
    ..arcToPoint(const Offset(5, 4), radius: r)
    ..lineTo(9, 4)
    ..lineTo(11, 6)
    ..lineTo(19, 6)
    ..arcToPoint(const Offset(21, 8), radius: r)
    ..lineTo(21, 17)
    ..arcToPoint(const Offset(19, 19), radius: r)
    ..lineTo(5, 19)
    ..arcToPoint(const Offset(3, 17), radius: r)
    ..lineTo(3, 6)
    ..close();
}

/// `M15 15h3v3M20 15v3h-2M15 20h2`
void _qrMarks(Path p) {
  p
    ..moveTo(15, 15)
    ..lineTo(18, 15)
    ..lineTo(18, 18)
    ..moveTo(20, 15)
    ..lineTo(20, 18)
    ..lineTo(18, 18)
    ..moveTo(15, 20)
    ..lineTo(17, 20);
}

/// `M0 0l10 10M10 0L0 10`
void _winCross(Path p) {
  p
    ..moveTo(0, 0)
    ..lineTo(10, 10)
    ..moveTo(10, 0)
    ..lineTo(0, 10);
}
