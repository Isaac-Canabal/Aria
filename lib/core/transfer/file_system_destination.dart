/// El destino sobre el sistema de archivos.
///
/// Es lo que usan Windows y las pruebas. Android escribe por MediaStore, que
/// no tiene ruta que abrir con `dart:io`: ver la capa de plataforma.
library;

import 'dart:async';
import 'dart:io';

import 'destination.dart';
import 'protocol/file_name.dart';

class FileSystemDestination implements ReceiveDestination {
  const FileSystemDestination(this.directory);

  final Directory directory;

  /// Abre la carpeta, creandola si hace falta. `null` si no se puede escribir
  /// en ella: es lo que acaba en `destinationUnavailable`, con el lote entero
  /// y antes de aceptarlo.
  static Future<FileSystemDestination?> open(Directory directory) async {
    try {
      if (!await directory.exists()) await directory.create(recursive: true);
      // Existir no es poder escribir: una carpeta de solo lectura, o un
      // volumen desmontado, se descubren aqui y no a mitad del lote.
      final File probe = File(
        '${directory.path}${Platform.pathSeparator}.syroda-probe',
      );
      await probe.writeAsString('', flush: true);
      await probe.delete();
      return FileSystemDestination(directory);
    } on FileSystemException {
      return null;
    }
  }

  @override
  String get label => directory.path;

  @override
  Future<IncomingFileSink> create(String name, {required int size}) async {
    final String safe = uniqueFileName(
      name,
      (String candidate) =>
          File(
            '${directory.path}${Platform.pathSeparator}$candidate',
          ).existsSync() ||
          File(
            '${directory.path}${Platform.pathSeparator}$candidate.part',
          ).existsSync(),
    );
    final String finalPath = '${directory.path}${Platform.pathSeparator}$safe';
    final File partial = File('$finalPath.part');
    return _FileSink(
      name: safe,
      partial: partial,
      finalPath: finalPath,
      handle: await partial.open(mode: FileMode.write),
    );
  }
}

class _FileSink implements IncomingFileSink {
  _FileSink({
    required this.name,
    required this.partial,
    required this.finalPath,
    required this._handle,
  });

  @override
  final String name;

  final File partial;
  final String finalPath;

  RandomAccessFile? _handle;

  /// `RandomAccessFile.writeFrom` en vez de `IOSink.add`: este si se puede
  /// esperar, y esperarlo es lo que acota lo que hay en vuelo a un chunk.
  @override
  Future<void> add(List<int> data) async => _handle?.writeFrom(data);

  @override
  Future<void> flush() async => _handle?.flush();

  @override
  Future<String?> commit() async {
    await _close();
    await partial.rename(finalPath);
    return finalPath;
  }

  @override
  Future<void> discard() async {
    await _close();
    try {
      if (await partial.exists()) await partial.delete();
    } on FileSystemException {
      // Borrar el parcial es lo ultimo que se intenta: si falla, no hay a
      // quien contarselo que sirva de algo.
    }
  }

  Future<void> _close() async {
    final RandomAccessFile? handle = _handle;
    _handle = null;
    await handle?.close();
  }
}
