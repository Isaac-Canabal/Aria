/// Lo que una sesion cuenta mientras corre. La UI de las fases 4 y 5 se
/// suscribe a esto; la capa de transporte no sabe de pantallas.
library;

import 'errors.dart';
import 'peer.dart';
import 'protocol/messages.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// El handshake termino bien: el codigo era el correcto.
final class SessionAuthorized extends SessionEvent {
  const SessionAuthorized({
    required this.deviceId,
    required this.device,
    required this.platform,
  });

  /// El identificador estable del par. Es lo que se guarda al emparejar.
  final String deviceId;

  final String device;
  final DevicePlatform platform;
}

/// El lote quedo acordado. Es lo que llena la cola antes de mover un byte.
final class SessionManifest extends SessionEvent {
  const SessionManifest(this.files, {required this.totalBytes});

  final List<ManifestEntry> files;
  final int totalBytes;
}

final class FileStarted extends SessionEvent {
  const FileStarted({
    required this.name,
    required this.index,
    required this.size,
  });

  final String name;

  /// Posicion dentro del lote, desde 0.
  final int index;

  final int size;
}

/// Un chunk mas. Trae el avance del archivo y el del lote, porque los mockups
/// muestran los dos: el anillo por archivo y la cola por sesion.
final class FileProgress extends SessionEvent {
  const FileProgress({
    required this.name,
    required this.index,
    required this.bytes,
    required this.size,
    required this.sessionBytes,
    required this.sessionTotal,
  });

  final String name;
  final int index;
  final int bytes;
  final int size;
  final int sessionBytes;
  final int sessionTotal;

  double get fraction => size == 0 ? 1 : bytes / size;
}

/// Un archivo termino. [failure] nulo es exito.
final class FileFinished extends SessionEvent {
  const FileFinished({
    required this.name,
    required this.index,
    this.failure,
    this.rejection,
    this.path,
  });

  final String name;
  final int index;

  /// Donde quedo el archivo. Solo lo llena el receptor, y solo cuando el
  /// checksum cuadro y el `.part` ya se renombro.
  final String? path;

  /// Fallo tecnico: huella que no cuadra, disco, corte.
  final FileFailure? failure;

  /// El par lo declino. No es un fallo.
  final RejectionReason? rejection;

  bool get ok => failure == null && rejection == null;
}

/// La sesion termino de forma limpia.
final class SessionFinished extends SessionEvent {
  const SessionFinished({required this.completed, required this.total});

  final int completed;
  final int total;
}
