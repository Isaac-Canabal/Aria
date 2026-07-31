/// Las dos mitades de una sesion: [SendSession] y [ReceiveServer].
///
/// El orden de los mensajes esta congelado y documentado en CLAUDE.md. Este
/// archivo es su unica implementacion.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'errors.dart';
import 'files.dart';
import 'peer.dart';
import 'protocol/connection.dart';
import 'protocol/file_name.dart';
import 'protocol/frame.dart';
import 'protocol/limits.dart';
import 'protocol/messages.dart';
import 'secure_channel.dart';
import 'session_events.dart';

/// El emisor. Se conecta, autoriza, acuerda el lote y lo manda.
class SendSession {
  SendSession({
    required this.addresses,
    required this.port,
    required this.identity,
    required this.channel,
    required this.files,
    this.connectTimeout = const Duration(seconds: 10),
    this.attemptTimeout = const Duration(seconds: 3),
    this.localAddresses,
  });

  /// Las direcciones candidatas del par, sin ordenar. Ver [orderCandidates].
  final List<String> addresses;

  final int port;
  final DeviceIdentity identity;
  final ChannelInitiator channel;
  final List<OutgoingFile> files;

  /// Lo que se espera cuando solo hay una candidata: no hay a que pasar.
  final Duration connectTimeout;

  /// Lo que se espera por candidata cuando hay varias. Corto a proposito:
  /// agotar el timeout largo en una direccion muerta deja la pantalla colgada
  /// mucho mas tiempo del que cuesta probar la siguiente.
  final Duration attemptTimeout;

  /// Las direcciones de este equipo, para el orden. Inyectable para poder
  /// probar el orden sin tocar las interfaces reales.
  final Future<List<String>> Function()? localAddresses;

  ProtocolConnection? _connection;
  bool _cancelled = false;
  bool _cancelSent = false;

  /// Prueba las direcciones candidatas en orden y se queda con la primera
  /// que abre.
  ///
  /// **Secuencial, no en paralelo, a proposito**: el receptor acepta lo que
  /// le llegue, asi que abrir varias a la vez le crearia varias sesiones para
  /// un solo envio. Vale mas esperar un poco que ensuciar la otra punta.
  Future<Socket> _connect() async {
    final List<String> candidates = orderCandidates(
      addresses,
      await localAddresses?.call() ?? const <String>[],
    );
    if (candidates.isEmpty) {
      throw const ConnectionFailed(ConnectionFault.unreachable);
    }
    // Con una sola candidata no hay a que pasar: se le da el tiempo entero.
    final Duration each = candidates.length == 1
        ? connectTimeout
        : attemptTimeout;

    SocketException? last;
    for (final String candidate in candidates) {
      try {
        return await Socket.connect(candidate, port, timeout: each);
      } on SocketException catch (e) {
        last = e;
      }
    }
    throw ConnectionFailed(_faultOf(last!), cause: last);
  }

  /// Corre la sesion entera. Termina con [SessionFinished], o con un
  /// [TransferError] tipado.
  Stream<SessionEvent> run() async* {
    final Socket socket = await _connect();

    final ProtocolConnection connection = ProtocolConnection(socket);
    _connection = connection;
    try {
      yield* _handshake(connection);

      final List<ManifestEntry> entries = <ManifestEntry>[
        for (final OutgoingFile file in files)
          ManifestEntry(name: file.name, size: file.size),
      ];
      final int total = files.fold<int>(
        0,
        (int sum, OutgoingFile file) => sum + file.size,
      );

      connection.send(Manifest(files: entries, totalBytes: total));
      final ManifestResult result = await connection.expect<ManifestResult>();
      if (!result.ok) {
        throw RejectedByPeer(
          result.reason ?? RejectionReason.userDeclined,
          scope: RejectionScope.session,
        );
      }
      yield SessionManifest(entries, totalBytes: total);

      final _Tally tally = _Tally();
      for (int i = 0; i < files.length; i++) {
        yield* _sendFile(
          connection,
          files[i],
          index: i,
          sessionTotal: total,
          tally: tally,
        );
      }

      connection.send(const SessionEnd());
      await connection.flush();
      yield SessionFinished(completed: tally.completed, total: files.length);
    } finally {
      await connection.close();
      _connection = null;
    }
  }

