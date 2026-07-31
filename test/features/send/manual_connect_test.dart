import 'package:syroda/design/components.dart';
import 'package:syroda/design/nocturne.dart';
import 'package:syroda/features/send/manual_connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fonts.dart';

void main() {
  testWidgets('arranca con el boton Conectar inhabilitado', (
    WidgetTester tester,
  ) async {
    await loadInter(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: nocturneTheme(),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => askForManualConnection(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final SyrodaButton connect = tester.widget<SyrodaButton>(
      find.widgetWithText(SyrodaButton, 'Conectar'),
    );
    expect(connect.enabled, isFalse);
  });

  testWidgets(
    'con direccion, puerto y codigo completos habilita Conectar y devuelve lo tecleado',
    (WidgetTester tester) async {
      await loadInter(tester);
      ManualConnection? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: nocturneTheme(),
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await askForManualConnection(context);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(SyrodaInput).at(0),
        '192.168.1.23:54321',
      );
      await tester.enterText(find.byType(SyrodaInput).at(1), '482 913');
      await tester.pump();

      final SyrodaButton connect = tester.widget<SyrodaButton>(
        find.widgetWithText(SyrodaButton, 'Conectar'),
      );
      expect(connect.enabled, isTrue);

      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.host, '192.168.1.23');
      expect(result!.port, 54321);
      // El espacio de lectura ("482 913") no viaja al protocolo.
      expect(result!.code, '482913');
    },
  );

  testWidgets('una direccion sin puerto no habilita Conectar', (
    WidgetTester tester,
  ) async {
    await loadInter(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: nocturneTheme(),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => askForManualConnection(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SyrodaInput).at(0), '192.168.1.23');
    await tester.enterText(find.byType(SyrodaInput).at(1), '482913');
    await tester.pump();

    final SyrodaButton connect = tester.widget<SyrodaButton>(
      find.widgetWithText(SyrodaButton, 'Conectar'),
    );
    expect(connect.enabled, isFalse);
  });

  testWidgets('cancelar no devuelve conexion', (WidgetTester tester) async {
    await loadInter(tester);
    ManualConnection? result;
    bool returned = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: nocturneTheme(),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await askForManualConnection(context);
              returned = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNull);
  });
}
