/// Nocturne — traduccion literal de `css/nocturne.css`.
///
/// Este es el unico archivo del proyecto donde puede aparecer un color
/// literal. Todo lo demas referencia estos tokens. Si un valor de aqui no
/// coincide con el CSS, el que esta mal es este archivo: `css/nocturne.css`
/// es la fuente de verdad y no se modifica.
library;

import 'package:flutter/material.dart';

/// Colores. Las rampas se generaron en OKLCH sobre una escala de luminosidad
/// compartida, asi que el mismo paso de cualquier rol coincide en valor
/// visual con los demas.
abstract final class NocturneColors {
  static const Color bg = Color(0xFF161826);
  static const Color surface = Color(0xFF232532);
  static const Color text = Color(0xFFE9E9ED);
  static const Color accent = Color(0xFF9184D9);
  static const Color accent2 = Color(0xFFA7A1DB);

  static const Color neutral100 = Color(0xFFF3F5FE);
  static const Color neutral200 = Color(0xFFE4E7F5);
  static const Color neutral300 = Color(0xFFCFD3E5);
  static const Color neutral400 = Color(0xFFB2B6CA);
  static const Color neutral500 = Color(0xFF9397AB);
  static const Color neutral600 = Color(0xFF75798C);
  static const Color neutral700 = Color(0xFF595D6C);
  static const Color neutral800 = Color(0xFF3F424D);
  static const Color neutral900 = Color(0xFF292B31);

  static const Color accent100 = Color(0xFFF5F4FF);
  static const Color accent200 = Color(0xFFE7E5FE);
  static const Color accent300 = Color(0xFFD2CEFD);
  static const Color accent400 = Color(0xFFB5ABFC);
  static const Color accent500 = Color(0xFF968AE0);
  static const Color accent600 = Color(0xFF796CBF);
  static const Color accent700 = Color(0xFF5D5294);
  static const Color accent800 = Color(0xFF423A6A);
  static const Color accent900 = Color(0xFF2B2741);

  static const Color accent2_100 = Color(0xFFF5F4FF);
  static const Color accent2_200 = Color(0xFFE7E5FE);
  static const Color accent2_300 = Color(0xFFD2CEFD);
  static const Color accent2_400 = Color(0xFFB5AFE8);
  static const Color accent2_500 = Color(0xFF9690C9);
  static const Color accent2_600 = Color(0xFF7972A9);
  static const Color accent2_700 = Color(0xFF5C5783);
  static const Color accent2_800 = Color(0xFF423E5D);
  static const Color accent2_900 = Color(0xFF2B293A);

  /// Fondos de seccion. Solo a escala de deck: no son colores de interfaz.
  static const Color section = Color(0xFF262A60);
  static const Color sectionGlow = Color(0xFF353B80);
  static const Color sectionGhost = Color(0xFF4C5397);

  /// `color-mix(in srgb, X n%, transparent)` equivale a X con alpha n%: la
  /// mezcla srgb con transparente es exactamente eso. Estos dos helpers
  /// cubren todos los usos del CSS.
  static Color onText(double percent) => text.withValues(alpha: percent);
  static Color onAccent(double percent) => accent.withValues(alpha: percent);

  /// `--color-divider`
  static final Color divider = onText(0.16);

  /// `.text-muted` y `figcaption`
  static final Color textMuted = onText(0.55);

  /// `.field > label`
  static final Color label = onText(0.70);

  /// `.card-meta`
  static final Color cardMeta = onText(0.50);

  /// `.table th`
  static final Color tableHead = onText(0.60);

  /// Rellenos de hover/active sobre superficies neutras.
  static final Color hoverNeutral = onText(0.07);
  static final Color activeNeutral = onText(0.14);

  /// Rellenos de hover/active de los controles con acento.
  static final Color hoverAccent = onAccent(0.12);
  static final Color activeAccent = onAccent(0.22);
  static final Color hoverGhost = onAccent(0.10);
  static final Color activeGhost = onAccent(0.18);

