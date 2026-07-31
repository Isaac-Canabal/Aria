import 'dart:io';

import 'package:syroda/core/data/app_database.dart';
import 'package:syroda/core/data/history_repository.dart';
import 'package:syroda/core/data/paired_device.dart';
import 'package:syroda/core/data/paired_devices_repository.dart';
import 'package:syroda/core/data/transfer_record.dart';
import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La migracion se prueba sobre archivo: una base en memoria nace nueva en
/// cada apertura y nunca ejecutaria `onUpgrade`.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('syroda_db');
    path = p.join(dir.path, 'syroda.db');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('una base en v1 llega al dia sin perder el historial', () async {
    // Una instalacion vieja: solo la tabla de transferencias.
    final Database old = await openAppDatabase(path: path, version: 1);
    expect(await old.getVersion(), 1);
    await HistoryRepository(old).add(
      TransferRecord(
        fileName: 'Reporte_final.pdf',
        sizeBytes: 4096,
        direction: TransferDirection.received,
        peerName: 'PC de Luis',
        peerPlatform: DevicePlatform.windows,
        completedAt: DateTime.utc(2026, 7, 29, 19, 10),
        status: TransferStatus.completed,
      ),
    );
    await old.close();

    // La app de hoy abre esa misma base.
    final Database migrated = await openAppDatabase(path: path);
    expect(await migrated.getVersion(), schemaVersion);

    // El historial de la persona sigue ahi. Borrar la base no es una opcion.
    final TransferRecord kept = (await HistoryRepository(
      migrated,
    ).recent()).single;
    expect(kept.fileName, 'Reporte_final.pdf');
    expect(kept.completedAt, DateTime.utc(2026, 7, 29, 19, 10));
    expect(kept.peerPlatform, DevicePlatform.windows);

    // Y la tabla nueva ya existe y funciona.
    expect(await PairedDevicesRepository(migrated).all(), isEmpty);
    await migrated.close();
  });

  test('una base nueva nace en la version actual con todo el esquema', () async {
    final Database db = await openAppDatabase(path: path);
    expect(await db.getVersion(), schemaVersion);

    final List<Map<String, Object?>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final Set<String> names = <String>{
      for (final Map<String, Object?> row in tables) row['name']! as String,
    };
    expect(names, containsAll(<String>['transfers', 'paired_devices']));
    await db.close();
  });

  test('abrir dos veces no vuelve a correr las migraciones', () async {
    final Database first = await openAppDatabase(path: path);
    await PairedDevicesRepository(first).remember(
      PairedDevice(
        deviceId: '0123456789abcdef0123456789abcdef',
        name: 'Pixel de Ana',
        platform: DevicePlatform.android,
        pairedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    await first.close();

    final Database second = await openAppDatabase(path: path);
    expect(await PairedDevicesRepository(second).all(), hasLength(1));
    await second.close();
  });
}
