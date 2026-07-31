import 'dart:async';

import 'package:syroda/core/platform/permissions.dart';
import 'package:syroda/core/transfer/transfer.dart';
import 'package:syroda/design/nocturne.dart';
import 'package:syroda/features/send/send_screen.dart';
import 'package:syroda/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fonts.dart';

/// Nunca emite un par: es el descubrimiento que no encuentra a nadie.
class _EmptyDiscoveryService implements DiscoveryService {
  final StreamController<List<Peer>> _peers =
      StreamController<List<Peer>>.broadcast();

  @override
  Stream<List<Peer>> get peers => _peers.stream;

  @override
  void excludeSelf(String deviceId) {}

  @override
  Future<void> announce({
    required DeviceIdentity identity,
    required int port,
  }) async {}

  @override
  Future<void> stopAnnouncing() async {}

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> dispose() async => _peers.close();
}

class _GrantedPermissionService implements PermissionService {
  @override
  Future<PermissionOutcome> status(SyrodaPermission permission) async =>
      PermissionOutcome.granted;

  @override
  Future<PermissionOutcome> request(SyrodaPermission permission) async =>
      PermissionOutcome.granted;

  @override
  Future<void> openSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _EmptyDiscoveryService discovery;

  setUp(() {
    // `peersProvider` resuelve la identidad antes de descubrir, para poder
    // excluirse a si mismo: sin esto no llega a arrancar el descubrimiento.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    discovery = _EmptyDiscoveryService();
  });
  tearDown(() => discovery.dispose());

  Future<void> pumpSendScreen(WidgetTester tester) async {
    await loadInter(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          discoveryServiceProvider.overrideWithValue(discovery),
          permissionServiceProvider.overrideWithValue(
            _GrantedPermissionService(),
          ),
        ],
        child: MaterialApp(theme: nocturneTheme(), home: const SendScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('antes del grace period solo muestra que esta buscando', (
    WidgetTester tester,
  ) async {
    await pumpSendScreen(tester);

    expect(find.text('Buscando más dispositivos…'), findsOneWidget);
    expect(find.text('No aparece nadie'), findsNothing);
    expect(find.text('Conectar manualmente'), findsNothing);
  });

  testWidgets(
    'tras el grace period sin pares gana la accion de conectar manualmente',
    (WidgetTester tester) async {
      await pumpSendScreen(tester);

      await tester.pump(discoveryGracePeriod + const Duration(seconds: 1));

      expect(find.text('No aparece nadie'), findsOneWidget);
      expect(find.text('Conectar manualmente'), findsOneWidget);
      // La explicacion no promete que el manual vaya a funcionar.
      expect(find.textContaining('aislamiento de clientes'), findsOneWidget);
      expect(find.textContaining('hotspot'), findsOneWidget);
      // La fila de busqueda se reemplaza, no se acumula con el aviso.
      expect(find.text('Buscando más dispositivos…'), findsNothing);
    },
  );

  testWidgets('un par que llega antes del grace period evita el estado vacio', (
    WidgetTester tester,
  ) async {
    await pumpSendScreen(tester);

    discovery._peers.add(<Peer>[
      Peer.at(
        host: '192.168.1.5',
        serviceName: 'pixel',
        deviceId: 'abc',
        name: 'Pixel de Ana',
        platform: DevicePlatform.android,
        port: 4000,
      ),
    ]);
    await tester.pump();

    await tester.pump(discoveryGracePeriod + const Duration(seconds: 1));

    expect(find.text('Pixel de Ana'), findsOneWidget);
    expect(find.text('No aparece nadie'), findsNothing);
    expect(find.text('Conectar manualmente'), findsNothing);
  });
}
