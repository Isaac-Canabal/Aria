/// Abrir lo recibido, y la carpeta donde esta.
///
/// El historial guarda la ruta o el `content://`, **no el archivo**: la
/// persona puede haberlo borrado desde Archivos o el Explorador y la entrada
/// seguir ahi. Por eso los resultados se distinguen en vez de colapsar en un
/// "no se pudo": son problemas distintos y lo que puede hacer la persona
/// tambien.
library;

import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('syroda/platform');

enum OpenOutcome {
  opened,

  /// El archivo ya no esta donde decia el historial.
  missing,

  /// No hay ninguna aplicacion capaz de abrirlo.
  noHandler,

  /// Cualquier otro fallo del sistema.
  failed,
}

abstract interface class ReceivedFileOpener {
  /// Abre [target]: una ruta en escritorio, un `content://` en Android.
  Future<OpenOutcome> open(String target);

  /// Lo ensena en su carpeta. En Windows abre el Explorador con el archivo ya
  /// seleccionado; en Android no existe el equivalente y abre el archivo.
  Future<OpenOutcome> reveal(String target);

  /// Abre la carpeta de destino. [path] solo lo usa el escritorio.
  Future<OpenOutcome> openFolder(String path);
}

class SystemFileOpener implements ReceivedFileOpener {
  const SystemFileOpener();

  @override
  Future<OpenOutcome> open(String target) => _call('openFile', target);

  @override
  Future<OpenOutcome> reveal(String target) => _call('revealFile', target);

  @override
  Future<OpenOutcome> openFolder(String path) =>
      _call('openDestinationFolder', path);

  Future<OpenOutcome> _call(String method, String target) async {
    try {
      final String? outcome = await _channel.invokeMethod<String>(
        method,
        <String, Object?>{'target': target},
      );
      return switch (outcome) {
        'opened' => OpenOutcome.opened,
        'missing' => OpenOutcome.missing,
        'noHandler' => OpenOutcome.noHandler,
        _ => OpenOutcome.failed,
      };
    } on PlatformException {
      return OpenOutcome.failed;
    } on MissingPluginException {
      // La plataforma no implementa el canal. No es culpa de la persona ni
      // hay nada que pueda hacer con ese dato.
      return OpenOutcome.failed;
    }
  }
}

/// El texto de cada resultado. Corto y accionable: nunca una pantalla de
/// error, porque no ha fallado ninguna transferencia.
String? openOutcomeMessage(OpenOutcome outcome) => switch (outcome) {
  OpenOutcome.opened => null,
  OpenOutcome.missing => 'El archivo ya no está donde se guardó',
  OpenOutcome.noHandler => 'No hay ninguna app para abrir este archivo',
  OpenOutcome.failed => 'No se pudo abrir el archivo',
};
