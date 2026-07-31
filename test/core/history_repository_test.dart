import 'dart:async';

import 'package:aria/core/data/app_database.dart';
import 'package:aria/core/data/history_repository.dart';
import 'package:aria/core/data/transfer_record.dart';
import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TransferRecord entry({
  String name = 'Foto_playa.jpg',
  TransferDirection direction = TransferDirection.sent,
  TransferStatus status = TransferStatus.completed,
  DateTime? at,
  int size = 1200,
  FileFailure? failure,
  String? localPath,
}) => TransferRecord(
  fileName: name,
  sizeBytes: size,
  direction: direction,
  peerName: 'Pixel de Ana',
  peerPlatform: DevicePlatform.android,
  completedAt: at ?? DateTime.utc(2026, 7, 30, 14, 32),
  status: status,
  failure: failure,
  localPath: localPath,
);

void main() {
  late Database db;
  late HistoryRepository repository;

  setUp(() async {
    db = await openAppDatabase(path: inMemoryDatabasePath);
    repository = HistoryRepository(db);
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  test('guarda y devuelve una entrada intacta', () async {
    final TransferRecord saved = await repository.add(
      entry(localPath: r'C:\Users\ana\Downloads\Foto_playa.jpg'),
    );
    expect(saved.id, isNotNull);

    final TransferRecord read = (await repository.recent()).single;
    expect(read.id, saved.id);
    expect(read.fileName, 'Foto_playa.jpg');
    expect(read.sizeBytes, 1200);
    expect(read.direction, TransferDirection.sent);
    expect(read.peerName, 'Pixel de Ana');
    expect(read.peerPlatform, DevicePlatform.android);
    expect(read.status, TransferStatus.completed);
    expect(read.completedAt, DateTime.utc(2026, 7, 30, 14, 32));
    expect(read.completedAt.isUtc, isTrue);
    expect(read.localPath, r'C:\Users\ana\Downloads\Foto_playa.jpg');
  });

  test('conserva el motivo del fallo', () async {
    await repository.add(
      entry(
        status: TransferStatus.failed,
        failure: FileFailure.checksumMismatch,
      ),
    );
    expect(
      (await repository.recent()).single.failure,
      FileFailure.checksumMismatch,
    );
  });

  test('ordena por fecha descendente', () async {
    await repository.add(entry(name: 'ayer', at: DateTime.utc(2026, 7, 29)));
    await repository.add(entry(name: 'hoy', at: DateTime.utc(2026, 7, 30)));
    await repository.add(
      entry(name: 'anteayer', at: DateTime.utc(2026, 7, 28)),
    );

    expect(
      (await repository.recent()).map((TransferRecord r) => r.fileName),
      <String>['hoy', 'ayer', 'anteayer'],
    );
  });

  test('respeta el limite de pagina', () async {
    for (int i = 0; i < 5; i++) {
      await repository.add(
        entry(name: 'f$i', at: DateTime.utc(2026, 7, 30, i)),
      );
    }
    expect(await repository.recent(limit: 2), hasLength(2));
    expect(await repository.count(), 5);
  });

  test('borra una entrada y todas', () async {
    final TransferRecord saved = await repository.add(entry());
    await repository.add(entry(name: 'otra'));

    await repository.remove(saved.id!);
    expect(await repository.count(), 1);

    await repository.clear();
    expect(await repository.recent(), isEmpty);
  });

  test('avisa de cada cambio', () async {
    final List<void> seen = <void>[];
    final StreamSubscription<void> subscription = repository.changes.listen(
      seen.add,
    );

    await repository.add(entry());
    await repository.clear();
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(2));
    await subscription.cancel();
  });
}
