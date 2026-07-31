import 'dart:typed_data';

import 'package:aria/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeFrame', () {
    test('escribe tipo, longitud big-endian y payload', () {
      final Uint8List frame = encodeFrame(
        FrameType.control,
        <int>[0xAA, 0xBB],
      );

      expect(frame[0], FrameType.control.tag);
      expect(frame.sublist(1, 5), <int>[0x00, 0x00, 0x00, 0x02]);
      expect(frame.sublist(5), <int>[0xAA, 0xBB]);
    });

    test('el tipo va antes de la longitud', () {
      // Es lo que permite intercalar control a mitad de los chunks: quien lee
      // sabe que trae el frame con el primer byte.
      expect(encodeFrame(FrameType.chunk, <int>[]).first, FrameType.chunk.tag);
      expect(frameHeaderBytes, 5);
    });

    test('una longitud de tres bytes se codifica en el orden de red', () {
      final Uint8List frame = encodeFrame(
        FrameType.chunk,
        Uint8List(0x010203),
      );
      expect(frame.sublist(1, 5), <int>[0x00, 0x01, 0x02, 0x03]);
    });
  });

  group('FrameParser', () {
    test('reconstruye un frame partido en trozos de un byte', () {
      final Uint8List frame = encodeFrame(
        FrameType.control,
        <int>[1, 2, 3, 4, 5],
      );
      final FrameParser parser = FrameParser();

      final List<Frame> out = <Frame>[];
      for (final int byte in frame) {
        out.addAll(parser.add(<int>[byte]));
      }

      expect(out, hasLength(1));
      expect(out.single.type, FrameType.control);
      expect(out.single.payload, <int>[1, 2, 3, 4, 5]);
      expect(parser.pendingBytes, 0);
    });

    test('devuelve varios frames de un mismo trozo', () {
      final FrameParser parser = FrameParser();
      final List<int> data = <int>[
        ...encodeFrame(FrameType.control, <int>[1]),
        ...encodeFrame(FrameType.chunk, <int>[2, 3]),
        ...encodeFrame(FrameType.control, <int>[4]),
      ];

      final List<Frame> out = parser.add(data);

      expect(out.map((Frame f) => f.type), <FrameType>[
        FrameType.control,
        FrameType.chunk,
        FrameType.control,
      ]);
      expect(out[1].payload, <int>[2, 3]);
    });

    test('guarda el resto cuando falta la cola', () {
      final FrameParser parser = FrameParser();
      final Uint8List frame = encodeFrame(FrameType.chunk, <int>[9, 9, 9]);

      expect(parser.add(frame.sublist(0, 6)), isEmpty);
      expect(parser.pendingBytes, 6);
      expect(parser.add(frame.sublist(6)), hasLength(1));
    });

    test('un frame de datos de cero bytes es valido', () {
      final FrameParser parser = FrameParser();
      final List<Frame> out = parser.add(encodeFrame(FrameType.chunk, <int>[]));
      expect(out.single.payload, isEmpty);
    });

    test('rechaza un tipo sin asignar antes de reservar nada', () {
      final FrameParser parser = FrameParser();
      // Tipo 0x7F: dentro del rango reservado, todavia sin asignar.
      expect(
        () => parser.add(<int>[0x7F, 0, 0, 0, 1, 0]),
        throwsA(
          isA<ProtocolError>().having(
            (ProtocolError e) => e.fault,
            'fault',
            ProtocolFault.unknownFrameType,
          ),
        ),
      );
    });

    test('rechaza un frame de control que anuncia mas de 64 KB', () {
      final FrameParser parser = FrameParser();
      final ByteData header = ByteData(5)
        ..setUint8(0, FrameType.control.tag)
        ..setUint32(1, maxControlFrameBytes + 1);

      expect(
        () => parser.add(header.buffer.asUint8List()),
        throwsA(
          isA<ProtocolError>().having(
            (ProtocolError e) => e.fault,
            'fault',
            ProtocolFault.frameTooLarge,
          ),
        ),
      );
    });

    test('rechaza un frame de datos que anuncia 4 GB', () {
      // La validacion ocurre con la cabecera en la mano: nunca se reserva el
      // buffer que anuncio el par.
      final FrameParser parser = FrameParser();
      final ByteData header = ByteData(5)
        ..setUint8(0, FrameType.chunk.tag)
        ..setUint32(1, 0xFFFFFFFF);

      expect(
        () => parser.add(header.buffer.asUint8List()),
        throwsA(
          isA<ProtocolError>().having(
            (ProtocolError e) => e.fault,
            'fault',
            ProtocolFault.frameTooLarge,
          ),
        ),
      );
    });
  });

  group('readFrames', () {
    test('un cierre a mitad de frame es un error de protocolo', () {
      final Uint8List frame = encodeFrame(FrameType.chunk, <int>[1, 2, 3]);
      final Stream<List<int>> source = Stream<List<int>>.value(
        frame.sublist(0, 4),
      );

      expect(
        readFrames(source).toList(),
        throwsA(
          isA<ProtocolError>().having(
            (ProtocolError e) => e.fault,
            'fault',
            ProtocolFault.truncatedStream,
          ),
        ),
      );
    });

    test('un cierre en el limite de frame termina limpio', () async {
      final Stream<List<int>> source = Stream<List<int>>.value(
        encodeFrame(FrameType.chunk, <int>[1]),
      );
      expect(await readFrames(source).length, 1);
    });
  });
}
