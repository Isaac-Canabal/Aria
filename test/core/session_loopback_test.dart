import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Codigos fijos, en orden, para no depender del azar. El segundo es el que
/// sale al invalidar el primero.
class _ScriptedRandom implements Random {
  int _index = 0;

  @override
  int nextInt(int max) => const <int>[482913, 111111][_index++ % 2];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

const String theCode = '482913';
const String nextCode = '111111';

const String phoneId = '0123456789abcdef0123456789abcdef';
const String desktopId = 'fedcba9876543210fedcba9876543210';

const DeviceIdentity phone = DeviceIdentity(
  id: phoneId,
  name: 'Pixel de Ana',
  platform: DevicePlatform.android,
);
const DeviceIdentity desktop = DeviceIdentity(
  id: desktopId,
  name: 'PC de Luis',
  platform: DevicePlatform.windows,
);

OutgoingFile fileOf(String name, List<int> bytes) => OutgoingFile(
  name: name,
  size: bytes.length,
  open: () => Stream<List<int>>.value(bytes),
);

/// Un canal que altera un byte al sellar. Con la huella en el trailer, un
/// emisor honesto no puede producir un desajuste: hace falta que los bytes se
/// corrompan en el camino, que es justo lo que el checksum existe para pillar.
class _CorruptingChannel implements ChannelInitiator {
  _CorruptingChannel(this._inner);

  final ChannelInitiator _inner;
  bool _done = false;

  @override
  String get id => _inner.id;

  @override
  Uint8List init() => _inner.init();

  @override
  Uint8List confirm(Uint8List responsePayload) =>
      _inner.confirm(responsePayload);

  @override
  List<int> seal(List<int> plain) {
    if (_done || plain.isEmpty) return plain;
    _done = true;
    return <int>[plain.first ^ 0xFF, ...plain.skip(1)];
  }
}

Uint8List payload(int size) =>
    Uint8List.fromList(List<int>.generate(size, (int i) => (i * 7) % 251));

/// Rechaza los archivos cuyo nombre este en [blocked].
class _PickyPolicy implements ReceivePolicy {
  _PickyPolicy(this.directory, {this.blocked = const <String>{}});

  final Directory directory;
  final Set<String> blocked;

  @override
  Future<ManifestDecision> reviewManifest(Manifest manifest) async =>
      AcceptManifest(FileSystemDestination(directory));

