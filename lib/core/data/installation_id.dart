/// El identificador estable de esta instalacion.
///
/// **Que es**: 16 bytes de `Random.secure()` en hexadecimal, generados la
/// primera vez que arranca la app y guardados en las preferencias.
///
/// **Que no es**: ni el nombre del dispositivo, que la persona cambia en
/// Ajustes, ni la IP, que cambia al reconectar a otra red. Emparejar contra
/// cualquiera de los dos significaria olvidar el par cuando le cambian el
/// nombre, o confiar en quien herede su IP.
///
/// **Por que no un identificador de la plataforma** (`ANDROID_ID`,
/// `MachineGuid`): obligarian a codigo nativo en cada plataforma, identifican
/// el aparato mas alla de esta app, y no aportan nada aqui. Lo que el
/// emparejamiento necesita es continuidad de esta instalacion, no la
/// identidad del hardware. El precio es que reinstalar pierde los
/// emparejamientos, que es el comportamiento correcto.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

const String _key = 'installation_id';

/// Longitud en bytes. 128 bits: la colision entre dos dispositivos de una LAN
/// no es un escenario que valga la pena considerar.
const int installationIdBytes = 16;

/// Devuelve el identificador de esta instalacion, creandolo la primera vez.
Future<String> readOrCreateInstallationId(
  SharedPreferences preferences, {
  Random? random,
}) async {
  final String? existing = preferences.getString(_key);
  if (existing != null && existing.length == installationIdBytes * 2) {
    return existing;
  }

  final String created = generateInstallationId(random: random);
  await preferences.setString(_key, created);
  return created;
}

String generateInstallationId({Random? random}) {
  final Random source = random ?? Random.secure();
  final Uint8List bytes = Uint8List(installationIdBytes);
  for (int i = 0; i < bytes.length; i++) {
    bytes[i] = source.nextInt(256);
  }
  return <String>[
    for (final int byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
}
