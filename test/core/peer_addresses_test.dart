import 'dart:io';

import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orden de candidatas', () {
    test('la de la misma /24 que una local va primero', () {
      // El caso real: un PC con WSL2 y VPN resuelve a varias, y el telefono
      // solo alcanza la de su propia red.
      expect(
        orderCandidates(
          <String>['172.29.80.1', '10.8.0.6', '192.168.1.10'],
          <String>['192.168.1.7'],
        ),
        <String>['192.168.1.10', '172.29.80.1', '10.8.0.6'],
      );
    });

    test('sin ninguna cercana se respeta el orden de llegada', () {
      expect(
        orderCandidates(
          <String>['172.29.80.1', '10.8.0.6'],
          <String>['192.168.1.7'],
        ),
        <String>['172.29.80.1', '10.8.0.6'],
      );
    });

    test('no descarta nada: ordenar mal cuesta tiempo, no la conexion', () {
      final List<String> candidates = <String>['10.0.0.5', '192.168.1.10'];
      expect(
        orderCandidates(candidates, <String>['172.16.0.1']),
        containsAll(candidates),
      );
      expect(orderCandidates(candidates, const <String>[]), hasLength(2));
    });

    test('varias cercanas mantienen su orden relativo', () {
      expect(
        orderCandidates(
          <String>['10.0.0.5', '192.168.1.10', '192.168.1.11'],
          <String>['192.168.1.7'],
        ),
        <String>['192.168.1.10', '192.168.1.11', '10.0.0.5'],
      );
    });

    test('IPv6 y nombres no rompen el orden: van detras', () {
      expect(
        orderCandidates(
          <String>['fe80::1', 'mi-pc.local', '192.168.1.10'],
          <String>['192.168.1.7'],
        ),
        <String>['192.168.1.10', 'fe80::1', 'mi-pc.local'],
      );
    });

    test('una local que no es IPv4 no arrastra a nadie', () {
      expect(
        orderCandidates(<String>['192.168.1.10'], <String>['fe80::1']),
        <String>['192.168.1.10'],
      );
    });
  });

  group('eleccion al conectar', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() => server.close());

    SendSession session(List<String> addresses, {List<String>? locals}) =>
        SendSession(
          addresses: addresses,
          port: server.port,
          identity: DeviceIdentity(
            id: '0123456789abcdef0123456789abcdef',
            name: 'Pixel',
            platform: DevicePlatform.android,
          ),
          channel: PlainChannelInitiator('123456'),
          files: const <OutgoingFile>[],
          attemptTimeout: const Duration(milliseconds: 300),
          localAddresses: locals == null ? null : () async => locals,
        );

    test('una direccion muerta no impide usar la buena', () async {
      // Lo que se comprueba es que el socket llega a abrirse en la segunda
      // candidata. Lo que pase despues da igual: este servidor no habla el
      // protocolo, asi que la sesion va a fallar de todas formas.
      int accepted = 0;
      server.listen((Socket socket) {
        accepted++;
        socket.destroy();
      });

      // La direccion muerta va primera a proposito: sin probar la siguiente,
      // el par quedaba visible y no conectable.
      final SendSession sender = session(<String>[
        '192.0.2.1', // TEST-NET-1, reservada: no responde nadie
        InternetAddress.loopbackIPv4.address,
      ]);
      try {
        await sender.run().toList();
      } on TransferError {
        // Esperado: el servidor de este test no completa el handshake.
      }

      expect(accepted, 1);
    });

    test('sin ninguna alcanzable falla como conexion, no como otra cosa', () {
      final SendSession sender = session(<String>['192.0.2.1', '192.0.2.2']);
      expect(sender.run().toList(), throwsA(isA<ConnectionFailed>()));
    });

    test('una lista vacia no llega a abrir socket', () {
      expect(
        session(const <String>[]).run().toList(),
        throwsA(isA<ConnectionFailed>()),
      );
    });
  });
}
