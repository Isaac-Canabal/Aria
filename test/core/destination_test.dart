import 'dart:io';

import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

Manifest manifestOf(int totalBytes) => Manifest(
  files: <ManifestEntry>[ManifestEntry(name: 'x.bin', size: totalBytes)],
  totalBytes: totalBytes,
);

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('syroda_dst'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('destino sobre el sistema de archivos', () {
    test('crea la carpeta si no existe', () async {
      final Directory nested = Directory('${root.path}/Descargas/Syroda');
      expect(nested.existsSync(), isFalse);

      expect(await FileSystemDestination.open(nested), isNotNull);
      expect(nested.existsSync(), isTrue);
    });

    test('lo escrito no es un archivo terminado hasta commit', () async {
      final FileSystemDestination destination =
          (await FileSystemDestination.open(root))!;
      final IncomingFileSink sink = await destination.create(
        'foto.jpg',
        size: 3,
      );
      await sink.add(<int>[1, 2, 3]);
      await sink.flush();

      // Mientras tanto solo hay un parcial: nada con el nombre definitivo.
      expect(File('${root.path}/foto.jpg').existsSync(), isFalse);
      expect(File('${root.path}/foto.jpg.part').existsSync(), isTrue);

      final String? path = await sink.commit();
      expect(File('${root.path}/foto.jpg').existsSync(), isTrue);
      expect(File('${root.path}/foto.jpg.part').existsSync(), isFalse);
      expect(path, endsWith('foto.jpg'));
    });

    test('descartar no deja rastro', () async {
      final FileSystemDestination destination =
          (await FileSystemDestination.open(root))!;
      final IncomingFileSink sink = await destination.create('x.bin', size: 2);
      await sink.add(<int>[1, 2]);
      await sink.discard();

      expect(root.listSync(), isEmpty);
    });

    test('descartar dos veces no revienta', () async {
      final FileSystemDestination destination =
          (await FileSystemDestination.open(root))!;
      final IncomingFileSink sink = await destination.create('x.bin', size: 1);
      await sink.discard();
      await sink.discard();
    });

    test('un nombre ocupado no se pisa, ni por su parcial', () async {
      final FileSystemDestination destination =
          (await FileSystemDestination.open(root))!;
      await File('${root.path}/x.bin').writeAsString('ya estaba');

      final IncomingFileSink second = await destination.create(
        'x.bin',
        size: 1,
      );
      expect(second.name, 'x (2).bin');

      // Y el parcial en vuelo tambien cuenta: dos sesiones a la vez con el
      // mismo nombre no pueden compartir `.part`.
      final IncomingFileSink third = await destination.create('x.bin', size: 1);
      expect(third.name, 'x (3).bin');

      await second.discard();
      await third.discard();
    });
  });

  group('rechazo del lote por destino invalido', () {
    test('se decide al validar el manifiesto, no a mitad del lote', () async {
      final DefaultReceivePolicy policy =
          DefaultReceivePolicy.withoutSpaceCheck(open: () async => null);

      final ManifestDecision decision = await policy.reviewManifest(
        manifestOf(10),
      );
      expect(
        decision,
        isA<RejectManifest>().having(
          (RejectManifest r) => r.reason,
          'reason',
          RejectionReason.destinationUnavailable,
        ),
      );
    });

    test('un destino que abre acepta y viene dentro de la decision', () async {
      final DefaultReceivePolicy policy =
          DefaultReceivePolicy.withoutSpaceCheck(
            open: () async => FileSystemDestination.open(root),
          );

      expect(
        await policy.reviewManifest(manifestOf(10)),
        isA<AcceptManifest>(),
      );
    });

    test('el espacio se comprueba antes de abrir el destino', () async {
      // Si no cabe, el motivo tiene que ser el espacio: abrir la carpeta no
      // puede robarle el diagnostico.
      bool opened = false;
      final DefaultReceivePolicy policy = DefaultReceivePolicy(
        open: () async {
          opened = true;
          return FileSystemDestination.open(root);
        },
        freeBytes: () async => 1000,
      );

      final ManifestDecision decision = await policy.reviewManifest(
        manifestOf(50000),
      );
      expect(
        decision,
        isA<RejectManifest>().having(
          (RejectManifest r) => r.reason,
          'reason',
          RejectionReason.insufficientSpace,
        ),
      );
      expect(opened, isFalse);
    });
  });
}
