import 'package:syroda/core/transfer/peer_table.dart';
import 'package:syroda/core/transfer/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

Peer peer({
  required String serviceName,
  required String deviceId,
  String name = 'Pixel de Ana',
  String host = '192.168.1.5',
  int port = 4000,
}) => Peer(
  serviceName: serviceName,
  deviceId: deviceId,
  name: name,
  platform: DevicePlatform.android,
  host: host,
  port: port,
);

void main() {
  late PeerTable table;

  setUp(() => table = PeerTable());

  test('un dispositivo bajo varios nombres es una sola fila', () {
    // El sistema renombra por conflicto cuando un registro anterior sigue
    // vivo: el mismo aparato acaba publicado como "Nombre", "Nombre (2)"...
    table.upsert(peer(serviceName: 'Pixel de Ana', deviceId: 'aaa'));
    table.upsert(peer(serviceName: 'Pixel de Ana (2)', deviceId: 'aaa'));
    table.upsert(peer(serviceName: 'Pixel de Ana (3)', deviceId: 'aaa'));

    expect(table.peers, hasLength(1));
  });

  test('dos dispositivos distintos con el mismo nombre son dos filas', () {
    // Lo contrario del caso anterior: el nombre lo pone la persona en
    // Ajustes y nada impide que dos aparatos se llamen igual.
    table.upsert(peer(serviceName: 'PC', deviceId: 'aaa'));
    table.upsert(peer(serviceName: 'PC (2)', deviceId: 'bbb'));

    expect(table.peers, hasLength(2));
  });

  test('el propio identificador no entra', () {
    table.excludeSelf('aaa');
    table.upsert(peer(serviceName: 'yo', deviceId: 'aaa'));

    expect(table.peers, isEmpty);
  });

  test('el propio identificador expulsa lo ya insertado', () {
    // La carrera real: el anuncio propio vuelve del descubrimiento antes de
    // que se sepa cual es el identificador propio. Bloquear la insercion no
    // basta, hay que sacar lo que ya entro.
    table.upsert(peer(serviceName: 'yo', deviceId: 'aaa'));
    expect(table.peers, hasLength(1));

    expect(table.excludeSelf('aaa'), isTrue);
    expect(table.peers, isEmpty);
  });

  test('un anuncio propio posterior tampoco vuelve a entrar', () {
    table.upsert(peer(serviceName: 'yo', deviceId: 'aaa'));
    table.excludeSelf('aaa');
    // Otro registro zombi de esta misma instalacion, con otro nombre.
    table.upsert(peer(serviceName: 'yo (2)', deviceId: 'aaa'));

    expect(table.peers, isEmpty);
  });

  test('el par no desaparece hasta que se va su ultimo nombre', () {
    table.upsert(peer(serviceName: 'Pixel de Ana', deviceId: 'aaa'));
    table.upsert(peer(serviceName: 'Pixel de Ana (2)', deviceId: 'aaa'));

    expect(table.remove('Pixel de Ana'), isFalse);
    expect(table.peers, hasLength(1));

    expect(table.remove('Pixel de Ana (2)'), isTrue);
    expect(table.peers, isEmpty);
  });

  test('una baja de un nombre desconocido no cambia nada', () {
    table.upsert(peer(serviceName: 'Pixel de Ana', deviceId: 'aaa'));
    expect(table.remove('otro'), isFalse);
    expect(table.peers, hasLength(1));
  });

  test('un par sin identificador se ve, con su nombre como clave', () {
    // No se puede agrupar ni reconocer como propio, pero esconderlo seria
    // peor: no cuenta como emparejado y eso ya lo decide `isPeerPaired`.
    table.upsert(peer(serviceName: 'anonimo', deviceId: ''));
    table.upsert(peer(serviceName: 'anonimo (2)', deviceId: ''));

    expect(table.peers, hasLength(2));
  });

  test('excluirse a si mismo no confunde a los pares sin identificador', () {
    table.upsert(peer(serviceName: 'anonimo', deviceId: ''));
    table.excludeSelf('aaa');

    expect(table.peers, hasLength(1));
  });

  test('reaparecer con otra direccion actualiza la fila', () {
    table.upsert(peer(serviceName: 'PC', deviceId: 'aaa', host: '10.0.0.9'));
    expect(
      table.upsert(
        peer(serviceName: 'PC', deviceId: 'aaa', host: '192.168.1.9'),
      ),
      isTrue,
    );

    expect(table.peers.single.host, '192.168.1.9');
  });

  test('el mismo anuncio repetido no reporta cambio', () {
    table.upsert(peer(serviceName: 'PC', deviceId: 'aaa'));
    expect(table.upsert(peer(serviceName: 'PC', deviceId: 'aaa')), isFalse);
  });

  test('clear vacia la tabla pero no olvida el identificador propio', () {
    table.excludeSelf('aaa');
    table.upsert(peer(serviceName: 'otro', deviceId: 'bbb'));
    expect(table.clear(), isTrue);

    table.upsert(peer(serviceName: 'yo', deviceId: 'aaa'));
    expect(table.peers, isEmpty);
  });
}
