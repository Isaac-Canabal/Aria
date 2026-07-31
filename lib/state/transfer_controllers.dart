/// El estado vivo de la transferencia: descubrimiento, recepcion y envio.
///
/// Es lo que separa la UI de la capa de transporte. Las pantallas leen de
/// aqui y no conocen sockets.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/data/session_history_recorder.dart';
import '../core/data/transfer_record.dart';
import '../core/platform/free_space.dart';
import '../core/platform/transfer_foreground_service.dart';
import '../core/transfer/transfer.dart';
import 'data_providers.dart';
import 'lifecycle.dart';
import 'paired_devices_controller.dart';
import 'settings_controller.dart';

// ── descubrimiento ────────────────────────────────────────────────────────

final Provider<DiscoveryService> discoveryServiceProvider =
    Provider<DiscoveryService>((Ref ref) {
      final DiscoveryService service = NsdDiscoveryService();
      ref.onDispose(service.dispose);
      return service;
    });

/// Los pares visibles ahora mismo. Lista vacia mientras no llega ninguno, que
/// es el estado "Buscando mas dispositivos..." de los mockups.
final StreamProvider<List<Peer>> peersProvider = StreamProvider<List<Peer>>((
  Ref ref,
) async* {
  final DiscoveryService service = ref.watch(discoveryServiceProvider);
  // Antes de descubrir: en la red puede quedar un registro zombi de un
  // arranque anterior de esta instalacion, y sin esto se veria como un par.
  final DeviceIdentity identity = await ref.watch(
    deviceIdentityProvider.future,
  );
  service.excludeSelf(identity.id);
  // Se espera a proposito: si falta CHANGE_WIFI_MULTICAST_STATE, `nsd` lanza
  // aqui, y ese error tiene que llegar a la pantalla en vez de perderse.
  await service.startDiscovery();
  ref.onDispose(service.stopDiscovery);
  yield* service.peers;
});

/// Cuanto se espera antes de ofrecer el emparejamiento manual. Pasado esto
/// sin pares, el estado vacio gana su accion secundaria.
const Duration discoveryGracePeriod = Duration(seconds: 12);

// ── recepcion ─────────────────────────────────────────────────────────────

final Provider<PairingService> pairingServiceProvider =
    Provider<PairingService>((Ref ref) {
      final PairingService pairing = PairingService();
      ref.onDispose(pairing.dispose);
      return pairing;
    });

/// El codigo vigente. Cambia solo cuando se invalida por intentos fallidos.
final StreamProvider<PairingCode> pairingCodeProvider =
    StreamProvider<PairingCode>((Ref ref) {
      final PairingService pairing = ref.watch(pairingServiceProvider);
      return pairing.codes.asBroadcastStream();
    });

final Provider<FreeSpaceProvider> freeSpaceProvider =
    Provider<FreeSpaceProvider>((Ref ref) => const NativeFreeSpaceProvider());

/// Toda sesion, de envio o de recepcion, corre atada a este servicio: en
/// Android 10+ los sockets de una app en segundo plano se cortan.
final Provider<TransferForegroundService> foregroundServiceProvider =
    Provider<TransferForegroundService>(
      (Ref ref) => Platform.isAndroid
          ? AndroidTransferForegroundService()
          : NoTransferForegroundService(),
    );

/// Donde se guarda lo recibido.
final FutureProvider<Directory> downloadsDirectoryProvider =
    FutureProvider<Directory>((Ref ref) async {
      final Directory? downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
      // Android no siempre expone Descargas: se cae al directorio de la app.
      return getApplicationDocumentsDirectory();
    });

/// El servidor de recepcion, ligado al puerto efimero que despues se anuncia.
final FutureProvider<ReceiveServer> receiveServerProvider =
    FutureProvider<ReceiveServer>((Ref ref) async {
      final DeviceIdentity identity = await ref.watch(
        deviceIdentityProvider.future,
      );
      final Directory destination = await ref.watch(
        downloadsDirectoryProvider.future,
      );
      final FreeSpaceProvider space = ref.watch(freeSpaceProvider);

      final ReceiveServer server = await ReceiveServer.bind(
        identity: identity,
        responder: PlainChannelResponder(ref.watch(pairingServiceProvider)),
        policy: DefaultReceivePolicy(
          directory: destination,
          freeBytes: () => space.bytesAvailable(destination.path),
        ),
      );
      // Se deja de aceptar al pasar a background y se vuelve a aceptar al
      // volver. El socket de escucha no se cierra: una sesion en vuelo sigue.
      server.setAccepting(ref.watch(appForegroundProvider));

      ref.onDispose(server.close);
      return server;
    });