  /// Los cuatro mensajes del handshake, en orden. El contenido de `payload`
  /// lo pone el canal; aqui solo se respeta la secuencia.
  Stream<SessionEvent> _handshake(ProtocolConnection connection) async* {
    connection.send(
      AuthInit(
        deviceId: identity.id,
        device: identity.name,
        platform: identity.platform,
        channel: channel.id,
        payload: channel.init(),
      ),
    );
    final AuthResponse response = await connection.expect<AuthResponse>();
    connection.send(AuthConfirm(payload: channel.confirm(response.payload)));
    final AuthResult result = await connection.expect<AuthResult>();
    if (!result.ok) {
      throw AuthError(result.failure ?? AuthFailure.invalidCode);
    }
    yield SessionAuthorized(
      deviceId: response.deviceId,
      device: response.device,
      platform: response.platform,
    );
  }

  Stream<SessionEvent> _sendFile(
    ProtocolConnection connection,
    OutgoingFile file, {
    required int index,
    required int sessionTotal,
    required _Tally tally,
  }) async* {
    // sha256 va nulo: la huella viaja al final, en `file_hash`.
    connection.send(FileHeader(name: file.name, size: file.size));
    final Ready ready = await connection.expect<Ready>();
    if (!ready.ok) {
      yield FileFinished(
        name: file.name,
        index: index,
        rejection: ready.reason ?? RejectionReason.userDeclined,
      );
      return;
    }

    yield FileStarted(name: file.name, index: index, size: file.size);

    int sent = 0;
    final IncrementalSha256 digest = IncrementalSha256();
    await for (final List<int> chunk in _rechunk(file.open(), chunkBytes)) {
      _throwIfCancelled(connection);

      // Atender una cancelacion del par sin dejar de enviar mientras tanto.
      final Frame? pending = connection.tryNextFrame();
      if (pending != null) ProtocolConnection.expectOnlyCancel(pending);

      // La huella se acumula sobre el mismo trozo que se esta enviando: ni
      // una lectura extra del archivo.
      digest.add(chunk);
      connection.sendChunk(channel.seal(chunk));
      sent += chunk.length;
      tally.sessionBytes += chunk.length;
      yield FileProgress(
        name: file.name,
        index: index,
        bytes: sent,
        size: file.size,
        sessionBytes: tally.sessionBytes,
        sessionTotal: sessionTotal,
      );
    }
    connection.send(FileHash(sha256: digest.finish()));
    await connection.flush();

    final FileDone done = await connection.expect<FileDone>();
    if (done.ok) tally.completed++;
    yield FileFinished(
      name: file.name,
      index: index,
      failure: done.ok ? null : (done.failure ?? FileFailure.ioError),
    );
  }

  void _throwIfCancelled(ProtocolConnection connection) {
    if (!_cancelled) return;
    _announceCancel(connection);
    throw const TransferCancelled(CancelOrigin.local);
  }

  void _announceCancel(ProtocolConnection connection) {
    if (_cancelSent) return;
    _cancelSent = true;
    connection.send(
      const Cancel(scope: RejectionScope.session, origin: CancelOrigin.local),
    );
  }

  /// Corta la sesion. Se hace efectivo en el siguiente chunk.
  void cancel() {
    _cancelled = true;
    final ProtocolConnection? connection = _connection;
    if (connection != null) _announceCancel(connection);
  }
}

class _Tally {
  int sessionBytes = 0;
  int completed = 0;
}

/// El receptor. Escucha en el puerto que le dio el sistema con `bind(0)`, que
/// es el que hay que publicar en el TXT del anuncio.
class ReceiveServer {
  ReceiveServer._(this._server, this._identity, this._responder, this._policy) {
    _subscription = _server.listen(_accept, onError: _events.addError);
  }

  static Future<ReceiveServer> bind({
    required DeviceIdentity identity,
    required ChannelResponder responder,
    required ReceivePolicy policy,
    InternetAddress? address,
  }) async {
    // Puerto 0: lo asigna el sistema. Nada puede asumir un numero fijo.
    final ServerSocket server = await ServerSocket.bind(
      address ?? InternetAddress.anyIPv4,
      0,
    );
    return ReceiveServer._(server, identity, responder, policy);
  }

  final ServerSocket _server;
  final DeviceIdentity _identity;
  final ChannelResponder _responder;
  final ReceivePolicy _policy;

