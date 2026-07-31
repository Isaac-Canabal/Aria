/// Los errores de la capa de transporte, modelados como tipos.
///
/// Nada de cadenas: la UI decide el texto en espanol a partir del tipo, y el
/// compilador obliga a cubrir los casos nuevos.
library;

sealed class TransferError implements Exception {
  const TransferError();

  /// Solo para registro y depuracion. La UI no muestra esto.
  String get debugMessage;

  @override
  String toString() => '$runtimeType: $debugMessage';
}

/// El par mando algo que no cumple el formato de cable.
final class ProtocolError extends TransferError {
  const ProtocolError(this.fault, {this.detail});

  final ProtocolFault fault;
  final String? detail;

  @override
  String get debugMessage =>
      detail == null ? fault.name : '${fault.name}: $detail';
}

enum ProtocolFault {
  /// Tipo de frame fuera de los asignados.
  unknownFrameType,

  /// La longitud anunciada supera el limite del tipo de frame.
  frameTooLarge,

  /// El JSON no parsea, o le faltan campos, o son de otro tipo.
  malformedPayload,

  /// El campo `v` no es [protocolVersion].
  unsupportedVersion,

  /// Un mensaje valido, pero no el que tocaba en este punto de la sesion.
  unexpectedMessage,

  /// La conexion se cerro a mitad de un frame.
  truncatedStream,

  /// Un valor supera su limite: nombre, conteo del manifiesto, bytes totales.
  limitExceeded,
}

/// El codigo de emparejamiento no autorizo la sesion.
final class AuthError extends TransferError {
  const AuthError(this.failure);

  final AuthFailure failure;

  @override
  String get debugMessage => failure.name;
}

enum AuthFailure {
  /// El codigo no coincide. Quedan intentos.
  invalidCode,

  /// Se agotaron los intentos: el codigo quedo invalidado y el receptor
  /// genera uno nuevo.
  tooManyAttempts,

  /// El codigo estuvo visible demasiado tiempo sin usarse.
  codeExpired,

  /// El par pide un canal que este extremo no implementa.
  channelMismatch,
}

/// El par rechazo la sesion completa o un archivo, sin que sea un fallo.
final class RejectedByPeer extends TransferError {
  const RejectedByPeer(this.reason, {required this.scope, this.detail});

  final RejectionReason reason;
  final RejectionScope scope;
  final String? detail;

  @override
  String get debugMessage => '${scope.name}/${reason.name}';
}

enum RejectionScope { session, file }

enum RejectionReason {
  /// No cabe: se valida contra el espacio libre al recibir el manifiesto.
  insufficientSpace,

  /// La persona declino.
  userDeclined,

  /// El receptor esta ocupado con otra sesion.
  busy,

  /// El nombre no sobrevivio al saneado, o el archivo no es aceptable.
  unacceptableFile,
}

/// El sha256 recibido no coincide con el anunciado en el `file_header`.
final class IntegrityError extends TransferError {
  const IntegrityError({required this.expected, required this.actual, this.name});

  final String expected;
  final String actual;
  final String? name;

  @override
  String get debugMessage => 'sha256 $name: esperado $expected, recibido $actual';
}

/// Fallo del disco: abrir, escribir, renombrar el `.part`.
final class TransferIoError extends TransferError {
  const TransferIoError(this.path, this.cause);

  final String path;
  final Object cause;

  @override
  String get debugMessage => '$path: $cause';
}

/// Alguno de los dos extremos cancelo.
final class TransferCancelled extends TransferError {
  const TransferCancelled(this.origin, {this.scope = RejectionScope.session});

  final CancelOrigin origin;
  final RejectionScope scope;

  @override
  String get debugMessage => '${origin.name}/${scope.name}';
}

enum CancelOrigin { local, remote }

/// El socket no llego a establecerse o se perdio.
final class ConnectionFailed extends TransferError {
  const ConnectionFailed(this.fault, {this.cause});

  final ConnectionFault fault;
  final Object? cause;

  @override
  String get debugMessage => cause == null ? fault.name : '${fault.name}: $cause';
}

enum ConnectionFault {
  /// Nadie escucha en ese puerto.
  refused,

  /// Se agoto el tiempo. En el emparejamiento manual, este es el sintoma del
  /// aislamiento de clientes del router.
  timeout,

  /// La conexion se cayo a mitad.
  lost,

  /// No hay ruta al par.
  unreachable,
}