/// Publica este dispositivo mientras la visibilidad no sea "Nadie".
///
/// El puerto sale del `bind(0)` del servidor: nadie lo elige.
/// `autoDispose`: salir de la pantalla Recibir deja de anunciar, igual que
/// irse a background. "Esperando conexion..." es el estado de una pantalla
/// abierta, no un servicio permanente.
final AutoDisposeFutureProvider<void>
announcementProvider = FutureProvider.autoDispose<void>((Ref ref) async {
  if (!ref.watch(announcingProvider)) return;
  // En background no se anuncia: el par no ve un dispositivo que no va a
  // aceptarle nada.
  if (!ref.watch(appForegroundProvider)) return;

  // WORKAROUND, no codigo redundante: no borrar sin leer esto.
  //
  // Causa: `nsd_android` adquiere el `WifiManager.MulticastLock` solo en
  // `startDiscovery` (NsdAndroidPlugin.kt:96) y lo libera en `stopDiscovery`
  // (:131). Nunca lo ata al registro. Pero **responder** una consulta mDNS
  // tambien exige recibir multicast, asi que un dispositivo que solo se
  // anuncia lo necesita igual: sin el lock, en varios equipos las consultas
  // entrantes no llegan y la pantalla Recibir queda invisible, sin error.
  //
  // Por eso se mantiene un descubrimiento vivo mientras se anuncia: es la
  // unica forma de sostener el lock desde fuera del plugin.
  //
  // Costo: un descubrimiento activo cuyos resultados esta pantalla no usa,
  // con el gasto de radio que eso implica.
  //
  // Sustituible en cuanto `nsd_android` ate el lock tambien al registro.
  ref.watch(peersProvider);

  final DiscoveryService discovery = ref.watch(discoveryServiceProvider);
  final ReceiveServer server = await ref.watch(receiveServerProvider.future);
  final DeviceIdentity identity = await ref.watch(
    deviceIdentityProvider.future,
  );

  await discovery.announce(identity: identity, port: server.port);
  ref.onDispose(discovery.stopAnnouncing);
});

/// Los eventos de las sesiones entrantes, ya registrados en el historial y en
/// los emparejados.
final StreamProvider<SessionEvent>
incomingProvider = StreamProvider<SessionEvent>((Ref ref) async* {
  final ReceiveServer server = await ref.watch(receiveServerProvider.future);
  final SessionHistoryRecorder recorder = SessionHistoryRecorder(
    await ref.watch(historyRepositoryProvider.future),
    direction: TransferDirection.received,
  );
  final TransferForegroundService service = ref.watch(
    foregroundServiceProvider,
  );

  // Si la sesion muere, el servicio no puede quedar vivo: se suelta en el
  // `finally`, valga como final limpio o como corte.
  bool held = false;
  Future<void> release() async {
    if (!held) return;
    held = false;
    await service.end();
  }

  try {
    await for (final SessionEvent event in recorder.observe(server.events)) {
      switch (event) {
        case SessionAuthorized():
          await ref.read(pairedDevicesProvider.notifier).rememberFrom(event);
          held = true;
          await service.begin(
            title: 'Recibiendo de ${event.device}',
            text: 'Syroda está recibiendo archivos en la red local.',
          );
        case SessionFinished():
          await release();
        case SessionManifest():
        case FileStarted():
        case FileProgress():
        case FileFinished():
          break;
      }
      yield event;
    }
  } finally {
    await release();
  }
});

// ── envio ─────────────────────────────────────────────────────────────────

/// El estado de la pantalla de envio. Cada variante es una pantalla de los
/// mockups.
sealed class SendState {
  const SendState();
}

/// "Enviar - inicio": eligiendo archivo y destino.
final class SendIdle extends SendState {
  const SendIdle();
}

/// "Enviando": el anillo con el porcentaje.
final class SendInProgress extends SendState {
  const SendInProgress({
    required this.fileName,
    required this.peerName,
    required this.sentBytes,
    required this.totalBytes,
  });

