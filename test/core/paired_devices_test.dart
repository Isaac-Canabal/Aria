import 'dart:async';

import 'package:aria/core/data/app_database.dart';
import 'package:aria/core/data/installation_id.dart';
import 'package:aria/core/data/paired_device.dart';
import 'package:aria/core/data/paired_devices_repository.dart';
import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String anaId = '0123456789abcdef0123456789abcdef';
const String luisId = 'fedcba9876543210fedcba9876543210';

PairedDevice device({
  String id = anaId,
  String name = 'Pixel de Ana',
  DevicePlatform platform = DevicePlatform.android,
  DateTime? at,
}) => PairedDevice(
  deviceId: id,
  name: name,
  platform: platform,
  pairedAt: at ?? DateTime.utc(2026, 7, 30, 14, 32),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('identificador de instalacion', () {
    test('tiene 32 caracteres hexadecimales', () {
      expect(generateInstallationId(), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('dos generaciones no coinciden', () {
      expect(generateInstallationId(), isNot(generateInstallationId()));
    });

    test('se crea una vez y no vuelve a cambiar', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String first = await readOrCreateInstallationId(prefs);
      expect(await readOrCreateInstallationId(prefs), first);
      // Y sobrevive a un arranque nuevo.
      expect(
        await readOrCreateInstallationId(await SharedPreferences.getInstance()),
        first,
      );
    });

    test('un valor guardado con mala forma se reemplaza', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.installation_id': 'no-es-un-id',
      });
      final String id = await readOrCreateInstallationId(
        await SharedPreferences.getInstance(),
      );
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('repositorio', () {
    late Database db;
    late PairedDevicesRepository repository;

    setUp(() async {
      db = await openAppDatabase(path: inMemoryDatabasePath);
      repository = PairedDevicesRepository(db);
    });

    tearDown(() async {
      await repository.dispose();
      await db.close();
    });

    test('guarda y encuentra por identificador', () async {
      await repository.remember(device());

      final PairedDevice? found = await repository.find(anaId);
      expect(found?.name, 'Pixel de Ana');
      expect(found?.platform, DevicePlatform.android);
      expect(found?.pairedAt, DateTime.utc(2026, 7, 30, 14, 32));
      expect(await repository.isPaired(anaId), isTrue);
      expect(await repository.isPaired(luisId), isFalse);
    });

    test('un identificador vacio nunca esta emparejado', () async {
      // Un par que no publica identificador no puede colarse como conocido.
      expect(await repository.isPaired(''), isFalse);
    });

    test('renombrar el dispositivo no lo duplica', () async {
      await repository.remember(device());
      await repository.remember(
        device(name: 'Pixel de mí', at: DateTime.utc(2026, 7, 31)),
      );

      final List<PairedDevice> all = await repository.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'Pixel de mí');
      expect(all.single.pairedAt, DateTime.utc(2026, 7, 31));
    });

    test('ordena por emparejamiento mas reciente', () async {
      await repository.remember(device(at: DateTime.utc(2026, 7, 20)));
      await repository.remember(
        device(id: luisId, name: 'PC de Luis', at: DateTime.utc(2026, 7, 30)),
      );

      expect(
        (await repository.all()).map((PairedDevice d) => d.name),
        <String>['PC de Luis', 'Pixel de Ana'],
      );
    });

    test('olvidar uno deja los demas', () async {
      await repository.remember(device());
      await repository.remember(device(id: luisId, name: 'PC de Luis'));

      await repository.forget(anaId);
      expect((await repository.all()).single.deviceId, luisId);
    });

    test('olvidar todos vacia la tabla', () async {
      await repository.remember(device());
      await repository.remember(device(id: luisId, name: 'PC de Luis'));

      await repository.forgetAll();
      expect(await repository.all(), isEmpty);
    });

    test('avisa de cada cambio', () async {
      final List<void> seen = <void>[];
      final StreamSubscription<void> subscription = repository.changes.listen(
        seen.add,
      );

      await repository.remember(device());
      await repository.forget(anaId);
      await repository.forgetAll();
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(3));
      await subscription.cancel();
    });
  });
}
