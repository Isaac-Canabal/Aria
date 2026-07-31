import 'package:syroda/state/lifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isForeground', () {
    test('inactive NO apaga nada', () {
      // Android emite `inactive` al bajar la cortina de notificaciones, al
      // mostrar un dialogo de permisos y al entrar una llamada. Apagarse ahi
      // haria parpadear el dispositivo en la lista del emisor.
      expect(isForeground(AppLifecycleState.inactive), isTrue);
    });

    test('resumed es primer plano', () {
      expect(isForeground(AppLifecycleState.resumed), isTrue);
    });

    test('paused, hidden y detached apagan', () {
      expect(isForeground(AppLifecycleState.paused), isFalse);
      expect(isForeground(AppLifecycleState.hidden), isFalse);
      expect(isForeground(AppLifecycleState.detached), isFalse);
    });

    test('cubre todos los estados sin caso por defecto', () {
      // Si Flutter agrega un estado, el switch deja de compilar y hay que
      // decidirlo a mano en vez de heredar un valor silencioso.
      for (final AppLifecycleState state in AppLifecycleState.values) {
        expect(isForeground(state), isA<bool>());
      }
    });

    test('el ciclo tipico de una llamada no cambia de estado', () {
      // resumed -> inactive -> resumed: la app nunca dejo de estar disponible.
      const List<AppLifecycleState> call = <AppLifecycleState>[
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ];
      expect(call.map(isForeground), everyElement(isTrue));
    });

    test('el ciclo de irse a otra app si apaga', () {
      // resumed -> inactive -> paused: solo el ultimo apaga.
      expect(isForeground(AppLifecycleState.inactive), isTrue);
      expect(isForeground(AppLifecycleState.paused), isFalse);
    });
  });
}
