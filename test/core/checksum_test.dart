import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aria/core/transfer/transfer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String hashOf(Iterable<List<int>> chunks) {
  final IncrementalSha256 digest = IncrementalSha256();
  for (final List<int> chunk in chunks) {
    digest.add(chunk);
  }
  return digest.finish();
}

void main() {
  group('IncrementalSha256', () {
    test('vector vacio', () {
      expect(
        hashOf(const <List<int>>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('vector "abc"', () {
      expect(
        hashOf(<List<int>>[utf8.encode('abc')]),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('el troceado no cambia la huella', () {
      // Es la garantia de la que depende el trailer: emisor y receptor
      // trocean distinto y tienen que llegar a la misma huella.
      final Uint8List data = Uint8List.fromList(
        List<int>.generate(300000, (int i) => (i * 31) % 256),
      );

      final String whole = hashOf(<List<int>>[data]);
      final String inSevens = hashOf(<List<int>>[
        for (int i = 0; i < data.length; i += 7)
          data.sublist(i, min(i + 7, data.length)),
      ]);
      final String inChunks = hashOf(<List<int>>[
        for (int i = 0; i < data.length; i += chunkBytes)
          data.sublist(i, min(i + chunkBytes, data.length)),
      ]);

      expect(whole, inSevens);
      expect(whole, inChunks);
      expect(whole, sha256.convert(data).toString());
    });

    test('un bit distinto cambia la huella', () {
      final Uint8List a = Uint8List.fromList(List<int>.filled(1000, 7));
      final Uint8List b = Uint8List.fromList(a)..[999] = 6;

      expect(hashOf(<List<int>>[a]), isNot(hashOf(<List<int>>[b])));
    });

    test('la huella sale en hexadecimal minuscula de 64 caracteres', () {
      expect(
        hashOf(<List<int>>[utf8.encode('Presentación_Q3.pdf')]),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });
  });
}
