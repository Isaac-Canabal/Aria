/// Lo que se envia y la politica con la que se recibe.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'errors.dart';
import 'protocol/file_name.dart';
import 'protocol/limits.dart';
import 'protocol/messages.dart';

/// Un archivo listo para enviar.
///
/// No trae la huella: se calcula sobre la marcha, mientras los bytes se
/// mueven, y viaja al final en `file_hash`. Pedirla por adelantado costaba
/// una lectura completa del archivo en cada punta sin habilitar nada, porque
/// la verificacion ocurre igual al terminar.
class OutgoingFile {
  const OutgoingFile({
    required this.name,
    required this.size,
    required this.open,
  });

  final String name;
  final int size;

  /// Abre el contenido. Se llama una vez por envio.
  final Stream<List<int>> Function() open;

  static Future<OutgoingFile> fromFile(File file) async {
    final int size;
    try {
      size = await file.length();
    } on FileSystemException catch (e) {
      throw TransferIoError(file.path, e);
    }
    if (size > maxTotalBytes) {
      throw ProtocolError(
        ProtocolFault.limitExceeded,
        detail: '${file.path}: $size',
      );
    }

    return OutgoingFile(
      name: sanitizeFileName(file.uri.pathSegments.last),
      size: size,
      open: file.openRead,
    );
  }
}

/// Huella sha256 acumulada trozo a trozo. La usan las dos puntas sobre los
/// bytes que ya estan moviendo.
class IncrementalSha256 {
  final _DigestSink _out = _DigestSink();
  late final ByteConversionSink _input = sha256.startChunkedConversion(_out);

  void add(List<int> data) => _input.add(data);

  /// Cierra el calculo y devuelve la huella en hexadecimal minuscula. No se
  /// puede volver a llamar.
  String finish() {
    _input.close();
    return _out.value.toString();
  }
}

/// Acumula la huella final. Evita depender de `AccumulatorSink` para no
/// agregar un paquete por cuatro lineas.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Las decisiones del receptor. La sesion no sabe de espacio libre ni de
/// carpetas: pregunta aqui.
abstract interface class ReceivePolicy {
  /// Donde se escriben los archivos aceptados.
  Future<Directory> destination();

  /// Se consulta al llegar el manifiesto. `null` acepta la sesion.
  Future<RejectionReason?> reviewManifest(Manifest manifest);

  /// Se consulta por archivo. `null` lo acepta; rechazarlo lo salta sin
  /// matar la sesion.
  Future<RejectionReason?> reviewFile(FileHeader header);
}

/// Politica por defecto: valida el lote completo contra el espacio libre.
///
/// [freeBytes] queda inyectado porque `dart:io` no expone el espacio libre; el
/// proveedor nativo entra en la fase 4 (Android) y la fase 5 (Windows).
/// Mientras tanto **no se puede omitir en silencio**: sin el, la unica forma
/// de construir la politica es [DefaultReceivePolicy.withoutSpaceCheck], que
/// deja rastro en el log.
class DefaultReceivePolicy implements ReceivePolicy {
  const DefaultReceivePolicy({
    required this.directory,
    required Future<int?> Function() this.freeBytes,
    this.confirm,
  });

  /// Renuncia explicita a la comprobacion de espacio. Aceptar un lote que no
  /// cabe termina en un disco lleno y un archivo a medias, asi que esto es
  /// para pruebas y para arrancar una plataforma cuyo proveedor todavia no
  /// existe, no para produccion.
  DefaultReceivePolicy.withoutSpaceCheck({
    required this.directory,
    this.confirm,
  }) : freeBytes = null {
    developer.log(
      'sin comprobacion de espacio libre: el lote se acepta sin saber si cabe',
      name: 'syroda.transfer',
      level: 900, // WARNING
    );
  }

  final Directory directory;
  final Future<int?> Function()? freeBytes;

  /// La decision de la persona, cuando la UI la pide. `null` acepta.
  final Future<RejectionReason?> Function(Manifest manifest)? confirm;

  @override
  Future<Directory> destination() async => directory;

  @override
  Future<RejectionReason?> reviewManifest(Manifest manifest) async {
    if (manifest.files.length > maxManifestEntries) {
      return RejectionReason.unacceptableFile;
    }

    final int? free = await freeBytes?.call();
    // Un margen: llenar el disco hasta el ultimo byte rompe otras cosas.
    if (free != null && manifest.totalBytes > free - _spaceMargin) {
      return RejectionReason.insufficientSpace;
    }

    return confirm == null ? null : await confirm!(manifest);
  }

  @override
  Future<RejectionReason?> reviewFile(FileHeader header) async => null;

  static const int _spaceMargin = 16 * 1024 * 1024;
}
