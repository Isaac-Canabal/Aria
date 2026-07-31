/// El espacio libre del destino.
///
/// `dart:io` no lo expone y no hay paquete aprobado que lo haga, asi que cada
/// plataforma responde por un canal con la API que le corresponde:
/// `StatFs` en Android, `GetDiskFreeSpaceExW` en Windows. Son cuatro lineas
/// nativas por lado y ninguna dependencia nueva.
///
/// Devolver `null` significa "no se pudo averiguar", nunca "cabe": quien
/// consume esto decide, y `DefaultReceivePolicy` solo omite la comprobacion
/// por la puerta que deja rastro en el log.
library;

import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('aria/platform');

abstract interface class FreeSpaceProvider {
  /// Bytes disponibles en el volumen que contiene [path], o `null` si la
  /// plataforma no supo responder.
  Future<int?> bytesAvailable(String path);
}

/// Pregunta al lado nativo.
class NativeFreeSpaceProvider implements FreeSpaceProvider {
  const NativeFreeSpaceProvider();

  @override
  Future<int?> bytesAvailable(String path) async {
    try {
      final int? bytes = await _channel.invokeMethod<int>('freeSpace', <
        String,
        Object?
      >{'path': path});
      // Un valor negativo o cero no es una respuesta util.
      return (bytes ?? 0) > 0 ? bytes : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // La plataforma todavia no implementa el canal.
      return null;
    }
  }
}

/// Para pruebas y para arrancar una plataforma cuyo lado nativo no existe.
class FixedFreeSpaceProvider implements FreeSpaceProvider {
  const FixedFreeSpaceProvider(this.bytes);

  final int? bytes;

  @override
  Future<int?> bytesAvailable(String path) async => bytes;
}
