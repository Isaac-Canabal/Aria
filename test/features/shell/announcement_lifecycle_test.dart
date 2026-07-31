/// El invariante de ciclo de vida sobre la pestana Recibir.
///
/// El shell usa un `IndexedStack`, que construye las cuatro pestanas aunque
/// solo pinte una. Sin cuidado, `announcementProvider` queda observado desde
/// el primer frame y el dispositivo se anuncia de forma permanente: se veia
/// en la primera prueba en dispositivo.
library;

import 'package:syroda/core/data/app_database.dart';
import 'package:syroda/core/platform/permissions.dart';
import 'package:syroda/design/nocturne.dart';
import 'package:syroda/features/shell/syroda_shell.dart';
import 'package:syroda/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  late int announcements;
  late int stopped;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    announcements = 0;
    stopped = 0;
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWith((Ref ref) async {
            final Database database = await openAppDatabase(
              path: inMemoryDatabasePath,
            );
            ref.onDispose(database.close);
            return database;
          }),
          permissionServiceProvider.overrideWithValue(
            _GrantedPermissionService(),
          ),
          // El anuncio real abre sockets y toca mDNS. Aqui solo interesa
          // **cuando** se observa, que es lo que enciende y apaga el anuncio.
          announcementProvider.overrideWith((Ref ref) async {
            announcements++;
            ref.onDispose(() => stopped++);
          }),
        ],
        child: MaterialApp(
          theme: nocturneTheme(),
          home: const Scaffold(body: SyrodaShell()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('en Enviar no se anuncia, aunque Recibir este construida', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    expect(find.text('Buscando más dispositivos…'), findsOneWidget);
    expect(announcements, 0);
  });

  testWidgets('entrar a Recibir enciende el anuncio', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Recibir'));
    await tester.pump();

    expect(announcements, 1);
    expect(stopped, 0);
  });

  testWidgets('salir de Recibir lo apaga', (WidgetTester tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Recibir'));
    await tester.pump();
    expect(announcements, 1);

    await tester.tap(find.text('Historial'));
    // Dos frames: Riverpod programa el `autoDispose`, no lo ejecuta en el
    // mismo frame en el que se deja de observar el proveedor.
    await tester.pump();
    await tester.pump();

    expect(stopped, 1);
  });

  testWidgets('volver a Recibir lo vuelve a encender', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Recibir'));
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    await tester.tap(find.text('Recibir'));
    await tester.pump();

    expect(announcements, 2);
  });
}
