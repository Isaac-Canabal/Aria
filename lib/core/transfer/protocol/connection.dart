/// La conexion sobre la que corre la sesion: frames de entrada en cola y
/// mensajes de salida.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../errors.dart';
import 'frame.dart';
import 'limits.dart';
import 'messages.dart';

/// Tiempo maximo esperando un mensaje de control del par.
const Duration controlTimeout = Duration(seconds: 30);

/// Lo que se espera a que el cierre se complete antes de forzarlo.
const Duration _lingerTimeout = Duration(seconds: 2);

class ProtocolConnection {
  /// Se suscribe al socket directamente, sin un `async*` de por medio.
  ///
  /// Con un generador intermedio, `cancel()` no se procesa mientras el
  /// generador esta suspendido en su `await for`, y al cerrar las dos puntas
  /// a la vez ya no llega ningun evento que lo despierte: las dos se quedan
  /// esperando para siempre.
  ProtocolConnection(this._socket) {
    _subscription = _socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final FrameParser _parser = FrameParser();
  late final StreamSubscription<Uint8List> _subscription;

  void _onData(Uint8List data) {
    try {
      for (final Frame frame in _parser.add(data)) {
        _onFrame(frame);
      }
    } on TransferError catch (error, stack) {
      _onError(error, stack);
    }
  }

  final Queue<Frame> _ready = Queue<Frame>();
  final Queue<Completer<Frame>> _waiting = Queue<Completer<Frame>>();

  Object? _failure;
  bool _closed = false;

  void _onFrame(Frame frame) {
    if (_waiting.isEmpty) {
      _ready.add(frame);
    } else {
      _waiting.removeFirst().complete(frame);
    }
  }

  void _onError(Object error, StackTrace stack) {
    _failure = error is TransferError
        ? error
        : ConnectionFailed(ConnectionFault.lost, cause: error);
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().completeError(_failure!, stack);
    }
  }

  void _onDone() {
    // Cerrar a mitad de un frame es un cierre a destiempo, no un final limpio.
    _failure ??= _parser.pendingBytes > 0
        ? const ProtocolError(ProtocolFault.truncatedStream)
        : const ConnectionFailed(ConnectionFault.lost);
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().completeError(_failure!);
    }
  }

  /// El siguiente frame, esperando si hace falta.
  Future<Frame> nextFrame({Duration timeout = controlTimeout}) {
    if (_ready.isNotEmpty) return Future<Frame>.value(_ready.removeFirst());
    if (_failure != null) return Future<Frame>.error(_failure!);

    final Completer<Frame> completer = Completer<Frame>();
    _waiting.add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () => throw const ConnectionFailed(ConnectionFault.timeout),
    );
  }

  /// El siguiente frame solo si ya llego. Sirve para atender una cancelacion
  /// del par entre chunk y chunk, sin dejar de enviar mientras tanto.
  Frame? tryNextFrame() => _ready.isEmpty ? null : _ready.removeFirst();

  /// El siguiente mensaje de control, con el tipo que toca.
  ///
  /// Un `cancel` del par se traduce aqui a [TransferCancelled], que es lo que
  /// corresponde en cualquier punto de la sesion.
  Future<T> expect<T extends ControlMessage>({
    Duration timeout = controlTimeout,
  }) async {
    final Frame frame = await nextFrame(timeout: timeout);
    return readControl<T>(frame);
  }

  /// El siguiente mensaje de control, sea cual sea. Para los puntos de la
  /// sesion donde caben dos mensajes distintos: otro `file_header` o el
  /// `session_end` que cierra el lote.
  Future<ControlMessage> expectAny({Duration timeout = controlTimeout}) async {
    final Frame frame = await nextFrame(timeout: timeout);
    return readControl<ControlMessage>(frame);
  }

  /// A mitad de los chunks solo se admite una cancelacion. Cualquier otro
  /// mensaje de control ahi es una violacion del orden congelado.
  static void expectOnlyCancel(Frame frame) =>
      readControl<Cancel>(frame);

  /// Interpreta un frame que deberia ser un mensaje de control de tipo [T].
  static T readControl<T extends ControlMessage>(Frame frame) {
    if (frame.type != FrameType.control) {
      throw const ProtocolError(
        ProtocolFault.unexpectedMessage,
        detail: 'llego un frame de datos donde iba control',
      );
    }
    final ControlMessage message = ControlMessage.decode(frame.payload);
    if (message is Cancel) {
      throw TransferCancelled(CancelOrigin.remote, scope: message.scope);
    }
    if (message is! T) {
      throw ProtocolError(
        ProtocolFault.unexpectedMessage,
        detail: 'llego ${message.type}, se esperaba $T',
      );
    }
    return message;
  }

  void send(ControlMessage message) {
    final Uint8List payload = message.encode();
    if (payload.length > maxControlFrameBytes) {
      throw ProtocolError(
        ProtocolFault.frameTooLarge,
        detail: '${message.type}: ${payload.length}',
      );
    }
    _socket.add(encodeFrame(FrameType.control, payload));
  }

  void sendChunk(List<int> bytes) =>
      _socket.add(encodeFrame(FrameType.chunk, bytes));

  /// Vacia el buffer de salida. Sin esto, cerrar puede perder los ultimos
  /// bytes.
  Future<void> flush() => _socket.flush();

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.flush();
      // Cierre por FIN, no por `destroy`: destruir el socket con datos
      // recien escritos provoca un RST que descarta lo ultimo que se mando,
      // y el par pierde justo el mensaje que explica por que se cerro.
      await _socket
          .close()
          .timeout(_lingerTimeout, onTimeout: () => _socket);
    } on SocketException {
      // La sesion ya termino: que el par se haya ido no cambia el resultado.
    }
    await _subscription.cancel();
    _socket.destroy();
  }
}
