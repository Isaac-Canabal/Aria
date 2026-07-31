/// Saneado del nombre de archivo.
///
/// El nombre llega de un par no confiable y termina en una ruta del disco. Se
/// sanea antes de tocarlo: sin separadores de ruta, sin componentes
/// relativos, y sin los nombres que Windows reserva.
library;

import 'dart:convert';

import 'limits.dart';

/// Lo que se usa cuando del nombre original no queda nada utilizable.
const String fallbackFileName = 'archivo';

const String _forbidden = r'<>:"/\|?*';

/// Nombres de dispositivo de Windows: `CON.txt` sigue siendo `CON`.
final Set<String> _reserved = <String>{
  'CON', 'PRN', 'AUX', 'NUL',
  for (int i = 1; i <= 9; i++) 'COM$i',
  for (int i = 1; i <= 9; i++) 'LPT$i',
};

/// Devuelve un nombre seguro para escribir en disco.
///
/// Se queda solo con el ultimo componente de la ruta, quita los caracteres
/// prohibidos y los de control, resuelve los nombres reservados y recorta a
/// [maxFileNameBytes] conservando la extension.
String sanitizeFileName(String raw) {
  // Solo el ultimo componente: "..\\..\\Windows\\System32\\x" -> "x".
  String name = raw;
  for (final String separator in <String>['/', r'\']) {
    final int index = name.lastIndexOf(separator);
    if (index >= 0) name = name.substring(index + 1);
  }

  final StringBuffer clean = StringBuffer();
  for (final int unit in name.runes) {
    // Caracteres de control y prohibidos por Windows.
    if (unit < 0x20 || unit == 0x7F) continue;
    if (_forbidden.contains(String.fromCharCode(unit))) continue;
    clean.write(String.fromCharCode(unit));
  }
  name = clean.toString();

  // Windows ignora puntos y espacios al final, asi que "x.txt. " abriria
  // "x.txt". Se quitan aqui para que el nombre sea el que se ve.
  name = name.replaceFirst(RegExp(r'[. ]+$'), '').trim();

  // Componentes relativos.
  if (name == '.' || name == '..' || name.isEmpty) return fallbackFileName;

  final String stem = _stemOf(name);
  if (_reserved.contains(stem.toUpperCase())) {
    name = '_$name';
  }

  return _truncateUtf8(name, maxFileNameBytes);
}

/// Un nombre que todavia no existe en el destino, consultando [exists].
///
/// Se queda puro a proposito: la comprobacion del disco la inyecta quien
/// llame, y asi se puede probar sin tocar el sistema de archivos.
String uniqueFileName(String name, bool Function(String candidate) exists) {
  if (!exists(name)) return name;

  final String stem = _stemOf(name);
  final String extension = name.substring(stem.length);
  for (int i = 2; i < 10000; i++) {
    final String candidate = _truncateUtf8(
      '$stem ($i)$extension',
      maxFileNameBytes,
    );
    if (!exists(candidate)) return candidate;
  }
  throw StateError('sin nombre libre para $name');
}

/// La parte anterior a la ultima extension. Un nombre que empieza por punto
/// no tiene extension: `.gitignore` es todo raiz.
String _stemOf(String name) {
  final int dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// Recorta a [limit] bytes UTF-8 sin partir un caracter y conservando la
/// extension.
String _truncateUtf8(String name, int limit) {
  if (utf8.encode(name).length <= limit) return name;

  final String stem = _stemOf(name);
  String extension = name.substring(stem.length);
  if (utf8.encode(extension).length > limit ~/ 2) extension = '';

  final int room = limit - utf8.encode(extension).length;
  String head = stem;
  while (utf8.encode(head).length > room && head.isNotEmpty) {
    head = head.substring(0, head.length - 1);
  }
  final String result = '$head$extension';
  return result.isEmpty ? fallbackFileName : result;
}