  late final StreamSubscription<Socket> _subscription;
  final StreamController<SessionEvent> _events =
      StreamController<SessionEvent>.broadcast();

  ProtocolConnection? _current;

  bool _accepting = true;

  /// Deja de aceptar conexiones **nuevas** sin cerrar el socket de escucha.
  ///
  /// La sesion en vuelo no se toca: sigue hasta terminar, que es para lo que
  /// existe el servicio en primer plano. Cerrar el `ServerSocket` la mataria.
  void setAccepting(bool value) => _accepting = value;

  bool get accepting => _accepting;

  /// La sesion que se este atendiendo. [close] la espera: si no, el receptor
  /// puede seguir escribiendo en disco despues de que lo den por cerrado.
  Future<void>? _inFlight;

  /// El puerto efimero asignado. Va en el TXT del anuncio, junto al nombre y
  /// la plataforma.
  int get port => _server.port;

  Stream<SessionEvent> get events => _events.stream;

  void _accept(Socket socket) {
    // Con la app en background no se acepta nada nuevo: autorizar una sesion
    // que el proceso no puede sostener deja el archivo a medias.
    if (!_accepting) {
      socket.destroy();
      return;
    }
    _inFlight = _handle(socket);
  }

  Future<void> _handle(Socket socket) async {
    final ProtocolConnection connection = ProtocolConnection(socket);
    // Una sesion a la vez: la segunda se autoriza igual, pero se le rechaza
    // el manifiesto con `busy`.
    final bool busy = _current != null;
    if (!busy) _current = connection;

    try {
      await for (final SessionEvent event in _session(connection, busy: busy)) {
        _events.add(event);
      }
    } on TransferError catch (error, stack) {
      _events.addError(error, stack);
    } finally {
      await connection.close();
      if (identical(_current, connection)) _current = null;
    }
  }

  Stream<SessionEvent> _session(
    ProtocolConnection connection, {
    required bool busy,
  }) async* {
    final AuthInit init = await connection.expect<AuthInit>();
    if (init.channel != _responder.id) {
      connection.send(const AuthResult.rejected(AuthFailure.channelMismatch));
      await connection.flush();
      throw const AuthError(AuthFailure.channelMismatch);
    }

    connection.send(
      AuthResponse(
        deviceId: _identity.id,
        device: _identity.name,
        platform: _identity.platform,
        payload: _responder.respond(init.payload),
      ),
    );
    final AuthConfirm confirm = await connection.expect<AuthConfirm>();
    try {
      _responder.verifyConfirm(confirm.payload);
    } on AuthError catch (error) {
      connection.send(AuthResult.rejected(error.failure));
      await connection.flush();
      rethrow;
    }
    connection.send(const AuthResult.accepted());
    yield SessionAuthorized(
      deviceId: init.deviceId,
      device: init.device,
      platform: init.platform,
    );

    final Manifest manifest = await connection.expect<Manifest>();
    final RejectionReason? rejection = busy
        ? RejectionReason.busy
        : await _policy.reviewManifest(manifest);
    if (rejection != null) {
      connection.send(ManifestResult.rejected(rejection));
      await connection.flush();
      throw RejectedByPeer(rejection, scope: RejectionScope.session);
    }
    connection.send(const ManifestResult.accepted());
    yield SessionManifest(manifest.files, totalBytes: manifest.totalBytes);

    final Directory destination = await _policy.destination();
    final _Tally tally = _Tally();
    int index = 0;

    while (true) {
      final ControlMessage message = await connection.expectAny();
      if (message is SessionEnd) {
        yield SessionFinished(completed: tally.completed, total: index);
        return;
      }
      if (message is! FileHeader) {
        throw ProtocolError(
          ProtocolFault.unexpectedMessage,
          detail: 'llego ${message.type} donde iba file_header o session_end',
        );
      }

      final RejectionReason? fileRejection = await _policy.reviewFile(message);
      if (fileRejection != null) {
        connection.send(Ready.rejected(fileRejection));
        yield FileFinished(
          name: message.name,
          index: index,
          rejection: fileRejection,
        );
        index++;
        continue;
      }

      connection.send(const Ready.accepted());
      yield FileStarted(name: message.name, index: index, size: message.size);
      yield* _receiveFile(
        connection,
        message,
        destination: destination,
        index: index,
        sessionTotal: manifest.totalBytes,
        tally: tally,
      );
      index++;
    }
  }

