/// El formato de cable: `[u8 tipo][u32 longitud big-endian][payload]`.
///
/// El tag de tipo va **antes** de la longitud a proposito. Sin el, un frame de
/// control y uno de datos solo se distinguirian por su posicion en la sesion,
/// y entonces no se podrian intercalar mensajes de control a mitad de una
/// transferencia: cancelacion, y el handshake del canal cuando llegue SPAKE2.
library;

import 'dart:typed_data';

import '../errors.dart';
import 'limits.dart';

/// Los tipos asignados. El rango 0x03-0x7F queda reservado para el protocolo
/// y 0x80-0xFF sin asignar; ambos se rechazan hoy.
enum FrameType {
  /// Un objeto JSON UTF-8. Ver `messages.dart`.
  control(0x01),

  /// Bytes del archivo, crudos, sin envolver.
  chunk(0x02);

  const FrameType(this.tag);

  final int tag;

  static FrameType? fromTag(int tag) {
    for (final FrameType type in values) {
      if (type.tag == tag) return type;
    }
    return null;
  }

  /// El techo de longitud que acepta cada tipo.
  int get maxPayloadBytes => switch (this) {
    FrameType.control => maxControlFrameBytes,
    FrameType.chunk => maxChunkFrameBytes,
  };
}

class Frame {
  const Frame(this.type, this.payload);

  final FrameType type;
  final Uint8List payload;
}

/// Cabecera de 5 bytes: tipo mas longitud.
const int frameHeaderBytes = 5;

Uint8List encodeFrame(FrameType type, List<int> payload) {
  final Uint8List out = Uint8List(frameHeaderBytes + payload.length);
  out[0] = type.tag;
  // Big-endian explicito: el orden de red, y el mismo en las dos plataformas.
  final ByteData view = ByteData.sublistView(out);
  view.setUint32(1, payload.length);
  out.setRange(frameHeaderBytes, out.length, payload);
  return out;
}

/// Reconstruye frames a partir de los trozos con que llegan del socket, que
/// no respetan los limites de frame.
class FrameParser {
  Uint8List _pending = Uint8List(0);

  /// Bytes que quedaron a medias de un frame.
  int get pendingBytes => _pending.length;

  /// Consume [data] y devuelve los frames completos que se hayan formado.
  ///
  /// Lanza [ProtocolError] si el tipo no esta asignado o si la longitud
  /// anunciada supera el limite del tipo. La validacion ocurre antes de
  /// reservar nada: nunca se asigna un buffer del tamano que anuncio el par.
  List<Frame> add(List<int> data) {
    _pending = _concat(_pending, data);

    final List<Frame> frames = <Frame>[];
    int offset = 0;
    while (_pending.length - offset >= frameHeaderBytes) {
      final int tag = _pending[offset];
      final FrameType? type = FrameType.fromTag(tag);
      if (type == null) {
        throw ProtocolError(
          ProtocolFault.unknownFrameType,
          detail: '0x${tag.toRadixString(16)}',
        );
      }

      final int length = ByteData.sublistView(
        _pending,
        offset + 1,
        offset + frameHeaderBytes,
      ).getUint32(0);
      if (length > type.maxPayloadBytes) {
        throw ProtocolError(
          ProtocolFault.frameTooLarge,
          detail: '${type.name}: $length > ${type.maxPayloadBytes}',
        );
      }

      final int end = offset + frameHeaderBytes + length;
      if (_pending.length < end) break; // falta cola: esperar mas bytes
      frames.add(
        Frame(
          type,
          Uint8List.sublistView(_pending, offset + frameHeaderBytes, end),
        ),
      );
      offset = end;
    }

    _pending = offset == 0
        ? _pending
        : Uint8List.fromList(
            Uint8List.sublistView(_pending, offset),
          );
    return frames;
  }

  static Uint8List _concat(Uint8List a, List<int> b) {
    if (a.isEmpty) return b is Uint8List ? b : Uint8List.fromList(b);
    final Uint8List out = Uint8List(a.length + b.length);
    out.setRange(0, a.length, a);
    out.setRange(a.length, out.length, b);
    return out;
  }
}

/// Envuelve un flujo de bytes en un flujo de frames.
///
/// Si el flujo termina con un frame a medias es un cierre a destiempo, no un
/// final limpio.
Stream<Frame> readFrames(Stream<List<int>> source) async* {
  final FrameParser parser = FrameParser();
  await for (final List<int> data in source) {
    yield* Stream<Frame>.fromIterable(parser.add(data));
  }
  if (parser.pendingBytes > 0) {
    throw const ProtocolError(ProtocolFault.truncatedStream);
  }
}
