import 'dart:math';

import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Devuelve los valores que se le pidan, en orden.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);

  final List<int> _values;
  int _index = 0;

  @override
  int nextInt(int max) => _values[_index++ % _values.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('el codigo son seis digitos, con ceros a la izquierda', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[42]),
    );

    expect(pairing.current.digits, '000042');
    expect(pairing.current.digits.length, 6);
  });

  test('display es la forma de los mockups', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913]),
    );
    expect(pairing.current.display, '482 913');
  });

  test('acepta el codigo correcto', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913]),
    );
    expect(pairing.verify('482913'), PairingOutcome.accepted);
  });

  test('rechaza el espacio de lectura: el codigo son los digitos', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913]),
    );
    expect(pairing.verify('482 913'), PairingOutcome.invalidCode);
  });

  test('tres intentos y el codigo se invalida', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913, 111111]),
    );

    expect(pairing.verify('000000'), PairingOutcome.invalidCode);
    expect(pairing.remainingAttempts, 2);
    expect(pairing.verify('000001'), PairingOutcome.invalidCode);
    expect(pairing.remainingAttempts, 1);
    expect(pairing.verify('000002'), PairingOutcome.tooManyAttempts);

    // Un millon de combinaciones no aguantan un atacante en la misma LAN sin
    // este limite.
    expect(pairing.current.digits, '111111');
    expect(pairing.remainingAttempts, 3);
    expect(pairing.verify('482913'), PairingOutcome.invalidCode);
  });

  test('un acierto reinicia la cuenta de intentos', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913]),
    );

    expect(pairing.verify('000000'), PairingOutcome.invalidCode);
    expect(pairing.verify('482913'), PairingOutcome.accepted);
    expect(pairing.remainingAttempts, 3);
  });

  test('emite el codigo nuevo al invalidar', () async {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913, 111111]),
    );
    final Future<PairingCode> next = pairing.codes.first;

    pairing.verify('1');
    pairing.verify('2');
    pairing.verify('3');

    expect((await next).digits, '111111');
    await pairing.dispose();
  });

  group('caducidad', () {
    test('un codigo recien generado no ha caducado', () {
      final PairingService pairing = PairingService(
        random: _ScriptedRandom(<int>[482913]),
        clock: () => DateTime.utc(2026, 7, 30, 12),
      );
      expect(pairing.isExpired, isFalse);
      expect(pairing.verify('482913'), PairingOutcome.accepted);
    });

    test('pasados cinco minutos caduca', () {
      DateTime now = DateTime.utc(2026, 7, 30, 12);
      final PairingService pairing = PairingService(
        random: _ScriptedRandom(<int>[482913]),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 5));
      expect(pairing.isExpired, isTrue);
      // Ni siquiera el codigo correcto sirve.
      expect(pairing.verify('482913'), PairingOutcome.expired);
    });

    test('caducar no gasta intentos', () {
      DateTime now = DateTime.utc(2026, 7, 30, 12);
      final PairingService pairing = PairingService(
        random: _ScriptedRandom(<int>[482913]),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 6));
      pairing.verify('000000');
      pairing.verify('000001');
      pairing.verify('000002');
      expect(pairing.remainingAttempts, 3);
    });

    test('generar uno nuevo reinicia el reloj', () {
      DateTime now = DateTime.utc(2026, 7, 30, 12);
      final PairingService pairing = PairingService(
        random: _ScriptedRandom(<int>[482913, 111111]),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 6));
      expect(pairing.isExpired, isTrue);

      pairing.regenerate();
      expect(pairing.isExpired, isFalse);
      expect(pairing.verify('111111'), PairingOutcome.accepted);
    });
  });

  test('un codigo de otra longitud no acierta por prefijo', () {
    final PairingService pairing = PairingService(
      random: _ScriptedRandom(<int>[482913]),
    );
    expect(pairing.verify('4829130'), PairingOutcome.invalidCode);
  });
}