  /// Escribe en `<nombre>.part` y solo renombra tras verificar el sha256. Un
  /// checksum que no cuadra borra el parcial: nunca queda un archivo con el
  /// nombre definitivo y el contenido a medias.
  Stream<SessionEvent> _receiveFile(
    ProtocolConnection connection,
    FileHeader header, {
    required Directory destination,
    required int index,
    required int sessionTotal,
    required _Tally tally,
  }) async* {
    // Saneado otra vez de este lado: el nombre viene de un par no confiable.
    final String safe = uniqueFileName(
      sanitizeFileName(header.name),
      (String candidate) => File(
        '${destination.path}${Platform.pathSeparator}$candidate',
      ).existsSync(),
    );
    final String finalPath =
        '${destination.path}${Platform.pathSeparator}$safe';
    final File partial = File('$finalPath.part');

    final IncrementalSha256 digest = IncrementalSha256();
    IOSink? out;
    int received = 0;
    FileFailure? failure;

    try {
      out = partial.openWrite();
      while (received < header.size) {
        final Frame frame = await connection.nextFrame();
        if (frame.type != FrameType.chunk) {
          ProtocolConnection.expectOnlyCancel(frame);
        }

        final List<int> plain = _responder.open(frame.payload);
        received += plain.length;
        if (received > header.size) {
          throw const ProtocolError(
            ProtocolFault.limitExceeded,
            detail: 'llegaron mas bytes que los anunciados',
          );
        }

        digest.add(plain);
        out.add(plain);
        tally.sessionBytes += plain.length;
        yield FileProgress(
          name: safe,
          index: index,
          bytes: received,
          size: header.size,
          sessionBytes: tally.sessionBytes,
          sessionTotal: sessionTotal,
        );
      }

      await out.flush();
      await out.close();
      out = null;

      // El trailer cierra el archivo: hasta compararlo, lo que hay en disco
      // es un `.part` y nada mas.
      final FileHash trailer = await connection.expect<FileHash>();
      if (digest.finish() != trailer.sha256) {
        await _deleteQuietly(partial);
        failure = FileFailure.checksumMismatch;
      } else {
        await partial.rename(finalPath);
      }
    } on TransferError {
      await out?.close();
      await _deleteQuietly(partial);
      rethrow;
    } on FileSystemException {
      await out?.close();
      await _deleteQuietly(partial);
      failure = FileFailure.ioError;
    }

    connection.send(
      FileDone(name: header.name, ok: failure == null, failure: failure),
    );
    if (failure == null) tally.completed++;
    yield FileFinished(
      name: safe,
      index: index,
      failure: failure,
      path: failure == null ? finalPath : null,
    );
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Un parcial que no se pudo borrar no cambia el resultado.
    }
  }

  /// Corta la sesion en curso, si la hay.
  void cancel() => _current?.send(
    const Cancel(scope: RejectionScope.session, origin: CancelOrigin.local),
  );

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close();
    await _current?.close();
    try {
      await _inFlight?.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // La sesion no solto: cerrar igual, el socket ya esta destruido.
    }
    if (!_events.isClosed) await _events.close();
  }
}

ConnectionFault _faultOf(SocketException e) {
  final int? code = e.osError?.errorCode;
  return switch (code) {
    // Windows (WSAE*) y errno de Linux/Android.
    10061 || 111 => ConnectionFault.refused,
    10060 || 110 => ConnectionFault.timeout,
    10065 || 113 => ConnectionFault.unreachable,
    _ => ConnectionFault.lost,
  };
}

/// Reparte el flujo de origen en trozos de [size] bytes exactos, salvo el
/// ultimo: `openRead` entrega lo que le da la gana segun el disco.
Stream<List<int>> _rechunk(Stream<List<int>> source, int size) async* {
  final BytesBuilder buffer = BytesBuilder(copy: false);
  await for (final List<int> data in source) {
    buffer.add(data);
    if (buffer.length < size) continue;

    final Uint8List taken = buffer.takeBytes();
    int offset = 0;
    while (taken.length - offset >= size) {
      yield Uint8List.sublistView(taken, offset, offset + size);
      offset += size;
    }
    if (offset < taken.length) {
      buffer.add(Uint8List.sublistView(taken, offset));
    }
  }
  if (buffer.length > 0) yield buffer.takeBytes();
}
