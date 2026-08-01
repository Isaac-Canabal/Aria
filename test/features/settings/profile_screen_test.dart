/// El renombrado del dispositivo en Ajustes.
///
/// Fallaba en dispositivo con `'_dependents.isEmpty': is not true`, que es el
/// `assert` de `InheritedElement.debugDeactivated`: una consecuencia de que
/// algo lanzara a mitad del desmontaje del dialogo, no la causa.
library;

import 'package:syroda/core/data/preferences.dart';
import 'package:syroda/design/components.dart';
import 'package:syroda/design/nocturne.dart';
import 'package:syroda/features/settings/profile_screen.dart';
import 'package:syroda/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<ProviderContainer> pumpProfile(WidgetTester tester) async {
    await loadInter(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: nocturneTheme(),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    // Los ajustes se resuelven asincronos: sin esto la pantalla esta vacia.
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('cambiar el nombre lo guarda y no deja el arbol roto', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpProfile(tester);

    await tester.tap(find.text('Nombre del dispositivo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SyrodaInput), 'PC de Luis');
    await tester.tap(find.text('Guardar'));
    // Hasta que la animacion de salida no termina, el dialogo sigue montado:
    // ahi es donde el controller destruido antes de tiempo explotaba.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container.read(settingsProvider).requireValue.deviceName,
      'PC de Luis',
    );
  });

  testWidgets('cancelar tras enfocar el campo no lanza al desmontar', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Nombre del dispositivo'));
    await tester.pumpAndSettle();

    // Enfocar es lo que en movil abre el teclado, y es el estado que en
    // escritorio no se alcanza pulsando Guardar con el raton: al cerrarse el
    // dialogo el campo pierde el foco y el listener avisa durante el
    // desmontaje.
    await tester.tap(find.byType(SyrodaInput));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('"Acerca de Syroda" explica lo que la app hace', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Acerca de Syroda'));
    await tester.pumpAndSettle();

    // Frases propias del texto: "red local" tambien esta detras, en la
    // etiqueta de visibilidad.
    expect(find.textContaining('ningún servidor'), findsOneWidget);
    expect(find.textContaining('no hacen falta'), findsOneWidget);
    expect(find.textContaining('código de 6 dígitos'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
  });

  testWidgets('el texto no afirma cifrado ni promete lo que no existe', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);
    await tester.tap(find.text('Acerca de Syroda'));
    await tester.pumpAndSettle();

    // El invariante de copy: `SecureChannel` es pass-through en v1, asi que
    // ninguna superficie puede afirmar cifrado. Y nada de lo diferido -- el
    // QR, el modo claro -- se menciona como si existiera.
    for (final String forbidden in <String>[
      'cifrad',
      'segur',
      'encriptad',
      'protegid',
      'QR',
      'modo claro',
    ]) {
      expect(
        find.textContaining(RegExp(forbidden, caseSensitive: false)),
        findsNothing,
        reason: 'el copy de "Acerca de" no puede decir "$forbidden"',
      );
    }
  });

  testWidgets('cancelar no cambia el nombre', (WidgetTester tester) async {
    final ProviderContainer container = await pumpProfile(tester);
    final SyrodaSettings before = container.read(settingsProvider).requireValue;

    await tester.tap(find.text('Nombre del dispositivo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SyrodaInput), 'No guardar');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).requireValue.deviceName,
      before.deviceName,
    );
  });
}
