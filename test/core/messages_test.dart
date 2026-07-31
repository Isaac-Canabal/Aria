import 'dart:convert';
import 'dart:typed_data';

import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Codifica y vuelve a decodificar, que es lo que hace el cable.
T roundTrip<T extends ControlMessage>(T message) =>
    ControlMessage.decode(message.encode()) as T;

Uint8List raw(Map<String, Object?> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

const String deviceId = '0123456789abcdef0123456789abcdef';

Matcher throwsFault(ProtocolFault fault) => throwsA(
  isA<ProtocolError>().having(
    (ProtocolError e) => e.fault,
    'fault',
    fault,
  ),
);

void main() {
  group('ida y vuelta', () {
    test('auth_init conserva identificador, canal y payload', () {
      final AuthInit message = roundTrip(
        AuthInit(
          deviceId: deviceId,
          device: 'Pixel de mí',
          platform: DevicePlatform.android,
          channel: plainChannelId,
          payload: Uint8List.fromList(<int>[4, 8, 2, 9, 1, 3]),
        ),
      );

      expect(message.deviceId, deviceId);
      expect(message.device, 'Pixel de mí');
      expect(message.platform, DevicePlatform.android);
      expect(message.channel, 'plain');
      expect(message.payload, <int>[4, 8, 2, 9, 1, 3]);
    });

    test('auth_response, auth_confirm y auth_result', () {
      expect(
        roundTrip(
          AuthResponse(
            deviceId: deviceId,
            device: 'PC de mí',
            platform: DevicePlatform.windows,
            payload: Uint8List(0),
          ),
        ).platform,
        DevicePlatform.windows,
      );
      expect(
        roundTrip(AuthConfirm(payload: Uint8List.fromList(<int>[7]))).payload,
        <int>[7],
      );
      expect(roundTrip(const AuthResult.accepted()).ok, isTrue);

      final AuthResult rejected = roundTrip(
        const AuthResult.rejected(AuthFailure.tooManyAttempts),
      );
      expect(rejected.ok, isFalse);
      expect(rejected.failure, AuthFailure.tooManyAttempts);
    });

    test('manifest lleva los nombres, no solo el conteo', () {
      final Manifest message = roundTrip(
        const Manifest(
          files: <ManifestEntry>[
            ManifestEntry(name: 'Foto_playa.jpg', size: 120),
            ManifestEntry(name: 'Contrato_v2.docx', size: 340),
          ],
          totalBytes: 460,
        ),
      );

      expect(message.files.map((ManifestEntry e) => e.name), <String>[
        'Foto_playa.jpg',
        'Contrato_v2.docx',
      ]);
      expect(message.files.first.size, 120);
      expect(message.totalBytes, 460);
    });

    test('manifest_result y ready pueden rechazar con motivo', () {
      expect(
        roundTrip(
          const ManifestResult.rejected(RejectionReason.insufficientSpace),
        ).reason,
        RejectionReason.insufficientSpace,
      );
      final Ready ready = roundTrip(
        const Ready.rejected(RejectionReason.userDeclined),
      );
      expect(ready.ok, isFalse);
      expect(ready.reason, RejectionReason.userDeclined);
    });

    test('file_header, file_hash, file_done, cancel y session_end', () {
      final FileHeader header = roundTrip(
        const FileHeader(name: 'Presentación_Q3.pdf', size: 13002342),
      );
      expect(header.name, 'Presentación_Q3.pdf');
      expect(header.size, 13002342);
      // v1 no manda huella por adelantado: viaja en el trailer.
      expect(header.sha256, isNull);

      const String digest =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      expect(roundTrip(const FileHash(sha256: digest)).sha256, digest);
      // El campo del header sigue existiendo, reservado para deduplicacion.
      expect(
        roundTrip(
          const FileHeader(name: 'x', size: 1, sha256: digest),
        ).sha256,
        digest,
      );

      final FileDone done = roundTrip(
        const FileDone(
          name: 'x.pdf',
          ok: false,
          failure: FileFailure.checksumMismatch,
        ),
      );
      expect(done.failure, FileFailure.checksumMismatch);

      expect(
        roundTrip(
          const Cancel(
            scope: RejectionScope.file,
            origin: CancelOrigin.local,
          ),
        ).scope,
        RejectionScope.file,
      );
      // El origen no viaja: lo fija quien decodifica.
      expect(
        roundTrip(
          const Cancel(
            scope: RejectionScope.file,
            origin: CancelOrigin.local,
          ),
        ).origin,
        CancelOrigin.remote,
      );

      expect(roundTrip(const SessionEnd()), isA<SessionEnd>());
    });

    test('una plataforma desconocida no rompe la sesion', () {
      final AuthInit message = ControlMessage.decode(
        raw(<String, Object?>{
          'v': protocolVersion,
          'type': 'auth_init',
          'device_id': deviceId,
          'device': 'algo',
          'platform': 'symbian',
          'channel': 'plain',
          'payload': '',
        }),
      ) as AuthInit;
      expect(message.platform, DevicePlatform.unknown);
    });

    test('un identificador que no tiene la forma se rechaza', () {
      // Va derecho a la clave primaria de los pares conocidos.
      for (final String bad in <String>['', 'abc', 'z' * 32, '0' * 31]) {
        expect(
          () => ControlMessage.decode(
            raw(<String, Object?>{
              'v': protocolVersion,
              'type': 'auth_init',
              'device_id': bad,
              'device': 'algo',
              'platform': 'android',
              'channel': 'plain',
              'payload': '',
            }),
          ),
          throwsFault(ProtocolFault.malformedPayload),
        );
      }
    });
  });

  group('validacion', () {
    test('otra version cierra la sesion', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{'v': 2, 'type': 'session_end'}),
        ),
        throwsFault(ProtocolFault.unsupportedVersion),
      );
    });

    test('JSON invalido', () {
      expect(
        () => ControlMessage.decode(Uint8List.fromList(utf8.encode('{nope'))),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });

    test('tipo desconocido', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{'v': protocolVersion, 'type': 'take_over'}),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });

    test('campo con el tipo equivocado', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'ready',
            'ok': 'si',
          }),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });

    test('un sha256 que no es un sha256', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'file_hash',
            'sha256': 'ZZZ',
          }),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'file_header',
            'name': 'x',
            'size': 1,
            'sha256': 'ZZZ',
          }),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });

    test('un tamano negativo', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'file_header',
            'name': 'x',
            'size': -1,
            'sha256': 'a' * 64,
          }),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });

    test('un tamano por encima del techo', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'file_header',
            'name': 'x',
            'size': maxTotalBytes + 1,
            'sha256': 'a' * 64,
          }),
        ),
        throwsFault(ProtocolFault.limitExceeded),
      );
    });

    test('un nombre mas largo que el limite', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'file_header',
            'name': 'x' * (maxFileNameBytes + 1),
            'size': 1,
            'sha256': 'a' * 64,
          }),
        ),
        throwsFault(ProtocolFault.limitExceeded),
      );
    });

    test('un manifiesto con demasiadas entradas', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'manifest',
            'total_bytes': 0,
            'files': <Object>[
              for (int i = 0; i <= maxManifestEntries; i++)
                <String, Object?>{'name': 'f$i', 'size': 0},
            ],
          }),
        ),
        throwsFault(ProtocolFault.limitExceeded),
      );
    });

    test('base64 invalido en un payload', () {
      expect(
        () => ControlMessage.decode(
          raw(<String, Object?>{
            'v': protocolVersion,
            'type': 'auth_confirm',
            'payload': '!!!',
          }),
        ),
        throwsFault(ProtocolFault.malformedPayload),
      );
    });
  });
}
