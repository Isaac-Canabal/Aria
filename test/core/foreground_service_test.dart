import 'package:aria/core/platform/transfer_foreground_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NoTransferForegroundService service;

  setUp(() => service = NoTransferForegroundService());

  Future<void> begin() =>
      service.begin(title: 'Enviando', text: 'en la red local');

  test('la primera sesion lo enciende y la ultima lo apaga', () async {
    await begin();
    expect(service.holders, 1);
    await service.end();
    expect(service.holders, 0);
  });

  test('enviar y recibir a la vez no se apagan entre si', () async {
    await begin();
    await begin();
    expect(service.holders, 2);

    // La primera en terminar no puede dejar sin servicio a la otra.
    await service.end();
    expect(service.holders, 1);

    await service.end();
    expect(service.holders, 0);
  });

  test('soltar de mas no apaga el servicio de otra sesion', () async {
    await begin();
    await service.end();
    await service.end();
    expect(service.holders, 0);

    await begin();
    expect(service.holders, 1);
  });
}
