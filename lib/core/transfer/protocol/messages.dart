/// Los mensajes de control, en JSON UTF-8 dentro de un frame de tipo
/// [FrameType.control].
///
/// El orden en que viajan queda congelado (ver CLAUDE.md). Los campos son
/// aditivos: introducir SPAKE2 llena `payload` con otra cosa, no agrega
/// mensajes ni los reordena.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../data/installation_id.dart' show installationIdBytes;
import '../errors.dart';
import '../peer.dart';
import 'limits.dart';

sealed class ControlMessage {
  const ControlMessage();

  String get type;

  Map<String, Object?> fields();

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'v': protocolVersion,
        'type': type,
        ...fields(),
      }),
    ),
  );

  static ControlMessage decode(Uint8List payload) {
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(payload));
    } on FormatException catch (e) {
      throw ProtocolError(ProtocolFault.malformedPayload, detail: e.message);
    }
    if (raw is! Map<String, Object?>) {
      throw const ProtocolError(
        ProtocolFault.malformedPayload,
        detail: 'la raiz no es un objeto',
      );
    }

    final _Reader r = _Reader(raw);
    if (r.integer('v') != protocolVersion) {
      throw ProtocolError(
        ProtocolFault.unsupportedVersion,
        detail: '${raw['v']}',
      );
    }

    return switch (r.text('type')) {
      'auth_init' => AuthInit(
        deviceId: r.deviceId('device_id'),
        device: r.deviceName('device'),
        platform: DevicePlatform.fromWire(r.text('platform')),
        channel: r.text('channel'),
        payload: r.bytes('payload'),
      ),
      'auth_response' => AuthResponse(
        deviceId: r.deviceId('device_id'),
        device: r.deviceName('device'),
        platform: DevicePlatform.fromWire(r.text('platform')),
        payload: r.bytes('payload'),
      ),
      'auth_confirm' => AuthConfirm(payload: r.bytes('payload')),
      'auth_result' => AuthResult(
        ok: r.boolean('ok'),
        failure: r.optionalEnum('failure', AuthFailure.values),
      ),
      'manifest' => Manifest(
        files: r.manifestEntries('files'),
        totalBytes: r.size('total_bytes'),
      ),
      'manifest_result' => ManifestResult(
        ok: r.boolean('ok'),
        reason: r.optionalEnum('reason', RejectionReason.values),
      ),
      'file_header' => FileHeader(
        name: r.fileName('name'),
        size: r.size('size'),
        sha256: r.optionalDigest('sha256'),
      ),
      'file_hash' => FileHash(sha256: r.digest('sha256')),
      'ready' => Ready(
        ok: r.boolean('ok'),
        reason: r.optionalEnum('reason', RejectionReason.values),
      ),
      'file_done' => FileDone(
        name: r.fileName('name'),
        ok: r.boolean('ok'),
        failure: r.optionalEnum('failure', FileFailure.values),
      ),
      'cancel' => Cancel(
        scope: r.requiredEnum('scope', RejectionScope.values),
        origin: CancelOrigin.remote,
      ),
      'session_end' => const SessionEnd(),
      final String other => throw ProtocolError(
        ProtocolFault.malformedPayload,
        detail: 'tipo desconocido: $other',
      ),
    };
  }
}

/// 1 de 4. Lo manda el emisor al conectar. `payload` lo llena el canal: en
/// v1 es el codigo de 6 digitos en claro; con SPAKE2 sera su elemento
/// publico.
final class AuthInit extends ControlMessage {
  const AuthInit({
    required this.deviceId,
    required this.device,
    required this.platform,
    required this.channel,
    required this.payload,
  });

  /// El identificador estable del emisor: contra esto se empareja, no contra
  /// el nombre ni la IP.
  final String deviceId;

  final String device;
  final DevicePlatform platform;

  /// Identificador del canal: `plain` en v1. Si el receptor no lo implementa
  /// responde [AuthFailure.channelMismatch].
  final String channel;

  final Uint8List payload;

  @override
  String get type => 'auth_init';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'device_id': deviceId,
    'device': device,
    'platform': platform.wire,
    'channel': channel,
    'payload': base64.encode(payload),
  };
}

/// 2 de 4.
final class AuthResponse extends ControlMessage {
  const AuthResponse({
    required this.deviceId,
    required this.device,
    required this.platform,
    required this.payload,
  });

