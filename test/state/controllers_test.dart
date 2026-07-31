import 'package:syroda/core/data/app_database.dart';
import 'package:syroda/core/data/paired_device.dart';
import 'package:syroda/core/data/preferences.dart';
import 'package:syroda/core/data/transfer_record.dart';
import 'package:syroda/core/transfer/transfer.dart';
import 'package:syroda/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TransferRecord entry(String name) => TransferRecord(
  fileName: name,
  sizeBytes: 10,
  direction: TransferDirection.sent,
  peerName: 'Pixel de Ana',
  peerPlatform: DevicePlatform.android,
  completedAt: DateTime.now().toUtc(),
  status: TransferStatus.completed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = ProviderContainer(
      overrides: <Override>[
        // Una base en memoria por prueba: nada toca el disco de verdad.
        // Cerrarla es obligatorio: `sqflite` cachea por ruta mientras esta
        // abierta, y `:memory:` sin cerrar se filtra a la prueba siguiente.
        databaseProvider.overrideWith((Ref ref) async {
          final Database database = await openAppDatabase(
            path: inMemoryDatabasePath,
          );
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ajustes', () {
    test('carga los valores por defecto', () async {
      final SyrodaSettings settings = await container.read(
        settingsProvider.future,
      );
      expect(settings.visibility, PeerVisibility.everyone);
      expect(settings.deviceName, isNotEmpty);
    });

    test('cambiar el nombre lo persiste', () async {
      await container.read(settingsProvider.future);
      await container
          .read(settingsProvider.notifier)
          .setDeviceName('  PC de mí  ');

      expect(container.read(settingsProvider).requireValue.deviceName, 'PC de mí');
      // Y sigue ahi para el siguiente arranque.
      expect((await SettingsStore.open()).read().deviceName, 'PC de mí');
    });

    test('un nombre en blanco no se acepta', () async {
      final SyrodaSettings before = await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).setDeviceName('   ');
      expect(
        container.read(settingsProvider).requireValue.deviceName,
        before.deviceName,
      );
    });

    test('la identidad sigue al nombre de Ajustes', () async {
      await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).setDeviceName('Pixel 9');

      final DeviceIdentity identity = await container.read(
        deviceIdentityProvider.future,
      );
      expect(identity.name, 'Pixel 9');
      expect(identity.platform, isNot(DevicePlatform.unknown));
      // El identificador estable no depende del nombre.
      expect(identity.id, hasLength(32));
    });

    test('"Nadie" deja de anunciar', () async {
      await container.read(settingsProvider.future);
      expect(container.read(announcingProvider), isTrue);

      await container
          .read(settingsProvider.notifier)
          .setVisibility(PeerVisibility.nobody);
      expect(container.read(announcingProvider), isFalse);

      await container
          .read(settingsProvider.notifier)
          .setVisibility(PeerVisibility.pairedOnly);
      expect(container.read(announcingProvider), isTrue);
    });
  });

  group('emparejados', () {
    test('arranca vacio', () async {
      expect(await container.read(pairedDevicesProvider.future), isEmpty);
      expect(container.read(pairedIdsProvider), isEmpty);
    });

    test('una sesion autorizada empareja al par', () async {
      await container.read(pairedDevicesProvider.future);
      await container
          .read(pairedDevicesProvider.notifier)
          .rememberFrom(
            const SessionAuthorized(
              deviceId: '0123456789abcdef0123456789abcdef',
              device: 'Pixel de Ana',
              platform: DevicePlatform.android,
            ),
          );
      await container.pump();

      final List<PairedDevice> paired = await container.read(
        pairedDevicesProvider.future,
      );
      expect(paired.single.name, 'Pixel de Ana');
      expect(
        container.read(pairedIdsProvider),
        <String>{'0123456789abcdef0123456789abcdef'},
      );
    });

    test('un par sin identificador no se empareja', () async {
      await container.read(pairedDevicesProvider.future);
      await container
          .read(pairedDevicesProvider.notifier)
          .rememberFrom(
            const SessionAuthorized(
              deviceId: '',
              device: 'anonimo',
              platform: DevicePlatform.unknown,
            ),
          );
      await container.pump();

      expect(await container.read(pairedDevicesProvider.future), isEmpty);
    });

    test('olvidar todos los borra', () async {
      await container.read(pairedDevicesProvider.future);
      await container
          .read(pairedDevicesProvider.notifier)
          .rememberFrom(
            const SessionAuthorized(
              deviceId: '0123456789abcdef0123456789abcdef',
              device: 'Pixel de Ana',
              platform: DevicePlatform.android,
            ),
          );
      await container.pump();

      await container.read(pairedDevicesProvider.notifier).forgetAll();
      await container.pump();

      expect(await container.read(pairedDevicesProvider.future), isEmpty);
    });
  });

  group('historial', () {
    test('arranca vacio', () async {
      expect(await container.read(historyProvider.future), isEmpty);
      expect(container.read(historyIsEmptyProvider), isTrue);
    });

    test('registrar una entrada refresca la lista sola', () async {
      await container.read(historyProvider.future);
      await container.read(historyProvider.notifier).record(entry('x.bin'));

      // El repositorio avisa del cambio y el controlador vuelve a consultar.
      await container.pump();
      final List<TransferRecord> entries = await container.read(
        historyProvider.future,
      );
      expect(entries.map((TransferRecord r) => r.fileName), <String>['x.bin']);
      expect(container.read(historyIsEmptyProvider), isFalse);
    });

    test('vaciar el historial lo deja en el estado vacio', () async {
      await container.read(historyProvider.future);
      await container.read(historyProvider.notifier).record(entry('x.bin'));
      await container.pump();
      await container.read(historyProvider.notifier).clear();
      await container.pump();

      expect(await container.read(historyProvider.future), isEmpty);
      expect(container.read(historyIsEmptyProvider), isTrue);
    });
  });
}
