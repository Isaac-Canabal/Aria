/// El canal que ocupa el handshake de cuatro mensajes.
///
/// INVARIANTE: en v1 el canal es pass-through. Difiere el **cifrado**, nunca
/// la **autorizacion**: el codigo de 6 digitos se verifica de verdad aqui, y
/// [TransferSession] rechaza la sesion si no coincide.
///
/// El handshake tiene cuatro mensajes fijos (auth_init, auth_response,
/// auth_confirm, auth_result) cuyo contenido llena esta interfaz. Introducir
/// SPAKE2 es escribir otra implementacion: los mismos cuatro mensajes pasan a
/// llevar el elemento publico de cada lado y los MAC de confirmacion. Ni la
/// forma del header ni el orden de los mensajes cambian.
///
/// INVARIANTE: mientras [PlainChannelInitiator] y [PlainChannelResponder]
/// sean los unicos canales, ninguna superficie de UI puede afirmar cifrado.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'pairing_service.dart';

/// Identificador que viaja en `auth_init.channel`.
const String plainChannelId = 'plain';

/// Lado emisor.
abstract interface class ChannelInitiator {
  String get id;

  /// Payload de `auth_init`.
  Uint8List init();

  /// Payload de `auth_confirm`, a partir del de `auth_response`.
  Uint8List confirm(Uint8List responsePayload);

  /// Envuelve un trozo de archivo antes de mandarlo. Identidad en v1.
  List<int> seal(List<int> plain);
}

/// Lado receptor.
abstract interface class ChannelResponder {
  String get id;

  /// Payload de `auth_response`, a partir del de `auth_init`.
  Uint8List respond(Uint8List initPayload);

  /// Ultimo paso: decide el `auth_result`. Lanza [AuthError] si la
  /// autorizacion no cuadra.
  void verifyConfirm(Uint8List confirmPayload);

  /// Desenvuelve un trozo recibido. Identidad en v1.
  List<int> open(List<int> sealed);
}

/// v1: el codigo viaja en claro dentro de `auth_init`.
class PlainChannelInitiator implements ChannelInitiator {
  PlainChannelInitiator(this.code);

  /// Los seis digitos, sin el espacio de lectura.
  final String code;

  @override
  String get id => plainChannelId;

  @override
  Uint8List init() => Uint8List.fromList(utf8.encode(code));

  @override
  Uint8List confirm(Uint8List responsePayload) => Uint8List(0);

  @override
  List<int> seal(List<int> plain) => plain;
}

/// v1: verifica el codigo contra [PairingService], que cuenta los intentos y
/// compara en tiempo constante.
class PlainChannelResponder implements ChannelResponder {
  PlainChannelResponder(this.pairing);

  final PairingService pairing;

  AuthFailure? _pending;

  @override
  String get id => plainChannelId;

  @override
  Uint8List respond(Uint8List initPayload) {
    final String candidate;
    try {
      candidate = utf8.decode(initPayload);
    } on FormatException {
      _pending = AuthFailure.invalidCode;
      return Uint8List(0);
    }

    // El veredicto se guarda y se comunica en el cuarto mensaje: el orden de
    // los cuatro es fijo y no se acorta porque este canal no lo necesite.
    _pending = switch (pairing.verify(candidate)) {
      PairingOutcome.accepted => null,
      PairingOutcome.invalidCode => AuthFailure.invalidCode,
      PairingOutcome.tooManyAttempts => AuthFailure.tooManyAttempts,
      PairingOutcome.expired => AuthFailure.codeExpired,
    };
    return Uint8List(0);
  }

  @override
  void verifyConfirm(Uint8List confirmPayload) {
    final AuthFailure? failure = _pending;
    if (failure != null) throw AuthError(failure);
  }

  @override
  List<int> open(List<int> sealed) => sealed;
}
