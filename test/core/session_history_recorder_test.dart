import 'package:aria/core/data/app_database.dart';
import 'package:aria/core/data/history_repository.dart';
import 'package:aria/core/data/session_history_recorder.dart';
import 'package:aria/core/data/transfer_record.dart';
import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const List<SessionEvent> _upToManifest = <SessionEvent>[
  SessionAuthorized(
    deviceId: '0123456789abcdef0123456789abcdef',
    device: 'Pixel de Ana',
    platform: DevicePlatform.android,
  ),
  SessionManifest(
    <ManifestEntry>[
      ManifestEntry(name: 'Foto_playa.jpg', size: 1200),
      ManifestEntry(name: 'Contrato_v2.docx', size: 800),
    ],
    totalBytes: 2000,
  ),
];

void main() {
  late Database db;
  late HistoryRepository repository;
  late SessionHistoryRecorder recorder;

  setUp(() async {
    db = await openAppDatabase(path: inMemoryDatabasePath);
    repository = HistoryRepository(db);
    recorder = SessionHistoryRecorder(
      repository,
      direction: TransferDirection.sent,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  test('reemite todo lo que recibe', () async {
    final List<SessionEvent> out = await recorder
        .observe(Stream<SessionEvent>.fromIterable(_upToManifest))
        .toList();
    expect(out, hasLength(2));
  });

  test('deja una entrada por archivo terminado', () async {
    await recorder
        .observe(
          Stream<SessionEvent>.fromIterable(<SessionEvent>[
            ..._upToManifest,
            const FileStarted(name: 'Foto_playa.jpg', index: 0, size: 1200),
            const FileFinished(name: 'Foto_playa.jpg', index: 0),
            const FileStarted(name: 'Contrato_v2.docx', index: 1, size: 800),
            const FileFinished(
              name: 'Contrato_v2.docx',
              index: 1,
              failure: FileFailure.checksumMismatch,
            ),
            const SessionFinished(completed: 1, total: 2),
          ]),
        )
        .toList();

    final List<TransferRecord> history = await repository.recent();
    expect(history, hasLength(2));

    final TransferRecord ok = history.firstWhere(
      (TransferRecord r) => r.fileName == 'Foto_playa.jpg',
    );
    expect(ok.status, TransferStatus.completed);
    expect(ok.sizeBytes, 1200);
    expect(ok.peerName, 'Pixel de Ana');
    expect(ok.peerPlatform, DevicePlatform.android);
    expect(ok.direction, TransferDirection.sent);

    final TransferRecord bad = history.firstWhere(
      (TransferRecord r) => r.fileName == 'Contrato_v2.docx',
    );
    expect(bad.status, TransferStatus.failed);
    expect(bad.failure, FileFailure.checksumMismatch);
  });

  test('un archivo que el par declino no entra al historial', () async {
    await recorder
        .observe(
          Stream<SessionEvent>.fromIterable(<SessionEvent>[
            ..._upToManifest,
            const FileFinished(
              name: 'Foto_playa.jpg',
              index: 0,
              rejection: RejectionReason.userDeclined,
            ),
          ]),
        )
        .toList();

    // No llego a transferirse: no hay nada que registrar.
    expect(await repository.recent(), isEmpty);
  });

  test('guarda la ruta de lo recibido', () async {
    final SessionHistoryRecorder receiving = SessionHistoryRecorder(
      repository,
      direction: TransferDirection.received,
    );

    await receiving
        .observe(
          Stream<SessionEvent>.fromIterable(<SessionEvent>[
            ..._upToManifest,
            const FileStarted(name: 'Foto_playa.jpg', index: 0, size: 1200),
            const FileFinished(
              name: 'Foto_playa.jpg',
              index: 0,
              path: '/descargas/Foto_playa.jpg',
            ),
          ]),
        )
        .toList();

    final TransferRecord saved = (await repository.recent()).single;
    expect(saved.direction, TransferDirection.received);
    expect(saved.localPath, '/descargas/Foto_playa.jpg');
  });

  test('un corte a mitad deja el archivo en vuelo como fallido', () async {
    final Stream<SessionEvent> broken = () async* {
      yield* Stream<SessionEvent>.fromIterable(<SessionEvent>[
        ..._upToManifest,
        const FileStarted(name: 'Foto_playa.jpg', index: 0, size: 1200),
      ]);
      throw const ConnectionFailed(ConnectionFault.lost);
    }();

    await expectLater(
      recorder.observe(broken).toList(),
      throwsA(isA<ConnectionFailed>()),
    );

    final TransferRecord saved = (await repository.recent()).single;
    expect(saved.fileName, 'Foto_playa.jpg');
    expect(saved.status, TransferStatus.failed);
    expect(saved.failure, FileFailure.incomplete);
    expect(saved.sizeBytes, 1200);
  });

  test('un corte entre archivos no inventa entradas', () async {
    final Stream<SessionEvent> broken = () async* {
      yield* Stream<SessionEvent>.fromIterable(_upToManifest);
      throw const TransferCancelled(CancelOrigin.remote);
    }();

    await expectLater(
      recorder.observe(broken).toList(),
      throwsA(isA<TransferCancelled>()),
    );
    expect(await repository.recent(), isEmpty);
  });
}