  @override
  Future<RejectionReason?> reviewFile(FileHeader header) async =>
      blocked.contains(header.name) ? RejectionReason.userDeclined : null;
}

void main() {
  late Directory inbox;
  late PairingService pairing;
  late ReceiveServer server;
  late List<SessionEvent> received;
  late List<Object> receiverErrors;
  late StreamSubscription<SessionEvent> subscription;

  /// La politica se construye aqui dentro: como fabrica, no como valor. Un
  /// argumento se evaluaria antes de que exista la carpeta de este test, y
  /// apuntaria a la del anterior, que tearDown ya borro.
  Future<void> boot({ReceivePolicy Function(Directory inbox)? policy}) async {
    inbox = await Directory.systemTemp.createTemp('syroda_inbox');
    pairing = PairingService(random: _ScriptedRandom());
    server = await ReceiveServer.bind(
      identity: desktop,
      responder: PlainChannelResponder(pairing),
      policy:
          policy?.call(inbox) ??
          DefaultReceivePolicy.withoutSpaceCheck(
            open: () async => FileSystemDestination.open(inbox),
          ),
      address: InternetAddress.loopbackIPv4,
    );
    received = <SessionEvent>[];
    receiverErrors = <Object>[];
    subscription = server.events.listen(
      received.add,
      onError: receiverErrors.add,
    );
  }

  SendSession sender(
    List<OutgoingFile> files, {
    String code = theCode,
    bool corrupt = false,
  }) {
    final ChannelInitiator plain = PlainChannelInitiator(code);
    return SendSession(
      addresses: <String>[InternetAddress.loopbackIPv4.address],
      port: server.port,
      identity: phone,
      channel: corrupt ? _CorruptingChannel(plain) : plain,
      files: files,
    );
  }

  tearDown(() async {
    await subscription.cancel();
    // close() espera a la sesion en vuelo: sin eso, el receptor seguiria
    // escribiendo en una carpeta que este tearDown ya borro.
    await server.close();
    await pairing.dispose();
    if (inbox.existsSync()) await inbox.delete(recursive: true);
  });

  test('bind(0) da un puerto efimero, nunca uno fijo', () async {
    await boot();
    expect(server.port, greaterThan(0));
    expect(server.port, isNot(anyOf(80, 443, 5353)));
  });

  test('un lote de dos archivos llega entero', () async {
    await boot();
    final Uint8List first = payload(200000);
    final Uint8List second = payload(1500);

    final List<SessionEvent> events = await sender(<OutgoingFile>[
      fileOf('Foto_playa.jpg', first),
      fileOf('Contrato_v2.docx', second),
    ]).run().toList();

    // El emisor ve el lote completo antes de mover un byte.
    final SessionManifest manifest = events.whereType<SessionManifest>().single;
    expect(manifest.files.map((ManifestEntry e) => e.name), <String>[
      'Foto_playa.jpg',
      'Contrato_v2.docx',
    ]);
    expect(manifest.totalBytes, first.length + second.length);

    final SessionAuthorized authorized = events
        .whereType<SessionAuthorized>()
        .single;
    expect(authorized.device, 'PC de Luis');
    // El identificador estable del par: es lo que se empareja, no el nombre.
    expect(authorized.deviceId, desktopId);
    expect(received.whereType<SessionAuthorized>().single.deviceId, phoneId);
    expect(events.whereType<FileStarted>(), hasLength(2));
    expect(
      events.whereType<FileFinished>().every((FileFinished e) => e.ok),
      isTrue,
    );

    final SessionFinished done = events.whereType<SessionFinished>().single;
    expect(done.completed, 2);
    expect(done.total, 2);

    expect(
      await File(
        '${inbox.path}${Platform.pathSeparator}Foto_playa.jpg',
      ).readAsBytes(),
      first,
    );
    expect(
      await File(
        '${inbox.path}${Platform.pathSeparator}Contrato_v2.docx',
      ).readAsBytes(),
      second,
    );
    // Ningun parcial sobrevive a una sesion que termino bien.
    expect(
      inbox.listSync().where((FileSystemEntity e) => e.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('el progreso avanza por chunk y llega al total', () async {
    await boot();
    final Uint8List data = payload(chunkBytes * 3 + 10);

    final List<SessionEvent> events = await sender(<OutgoingFile>[
      fileOf('grande.bin', data),
    ]).run().toList();

    final List<FileProgress> progress = events
        .whereType<FileProgress>()
        .toList();
    expect(progress.length, 4);
    expect(progress.first.bytes, chunkBytes);
    expect(progress.last.bytes, data.length);
    expect(progress.last.fraction, 1);
    expect(progress.last.sessionBytes, data.length);
  });

  test('un codigo equivocado no autoriza la sesion', () async {
    await boot();

    await expectLater(
      sender(<OutgoingFile>[
        fileOf('x.txt', payload(10)),
      ], code: '000000').run().toList(),
      throwsA(
        isA<AuthError>().having(
          (AuthError e) => e.failure,
          'failure',
          AuthFailure.invalidCode,
        ),
      ),
    );
    expect(inbox.listSync(), isEmpty);
  });

  test('al tercer intento el codigo se invalida', () async {
    await boot();
    final OutgoingFile file = fileOf('x.txt', payload(10));

    for (int i = 0; i < 2; i++) {
      await expectLater(
        sender(<OutgoingFile>[file], code: '00000$i').run().toList(),
        throwsA(isA<AuthError>()),
      );
    }

    await expectLater(
      sender(<OutgoingFile>[file], code: '999999').run().toList(),
      throwsA(
        isA<AuthError>().having(
          (AuthError e) => e.failure,
          'failure',
          AuthFailure.tooManyAttempts,
        ),
      ),
    );

    // Y el codigo viejo ya no sirve: hay uno nuevo.
    expect(pairing.current.digits, nextCode);
  });

  test('un checksum que no cuadra borra el parcial', () async {
    await boot();
    final Uint8List data = payload(5000);

    final List<SessionEvent> events = await sender(<OutgoingFile>[
      fileOf('corrupto.bin', data),
    ], corrupt: true).run().toList();

    final FileFinished finished = events.whereType<FileFinished>().single;
    expect(finished.ok, isFalse);
    expect(finished.failure, FileFailure.checksumMismatch);

    // Ni el definitivo ni el parcial quedan en el disco.
    expect(inbox.listSync(), isEmpty);
    expect(events.whereType<SessionFinished>().single.completed, 0);
  });

  test('rechazar un archivo no mata la sesion', () async {
    await boot(
      policy: (Directory dir) => _PickyPolicy(dir, blocked: <String>{'no.bin'}),
    );

    final List<SessionEvent> events = await sender(<OutgoingFile>[
      fileOf('no.bin', payload(100)),
      fileOf('si.bin', payload(100)),
    ]).run().toList();

    final List<FileFinished> finished = events
        .whereType<FileFinished>()
        .toList();
    expect(finished, hasLength(2));
    expect(finished.first.rejection, RejectionReason.userDeclined);
    expect(finished.first.failure, isNull);
    expect(finished.last.ok, isTrue);

    expect(
      File('${inbox.path}${Platform.pathSeparator}si.bin').existsSync(),
      isTrue,
    );
    expect(
      File('${inbox.path}${Platform.pathSeparator}no.bin').existsSync(),
      isFalse,
    );
  });

  test('el lote se rechaza entero si no cabe', () async {
    await boot(
      policy: (Directory dir) => DefaultReceivePolicy(
        open: () async => FileSystemDestination.open(dir),
        freeBytes: () async => 1000,
      ),
    );

    await expectLater(
      sender(<OutgoingFile>[
        fileOf('enorme.bin', payload(50000)),
      ]).run().toList(),
      throwsA(
        isA<RejectedByPeer>()
            .having(
              (RejectedByPeer e) => e.reason,
              'reason',
              RejectionReason.insufficientSpace,
            )
            .having(
              (RejectedByPeer e) => e.scope,
              'scope',
              RejectionScope.session,
            ),
      ),
    );
    // Se rechaza antes de escribir nada, no en el archivo 3 de 5.
    expect(inbox.listSync(), isEmpty);
  });

  test('un nombre con ruta se sanea del lado que escribe', () async {
    await boot();
    // Un par hostil no sanea antes de mandar: el receptor no se fia.
    final Uint8List data = payload(64);

    await sender(<OutgoingFile>[
      fileOf(r'..\..\..\Windows\System32\evil.dll', data),
    ]).run().toList();

    expect(
      File('${inbox.path}${Platform.pathSeparator}evil.dll').existsSync(),
      isTrue,
    );
    expect(inbox.listSync(), hasLength(1));
  });

  test('dos archivos con el mismo nombre no se pisan', () async {
    await boot();
    final Uint8List a = payload(50);
    final Uint8List b = payload(80);

    await sender(<OutgoingFile>[
      fileOf('repetido.bin', a),
      fileOf('repetido.bin', b),
    ]).run().toList();

    expect(
      await File(
        '${inbox.path}${Platform.pathSeparator}repetido.bin',
      ).readAsBytes(),
      a,
    );
    expect(
      await File(
        '${inbox.path}${Platform.pathSeparator}repetido (2).bin',
      ).readAsBytes(),
      b,
    );
  });

  test('cancelar a mitad corta la sesion y no deja parciales', () async {
    await boot();
    final Uint8List data = payload(chunkBytes * 40);
    final SendSession session = sender(<OutgoingFile>[
      fileOf('largo.bin', data),
    ]);

    final Completer<Object?> ended = Completer<Object?>();
    final StreamSubscription<SessionEvent> events = session.run().listen(
      (SessionEvent event) {
        if (event is FileProgress) session.cancel();
      },
      onError: (Object error) {
        if (!ended.isCompleted) ended.complete(error);
      },
      onDone: () {
        if (!ended.isCompleted) ended.complete(null);
      },
    );

    final Object? outcome = await ended.future;
    await events.cancel();

    expect(
      outcome,
      isA<TransferCancelled>().having(
        (TransferCancelled e) => e.origin,
        'origin',
        CancelOrigin.local,
      ),
    );

    // El receptor lo interpreta como cancelacion del par y borra el parcial.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(receiverErrors.whereType<TransferCancelled>(), isNotEmpty);
    expect(inbox.listSync(), isEmpty);
  });

  test('una segunda sesion simultanea se rechaza por ocupado', () async {
    await boot();
    final SendSession first = sender(<OutgoingFile>[
      fileOf('primero.bin', payload(chunkBytes * 30)),
    ]);

    final Completer<void> started = Completer<void>();
    final Future<List<SessionEvent>> firstRun = first.run().map((
      SessionEvent event,
    ) {
      if (event is FileProgress && !started.isCompleted) started.complete();
      return event;
    }).toList();

    await started.future;

    await expectLater(
      sender(<OutgoingFile>[fileOf('segundo.bin', payload(10))]).run().toList(),
      throwsA(
        isA<RejectedByPeer>().having(
          (RejectedByPeer e) => e.reason,
          'reason',
          RejectionReason.busy,
        ),
      ),
    );

    // La primera sigue viva y termina bien.
    final List<SessionEvent> events = await firstRun;
    expect(events.whereType<SessionFinished>().single.completed, 1);
  });
}
