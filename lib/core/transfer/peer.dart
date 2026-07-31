/// Lo que un dispositivo publica de si mismo y lo que se descubre de otros.
library;

/// La plataforma viaja en el TXT del anuncio y en el handshake: decide el
/// icono de la fila (`.row-icon` con telefono o pantalla) en los mockups.
enum DevicePlatform {
  android('android'),
  windows('windows'),

  /// Un par que anuncia algo que esta version no conoce. Se muestra, no se
  /// rechaza.
  unknown('unknown');

  const DevicePlatform(this.wire);

  final String wire;

  static DevicePlatform fromWire(String? value) {
    for (final DevicePlatform platform in values) {
      if (platform.wire == value) return platform;
    }
    return DevicePlatform.unknown;
  }
}

/// La identidad con la que este dispositivo se anuncia.
class DeviceIdentity {
  const DeviceIdentity({
    required this.id,
    required this.name,
    required this.platform,
  });

  /// El identificador estable de esta instalacion. Ver `installation_id.dart`:
  /// no es el nombre, que la persona cambia, ni la IP, que cambia sola.
  final String id;

  /// El nombre editable de Ajustes: "Pixel de mi".
  final String name;

  final DevicePlatform platform;
}

/// Un par encontrado en la red local.
class Peer {
  const Peer({
    required this.serviceName,
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.host,
    required this.port,
  });

  /// El nombre del servicio mDNS, unico dentro de la red pero no estable
  /// entre sesiones: sirve para seguir la aparicion y desaparicion del par.
  final String serviceName;

  /// El identificador estable del par, el que se guarda al emparejar. Vacio
  /// si el par no lo publica.
  final String deviceId;

  final String name;
  final DevicePlatform platform;
  final String host;

  /// Efimero: sale del `bind(0)` del receptor y viaja en el TXT. Nada puede
  /// asumir un numero fijo.
  final int port;

  @override
  bool operator ==(Object other) =>
      other is Peer &&
      other.serviceName == serviceName &&
      other.deviceId == deviceId &&
      other.host == host &&
      other.port == port &&
      other.name == name &&
      other.platform == platform;

  @override
  int get hashCode =>
      Object.hash(serviceName, deviceId, host, port, name, platform);

  @override
  String toString() => 'Peer($name, ${platform.wire}, $host:$port)';
}
