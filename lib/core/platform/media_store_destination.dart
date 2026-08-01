/// El destino de Android: Descargas/Syroda, por MediaStore.
///
/// `path_provider` **no** da Descargas publico en Android: resuelve
/// `getExternalFilesDirs(DIRECTORY_DOWNLOADS)`, que es privado de la app e
/// inaccesible desde la app Archivos en Android 11+. El archivo llegaba a un
/// sitio donde la persona no podia entrar.
///
/// MediaStore lo resuelve sin permiso en tiempo de ejecucion en Android 10+ y
/// sin dependencias nuevas: el lado nativo va en el canal que ya existe.
///
/// El `IS_PENDING` de MediaStore es el equivalente exacto del `.part`: la fila
/// existe pero no es visible como archivo terminado hasta que se baja el
/// flag, y eso solo ocurre tras comparar el trailer.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../transfer/destination.dart';

const MethodChannel _channel = MethodChannel('syroda/platform');

/// La subcarpeta bajo Descargas. Es tambien la de Windows: el mismo nombre en
/// las dos plataformas, para que la explicacion en pantalla sea una sola.
const String destinationFolder = 'Syroda';

class MediaStoreDestination implements ReceiveDestination {
  const MediaStoreDestination();

  /// Comprueba que se puede escribir antes de aceptar un lote. `null` deja
  /// que la politica lo rechace entero con `destinationUnavailable`.
  static Future<MediaStoreDestination?> open() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('destinationReady');
      return ok ?? false ? const MediaStoreDestination() : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// El espacio libre del volumen al que MediaStore escribe.
  ///
  /// `VOLUME_EXTERNAL_PRIMARY` es `Environment.getExternalStorageDirectory()`,
  /// asi que esto mide el volumen del destino. Medirlo sobre el
  /// almacenamiento interno de la app seria otra cosa cuando no coinciden.
  static Future<int?> freeBytes() async {
    try {
      return await _channel.invokeMethod<int>('destinationFreeBytes');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  String get label => 'Descargas/$destinationFolder';

  @override
  Future<IncomingFileSink> create(String name, {required int size}) async {
    final Map<Object?, Object?>? created = await _channel
        .invokeMethod<Map<Object?, Object?>>(
          'createDownload',
          <String, Object?>{'name': name, 'size': size},
        );
    // `FileSystemException` a proposito: es lo que la sesion ya traduce a
    // `FileFailure.ioError` sin matar el lote.
    if (created == null) {
      throw const FileSystemException('MediaStore no devolvio la fila');
    }
    return _MediaStoreSink(
      uri: created['uri']! as String,
      name: created['name']! as String,
    );
  }
}

class _MediaStoreSink implements IncomingFileSink {
  _MediaStoreSink({required this.uri, required this.name});

  /// El `content://` de la fila pendiente. Es lo que acaba en el historial:
  /// **no es una ruta** y nada puede abrirlo con `dart:io`.
  final String uri;

  @override
  final String name;

  bool _closed = false;

  /// Un fallo del lado nativo sale como `FileSystemException`, que es lo que
  /// la sesion ya sabe traducir a `FileFailure.ioError` sin matar el lote.
  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? method, uri);
    }
  }

  @override
  Future<void> add(List<int> data) async {
    if (_closed) return;
    // Esperado hasta que el lado nativo termina de escribir: es lo que da la
    // contrapresion. MediaStore escribe por FUSE y es mas lento que la red.
    await _call<void>('writeDownload', <String, Object?>{
      'uri': uri,
      'bytes': Uint8List.fromList(data),
    });
  }

  @override
  Future<void> flush() async {
    if (_closed) return;
    await _call<void>('flushDownload', <String, Object?>{'uri': uri});
  }

  @override
  Future<String?> commit() async {
    if (_closed) return uri;
    _closed = true;
    // Baja `IS_PENDING`: hasta aqui el archivo no existe como terminado.
    await _call<void>('publishDownload', <String, Object?>{'uri': uri});
    return uri;
  }

  @override
  Future<void> discard() async {
    if (_closed) return;
    _closed = true;
    try {
      await _channel.invokeMethod<void>('discardDownload', <String, Object?>{
        'uri': uri,
      });
    } on PlatformException {
      // Borrar la fila pendiente es lo ultimo que se intenta.
    }
  }
}