  /// `::selection`
  static final Color selection = onAccent(0.30);
}

/// `--space-*`. La escala no es entera: sale de una base de 2.8px.
abstract final class NocturneSpace {
  static const double s1 = 2.8;
  static const double s2 = 5.6;
  static const double s3 = 8.4;
  static const double s4 = 11.2;
  static const double s6 = 16.8;
  static const double s8 = 22.4;
}

/// `--radius-*`
abstract final class NocturneRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 14;

  /// Radio de las pildoras (`border-radius: 999px`).
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// `--shadow-*`. En tema oscuro la elevacion es un filo de 1px mas oscuridad
/// ambiental; el filo se modela como una sombra sin desenfoque ni desfase.
abstract final class NocturneShadow {
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: NocturneColors.neutral800, spreadRadius: 1),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: NocturneColors.neutral700, spreadRadius: 1),
    BoxShadow(
      color: Color(0x8C000000), // rgba(0,0,0,0.55)
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: NocturneColors.neutral500, spreadRadius: 1),
    BoxShadow(
      color: Color(0xA6000000), // rgba(0,0,0,0.65)
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];
}

/// Tipografia. Los titulos van en peso 500 con interletrado -0.015em; el
/// cuerpo en 400 a 15/1.55. `letterSpacing` se expresa en px, asi que cada
/// estilo trae su em ya multiplicado por su tamano.
abstract final class NocturneType {
  static const String family = 'Inter';

  static const FontWeight headingWeight = FontWeight.w500;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const double _headingTracking = -0.015;
  static const double _headingHeight = 1.12;

  static TextStyle _heading(double size) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: headingWeight,
    height: _headingHeight,
    letterSpacing: size * _headingTracking,
    color: NocturneColors.text,
  );

  static final TextStyle h1 = _heading(42);
  static final TextStyle h2 = _heading(32);
  static final TextStyle h3 = _heading(25);
  static final TextStyle h4 = _heading(20);
  static final TextStyle h5 = _heading(16);

  /// h6 rompe el patron: versalitas con interletrado positivo.
  static final TextStyle h6 = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: headingWeight,
    height: _headingHeight,
    letterSpacing: 13 * 0.08,
    color: NocturneColors.text,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: regular,
    height: 1.55,
    color: NocturneColors.text,
  );

  /// Texto de controles: `.btn` y `.input` comparten 14px.
  static const TextStyle control = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: headingWeight,
    height: 1.2,
    color: NocturneColors.text,
  );

  /// Un estilo derivado del cuerpo, para los tamanos sueltos que usan los
  /// componentes de Aria (13.5px, 12.5px, 11.5px...).
  static TextStyle at(
    double size, {
    FontWeight weight = regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color ?? NocturneColors.text,
  );
}

/// El `ThemeData` de la app. Los widgets de Material heredan de aqui; los
/// componentes de Aria toman los tokens directamente.
ThemeData nocturneTheme() {
  const ColorScheme scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: NocturneColors.accent,
    onPrimary: NocturneColors.accent900,
    secondary: NocturneColors.accent2,
    onSecondary: NocturneColors.accent2_900,
    error: NocturneColors.neutral300,
    onError: NocturneColors.neutral900,
    surface: NocturneColors.surface,
    onSurface: NocturneColors.text,
  );

  final TextTheme textTheme = TextTheme(
    displayLarge: NocturneType.h1,
    displayMedium: NocturneType.h2,
    headlineLarge: NocturneType.h3,
    headlineMedium: NocturneType.h4,
    headlineSmall: NocturneType.h5,
    titleSmall: NocturneType.h6,
    bodyLarge: NocturneType.body,
    bodyMedium: NocturneType.body,
    labelLarge: NocturneType.control,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: NocturneColors.bg,
    canvasColor: NocturneColors.bg,
    fontFamily: NocturneType.family,
    textTheme: textTheme,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: NocturneColors.accent,
      selectionColor: NocturneColors.selection,
      selectionHandleColor: NocturneColors.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