  /// El identificador estable del receptor: el emisor tambien empareja.
  final String deviceId;

  final String device;
  final DevicePlatform platform;
  final Uint8List payload;

  @override
  String get type => 'auth_response';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'device_id': deviceId,
    'device': device,
    'platform': platform.wire,
    'payload': base64.encode(payload),
  };
}

/// 3 de 4.
final class AuthConfirm extends ControlMessage {
  const AuthConfirm({required this.payload});

  final Uint8List payload;

  @override
  String get type => 'auth_confirm';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'payload': base64.encode(payload),
  };
}

/// 4 de 4. El veredicto del receptor.
final class AuthResult extends ControlMessage {
  const AuthResult({required this.ok, this.failure});

  const AuthResult.accepted() : ok = true, failure = null;

  const AuthResult.rejected(AuthFailure this.failure) : ok = false;

  final bool ok;
  final AuthFailure? failure;

  @override
  String get type => 'auth_result';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'ok': ok,
    if (failure != null) 'failure': failure!.name,
  };
}

class ManifestEntry {
  const ManifestEntry({required this.name, required this.size});

  final String name;
  final int size;
}

/// La cola completa, antes de mandar nada: la ventana "Cola de
/// transferencias" tiene que poder pintarla entera de una vez.
final class Manifest extends ControlMessage {
  const Manifest({required this.files, required this.totalBytes});

  final List<ManifestEntry> files;
  final int totalBytes;

  @override
  String get type => 'manifest';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'files': <Object>[
      for (final ManifestEntry entry in files)
        <String, Object?>{'name': entry.name, 'size': entry.size},
    ],
    'total_bytes': totalBytes,
  };
}

/// El receptor contrasta `total_bytes` con el espacio libre aqui, y rechaza
/// la sesion entera antes de empezar en vez de fallar en el archivo 3 de 5.
final class ManifestResult extends ControlMessage {
  const ManifestResult({required this.ok, this.reason});

  const ManifestResult.accepted() : ok = true, reason = null;

  const ManifestResult.rejected(RejectionReason this.reason) : ok = false;

  final bool ok;
  final RejectionReason? reason;

  @override
  String get type => 'manifest_result';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'ok': ok,
    if (reason != null) 'reason': reason!.name,
  };
}

/// Abre un archivo del lote.
final class FileHeader extends ControlMessage {
  const FileHeader({required this.name, required this.size, this.sha256});

  /// Ya saneado por el emisor, y saneado otra vez por el receptor: llega de
  /// un par no confiable.
  final String name;

  final int size;

  /// **v1 siempre manda null.** La huella real viaja al final, en [FileHash],
  /// calculada de forma incremental sobre los bytes que ya se estaban
  /// moviendo. El campo queda reservado para deduplicacion futura: conocer la
  /// huella de antemano permitiria saltarse un archivo que el receptor ya
  /// tiene, y eso si justificaria la lectura extra que cuesta calcularla.
  final String? sha256;

  @override
  String get type => 'file_header';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'name': name,
    'size': size,
    if (sha256 != null) 'sha256': sha256,
  };
}

/// El trailer: la huella de lo que se acaba de enviar, justo antes de que el
/// receptor conteste con [FileDone]. Las dos puntas la calculan mientras
/// mueven los bytes, sin releer nada.
final class FileHash extends ControlMessage {
  const FileHash({required this.sha256});

  /// Hexadecimal en minusculas, 64 caracteres.
  final String sha256;

  @override
  String get type => 'file_hash';

  @override
  Map<String, Object?> fields() => <String, Object?>{'sha256': sha256};
}

/// La respuesta a un `file_header`. Un rechazo salta ese archivo y sigue el
/// siguiente: no mata la sesion.
final class Ready extends ControlMessage {
  const Ready({required this.ok, this.reason});

  const Ready.accepted() : ok = true, reason = null;

  const Ready.rejected(RejectionReason this.reason) : ok = false;

  final bool ok;
  final RejectionReason? reason;

  @override
  String get type => 'ready';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'ok': ok,
    if (reason != null) 'reason': reason!.name,
  };
}

enum FileFailure { checksumMismatch, ioError, cancelled, incomplete }

/// El resultado de un archivo. El resultado de la sesion es la suma de estos.
final class FileDone extends ControlMessage {
  const FileDone({required this.name, required this.ok, this.failure});