  final String fileName;
  final String peerName;
  final int sentBytes;
  final int totalBytes;

  double get fraction => totalBytes == 0 ? 0 : sentBytes / totalBytes;
}

/// "Completado".
final class SendCompleted extends SendState {
  const SendCompleted({
    required this.fileName,
    required this.peerName,
    required this.elapsed,
  });

  final String fileName;
  final String peerName;
  final Duration elapsed;
}

/// "Error al enviar".
final class SendFailed extends SendState {
  const SendFailed({
    required this.fileName,
    required this.peerName,
    required this.error,
  });

  final String fileName;
  final String peerName;
  final TransferError error;
}

class SendController extends Notifier<SendState> {
  SendSession? _session;
  StreamSubscription<SessionEvent>? _subscription;
  Stopwatch? _clock;
  TransferForegroundService? _service;
  bool _serviceHeld = false;

  @override
  SendState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _session?.cancel();
      // Ni siquiera tirar el controlador puede dejar el servicio encendido.
      unawaited(_releaseService());
    });
    return const SendIdle();
  }

  /// Suelta el servicio una sola vez, venga de un final limpio o de un corte.
  Future<void> _releaseService() async {
    if (!_serviceHeld) return;
    _serviceHeld = false;
    await _service?.end();
  }

  /// Manda [files] a [peer] con el codigo que la persona tecleo.
  Future<void> send({
    required Peer peer,
    required String code,
    required List<OutgoingFile> files,
  }) async {
    if (files.isEmpty) return;
    final DeviceIdentity identity = await ref.read(
      deviceIdentityProvider.future,
    );

    final SendSession session = SendSession(
      host: peer.host,
      port: peer.port,
      identity: identity,
      channel: PlainChannelInitiator(code),
      files: files,
    );
    _session = session;
    _clock = Stopwatch()..start();

    final SessionHistoryRecorder recorder = SessionHistoryRecorder(
      await ref.read(historyRepositoryProvider.future),
      direction: TransferDirection.sent,
    );

    _service = ref.read(foregroundServiceProvider);
    _serviceHeld = true;
    await _service!.begin(
      title: 'Enviando a ${peer.name}',
      text: 'Syroda está enviando archivos en la red local.',
    );

    final String first = files.first.name;
    state = SendInProgress(
      fileName: first,
      peerName: peer.name,
      sentBytes: 0,
      totalBytes: files.fold<int>(
        0,
        (int sum, OutgoingFile file) => sum + file.size,
      ),
    );

    _subscription = recorder
        .observe(session.run())
        .listen(
          (SessionEvent event) => _onEvent(event, peer),
          onError: (Object error) => _onError(error, peer, first),
          onDone: _onDone,
        );
  }

  void _onEvent(SessionEvent event, Peer peer) {
    switch (event) {
      case SessionAuthorized():
        unawaited(ref.read(pairedDevicesProvider.notifier).rememberFrom(event));
      case FileProgress():
        state = SendInProgress(
          fileName: event.name,
          peerName: peer.name,
          sentBytes: event.sessionBytes,
          totalBytes: event.sessionTotal,
        );
      case SessionFinished():
        final SendState current = state;
        state = SendCompleted(
          fileName: current is SendInProgress ? current.fileName : '',
          peerName: peer.name,
          elapsed: _clock?.elapsed ?? Duration.zero,
        );
      case SessionManifest():
      case FileStarted():
      case FileFinished():
        break;
    }
  }

  void _onError(Object error, Peer peer, String fileName) {
    unawaited(_releaseService());
    final SendState current = state;
    state = SendFailed(
      fileName: current is SendInProgress ? current.fileName : fileName,
      peerName: peer.name,
      error: error is TransferError
          ? error
          : const ConnectionFailed(ConnectionFault.lost),
    );
  }

  void _onDone() {
    _clock?.stop();
    _session = null;
    unawaited(_releaseService());
  }

  /// "Cancelar envio".
  void cancel() => _session?.cancel();

  /// Vuelve al inicio desde una pantalla de resultado.
  void reset() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _session = null;
    state = const SendIdle();
  }
}

final NotifierProvider<SendController, SendState> sendProvider =
    NotifierProvider<SendController, SendState>(SendController.new);
