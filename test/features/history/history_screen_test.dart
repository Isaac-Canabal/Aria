/// La seccion de archivos recibidos: ver donde quedan y abrirlos.
library;

import 'package:syroda/core/data/transfer_record.dart';
import 'package:syroda/core/platform/open_received.dart';
import 'package:syroda/core/transfer/transfer.dart';
import 'package:syroda/design/nocturne.dart';
import 'package:syroda/features/history/history_screen.dart';
import 'package:syroda/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fonts.dart';

/// El historial ya resuelto.
///
/// Sin base de datos a proposito: `sqflite` necesita E/S real y `testWidgets`
/// corre con reloj falso, asi que abrirla aqui cuelga el test. Lo que se
/// prueba es la pantalla, no el repositorio, que ya tiene sus propias pruebas.
class _FixedHistory extends HistoryController {
  _FixedHistory(this.entries);

  final List<TransferRecord> entries;

  @override
  Future<List<TransferRecord>> build() async => entries;
}

class _ScriptedOpener implements ReceivedFileOpener {
  _ScriptedOpener(this.outcome);

  final OpenOutcome outcome;
  final List<String> opened = <String>[];
  final List<String> folders = <String>[];

  @override
  Future<OpenOutcome> open(String target) async {
    opened.add(target);
    return outcome;
  }

  @override
  Future<OpenOutcome> reveal(String target) => open(target);

  @override
  Future<OpenOutcome> openFolder(String path) async {
    folders.add(path);
    return outcome;
  }
}

TransferRecord received({
  String name = 'Foto_playa.jpg',
  String? localPath = '/descargas/Syroda/Foto_playa.jpg',
  TransferStatus status = TransferStatus.completed,
  TransferDirection direction = TransferDirection.received,
}) => TransferRecord(
  fileName: name,
  sizeBytes: 1024,
  direction: direction,
  peerName: 'Pixel de Ana',
  peerPlatform: DevicePlatform.android,
  completedAt: DateTime.now().toUtc(),
  status: status,
  localPath: localPath,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpHistory(
    WidgetTester tester,
    _ScriptedOpener opener, {
    List<TransferRecord> entries = const <TransferRecord>[],
  }) async {
    await loadInter(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          historyProvider.overrideWith(() => _FixedHistory(entries)),
          fileOpenerProvider.overrideWithValue(opener),
          // La etiqueta real la resuelve `path_provider`, que en un test no
          // existe. Que sea la ruta correcta no es lo que se prueba aqui.
          destinationLabelProvider.overrideWith(
            (Ref ref) async => 'C:\\Users\\yo\\Downloads\\Syroda',
          ),
        ],
        child: MaterialApp(
          theme: nocturneTheme(),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    // Dos frames: la etiqueta del destino es asincrona y el primero solo
    // alcanza a pintar la lista.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('la carpeta de destino se ve con lo recibido', (
    WidgetTester tester,
  ) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.opened);
    await pumpHistory(tester, opener, entries: <TransferRecord>[received()]);

    expect(find.text('Lo recibido se guarda aquí'), findsOneWidget);
  });

  testWidgets('tocar un recibido lo abre', (WidgetTester tester) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.opened);
    await pumpHistory(tester, opener, entries: <TransferRecord>[received()]);

    await tester.tap(find.text('Foto_playa.jpg'));
    await tester.pump();

    expect(opener.opened, <String>['/descargas/Syroda/Foto_playa.jpg']);
  });

  testWidgets('un archivo borrado dice que ya no esta, no que falte una app', (
    WidgetTester tester,
  ) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.missing);
    await pumpHistory(tester, opener, entries: <TransferRecord>[received()]);

    await tester.tap(find.text('Foto_playa.jpg'));
    await tester.pump();

    expect(find.text('El archivo ya no está donde se guardó'), findsOneWidget);
    // Y la fila sigue ahi, diciendo donde estaba.
    expect(find.text('Foto_playa.jpg'), findsOneWidget);
  });

  testWidgets('sin app que lo abra dice eso, que es otro problema', (
    WidgetTester tester,
  ) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.noHandler);
    await pumpHistory(
      tester,
      opener,
      entries: <TransferRecord>[
        received(name: 'raro.bin', localPath: '/descargas/Syroda/raro.bin'),
      ],
    );

    await tester.tap(find.text('raro.bin'));
    await tester.pump();

    expect(
      find.text('No hay ninguna app para abrir este archivo'),
      findsOneWidget,
    );
  });

  testWidgets('lo enviado no se intenta abrir: no lo movio nadie', (
    WidgetTester tester,
  ) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.opened);
    await pumpHistory(
      tester,
      opener,
      entries: <TransferRecord>[
        received(name: 'enviado.pdf', direction: TransferDirection.sent),
      ],
    );

    await tester.tap(find.text('enviado.pdf'));
    await tester.pump();

    expect(opener.opened, isEmpty);
  });

  testWidgets('un recibido sin ruta tampoco se intenta abrir', (
    WidgetTester tester,
  ) async {
    final _ScriptedOpener opener = _ScriptedOpener(OpenOutcome.opened);
    await pumpHistory(
      tester,
      opener,
      entries: <TransferRecord>[
        received(name: 'sin_ruta.bin', localPath: null),
      ],
    );

    await tester.tap(find.text('sin_ruta.bin'));
    await tester.pump();

    expect(opener.opened, isEmpty);
  });
}
