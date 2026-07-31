import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeFileName', () {
    test('deja pasar un nombre normal, con acentos', () {
      expect(
        sanitizeFileName('Presentación_Q3.pdf'),
        'Presentación_Q3.pdf',
      );
    });

    test('se queda con el ultimo componente de una ruta', () {
      expect(sanitizeFileName(r'..\..\Windows\System32\drivers\etc\hosts'),
          'hosts');
      expect(sanitizeFileName('/etc/passwd'), 'passwd');
      expect(sanitizeFileName(r'C:\Users\alguien\clave.txt'), 'clave.txt');
    });

    test('un nombre que solo es ruta relativa cae al de reserva', () {
      expect(sanitizeFileName('..'), fallbackFileName);
      expect(sanitizeFileName('.'), fallbackFileName);
      expect(sanitizeFileName('../'), fallbackFileName);
      expect(sanitizeFileName(''), fallbackFileName);
    });

    test('quita los caracteres que Windows prohibe', () {
      expect(sanitizeFileName('re:porte<final>.pdf'), 'reportefinal.pdf');
      expect(sanitizeFileName('a|b?c*d.txt'), 'abcd.txt');
    });

    test('quita los caracteres de control', () {
      expect(sanitizeFileName('foto\u0000\u001B.jpg'), 'foto.jpg');
    });

    test('quita puntos y espacios al final', () {
      // Windows los ignora al abrir, asi que el nombre real no seria el que
      // se ve.
      expect(sanitizeFileName('x.txt. '), 'x.txt');
      expect(sanitizeFileName('informe   '), 'informe');
    });

    test('desactiva los nombres de dispositivo de Windows', () {
      expect(sanitizeFileName('CON'), '_CON');
      expect(sanitizeFileName('con.txt'), '_con.txt');
      expect(sanitizeFileName('LPT9.dat'), '_LPT9.dat');
      expect(sanitizeFileName('CONTRATO.pdf'), 'CONTRATO.pdf');
    });

    test('recorta al limite conservando la extension', () {
      final String name = sanitizeFileName('${'a' * 400}.pdf');
      expect(name.length, lessThanOrEqualTo(maxFileNameBytes));
      expect(name, endsWith('.pdf'));
    });

    test('cuenta bytes, no caracteres', () {
      // Cada 'ñ' ocupa dos bytes en UTF-8.
      final String name = sanitizeFileName('${'ñ' * 200}.jpg');
      expect(name.length, lessThan(200));
      expect(name, endsWith('.jpg'));
    });

    test('un nombre que empieza por punto es todo raiz', () {
      expect(sanitizeFileName('.gitignore'), '.gitignore');
    });
  });

  group('uniqueFileName', () {
    test('devuelve el mismo si no existe', () {
      expect(uniqueFileName('a.txt', (_) => false), 'a.txt');
    });

    test('numera hasta encontrar hueco', () {
      const Set<String> taken = <String>{'a.txt', 'a (2).txt', 'a (3).txt'};
      expect(uniqueFileName('a.txt', taken.contains), 'a (4).txt');
    });

    test('numera tambien sin extension', () {
      expect(uniqueFileName('informe', <String>{'informe'}.contains),
          'informe (2)');
    });
  });
}
