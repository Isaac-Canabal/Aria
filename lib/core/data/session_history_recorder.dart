/// El puente entre una sesion y el historial.
library;

import '../transfer/peer.dart';
import '../transfer/protocol/messages.dart';
import '../transfer/session_events.dart';
import 'history_repository.dart';
import 'transfer_record.dart';

/// Observa los eventos de una sesion y deja una entrada por archivo.
///
/// Es transparente: reemite todo lo que recibe, de modo que la UI siga
/// consumiendo la misma corriente. Solo se guardan estados terminales; un
/// archivo que el par declino no se registra, porque no llego a transferirse.
class SessionHistoryRecorder {
  SessionHistoryRecorder(this._repository, {required this.direction});

  final HistoryRepository _repository;
  final TransferDirection direction;

  Stream<SessionEvent> observe(Stream<SessionEvent> source) async* {
    String peerName = '';
    DevicePlatform peerPlatform = DevicePlatform.unknown;
    final Map<String, int> sizes = <String, int>{};

    // Lo que estaba en vuelo cuando la sesion se rompio: sin esto, un corte a
    // mitad no deja rastro y el archivo desaparece del historial.
    String? inFlight;
    int inFlightSize = 0;

    try {
      await for (final SessionEvent event in source) {
        switch (event) {
          case SessionAuthorized():
            peerName = event.device;
            peerPlatform = event.platform;
          case SessionManifest():
            for (final ManifestEntry entry in event.files) {
              sizes[entry.name] = entry.size;
            }
          case FileStarted():
            inFlight = event.name;
            inFlightSize = event.size;
            // El receptor sanea el nombre, asi que puede no coincidir con el
            // del manifiesto: se guarda tambien bajo el nombre real.
            sizes[event.name] = event.size;
          case FileFinished():
            inFlight = null;
            if (event.rejection == null) {
              await _repository.add(
                TransferRecord(
                  fileName: event.name,
                  sizeBytes: sizes[event.name] ?? 0,
                  direction: direction,
                  peerName: peerName,
                  peerPlatform: peerPlatform,
                  completedAt: DateTime.now().toUtc(),
                  status: event.ok
                      ? TransferStatus.completed
                      : TransferStatus.failed,
                  failure: event.failure,
                  localPath: event.path,
                ),
              );
            }
          case FileProgress():
          case SessionFinished():
            break;
        }
        yield event;
      }
    } catch (_) {
      if (inFlight != null) {
        await _repository.add(
          TransferRecord(
            fileName: inFlight,
            sizeBytes: sizes[inFlight] ?? inFlightSize,
            direction: direction,
            peerName: peerName,
            peerPlatform: peerPlatform,
            completedAt: DateTime.now().toUtc(),
            status: TransferStatus.failed,
            failure: FileFailure.incomplete,
          ),
        );
      }
      rethrow;
    }
  }
}