  final String name;
  final bool ok;
  final FileFailure? failure;

  @override
  String get type => 'file_done';

  @override
  Map<String, Object?> fields() => <String, Object?>{
    'name': name,
    'ok': ok,
    if (failure != null) 'failure': failure!.name,
  };
}

/// Va en cualquiera de las dos direcciones y en cualquier momento despues del
/// handshake, incluso a mitad de los chunks: para eso el frame lleva su tipo
/// delante de la longitud.
final class Cancel extends ControlMessage {
  const Cancel({required this.scope, required this.origin});

  final RejectionScope scope;

  /// No viaja por el cable: lo fija quien decodifica, que sabe si el mensaje
  /// lo mando el o le llego.
  final CancelOrigin origin;

  @override
  String get type => 'cancel';

  @override
  Map<String, Object?> fields() => <String, Object?>{'scope': scope.name};
}

/// Cierra la sesion de forma explicita, en vez de dejar que el socket muera.
final class SessionEnd extends ControlMessage {
  const SessionEnd();

  @override
  String get type => 'session_end';

  @override
  Map<String, Object?> fields() => const <String, Object?>{};
}

/// Lectura de campos con los limites aplicados antes de construir nada.
class _Reader {
  const _Reader(this.json);

  final Map<String, Object?> json;

  Never _bad(String detail) =>
      throw ProtocolError(ProtocolFault.malformedPayload, detail: detail);

  Never _limit(String detail) =>
      throw ProtocolError(ProtocolFault.limitExceeded, detail: detail);

  String text(String key) {
    final Object? value = json[key];
    if (value is! String) _bad('$key no es texto');
    return value;
  }

  int integer(String key) {
    final Object? value = json[key];
    if (value is! int) _bad('$key no es entero');
    return value;
  }

  bool boolean(String key) {
    final Object? value = json[key];
    if (value is! bool) _bad('$key no es booleano');
    return value;
  }

  Uint8List bytes(String key) {
    try {
      return base64.decode(text(key));
    } on FormatException {
      _bad('$key no es base64');
    }
  }

  /// Tamanos: no negativos y bajo el techo.
  int size(String key) {
    final int value = integer(key);
    if (value < 0) _bad('$key negativo');
    if (value > maxTotalBytes) _limit('$key: $value');
    return value;
  }

  /// Hexadecimal de [installationIdBytes] bytes. Se valida la forma para que
  /// no entre cualquier cosa a la clave primaria de los pares conocidos.
  String deviceId(String key) {
    final String value = text(key);
    if (!RegExp('^[0-9a-f]{${installationIdBytes * 2}}\$').hasMatch(value)) {
      _bad('$key no es un identificador de instalacion');
    }
    return value;
  }

  String deviceName(String key) {
    final String value = text(key);
    if (utf8.encode(value).length > maxFileNameBytes) _limit(key);
    return value;
  }

  String fileName(String key) {
    final String value = text(key);
    if (value.isEmpty) _bad('$key vacio');
    if (utf8.encode(value).length > maxFileNameBytes) _limit(key);
    return value;
  }

  String? optionalDigest(String key) =>
      json[key] == null ? null : digest(key);

  String digest(String key) {
    final String value = text(key);
    if (value.length != 64 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      _bad('$key no es un sha256 hexadecimal');
    }
    return value;
  }

  List<ManifestEntry> manifestEntries(String key) {
    final Object? value = json[key];
    if (value is! List<Object?>) _bad('$key no es una lista');
    if (value.length > maxManifestEntries) {
      _limit('$key: ${value.length} > $maxManifestEntries');
    }
    return <ManifestEntry>[
      for (final Object? item in value)
        if (item is! Map<String, Object?>)
          _bad('$key: entrada que no es objeto')
        else
          ManifestEntry(
            name: _Reader(item).fileName('name'),
            size: _Reader(item).size('size'),
          ),
    ];
  }

  T requiredEnum<T extends Enum>(String key, List<T> values) {
    final String value = text(key);
    for (final T candidate in values) {
      if (candidate.name == value) return candidate;
    }
    _bad('$key desconocido: $value');
  }

  T? optionalEnum<T extends Enum>(String key, List<T> values) {
    if (json[key] == null) return null;
    return requiredEnum(key, values);
  }
}
