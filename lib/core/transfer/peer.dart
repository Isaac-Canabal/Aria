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
    required this.addresses,
    required this.port,
  });

  /// Atajo para el par de una sola direccion: el emparejamiento manual y las
  /// pruebas.
  Peer.at({
    required String host,
    required this.serviceName,
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.port,
  }) : addresses = <String>[host];

  /// El nombre del servicio mDNS, unico dentro de la red pero no estable
  /// entre sesiones: sirve para seguir la aparicion y desaparicion del par.
  final String serviceName;

  /// El identificador estable del par, el que se guarda al emparejar. Vacio
  /// si el par no lo publica.
  final String deviceId;

  final String name;
  final DevicePlatform platform;

  /// **Todas** las direcciones con las que se resolvio el par, en el orden en
  /// que llegaron.
  ///
  /// Un equipo con adaptadores virtuales (WSL2, VPN, Docker) resuelve a
  /// varias, y desde fuera no hay forma de saber cual es la alcanzable:
  /// quedarse con la primera dejaba al par visible y no conectable. Se
  /// guardan todas y se elige al conectar, probandolas en orden.
  final List<String> addresses;

  /// Efimero: sale del `bind(0)` del receptor y viaja en el TXT. Nada puede
  /// asumir un numero fijo.
  final int port;

  @override
  bool operator ==(Object other) =>
      other is Peer &&
      other.serviceName == serviceName &&
      other.deviceId == deviceId &&
      _sameAddresses(other.addresses) &&
      other.port == port &&
      other.name == name &&
      other.platform == platform;

  bool _sameAddresses(List<String> other) {
    if (other.length != addresses.length) return false;
    for (int i = 0; i < addresses.length; i++) {
      if (other[i] != addresses[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    serviceName,
    deviceId,
    Object.hashAll(addresses),
    port,
    name,
    platform,
  );

  @override
  String toString() =>
      'Peer($name, ${platform.wire}, ${addresses.join(", ")}:$port)';
}

/// Ordena las direcciones de un par por probabilidad de ser la alcanzable.
///
/// Primero las que comparten prefijo /24 con alguna direccion local: es la
/// unica senal fuerte que hay desde fuera, y es la que separa la Wi-Fi real
/// de los adaptadores virtuales (WSL2, VPN, Docker) de un equipo con varios.
///
/// El /24 es una suposicion —`dart:io` no expone la mascara de red de las
/// interfaces—, pero **es solo un orden, no un filtro**: si la suposicion
/// falla, la direccion buena sigue en la lista y se prueba despues. Ordenar
/// mal cuesta tiempo, nunca la conexion.
List<String> orderCandidates(
  List<String> candidates,
  List<String> localAddresses,
) {
  final Set<String> localPrefixes = <String>{
    for (final String local in localAddresses)
      if (_prefix24(local) case final String prefix) prefix,
  };

  final List<String> near = <String>[];
  final List<String> far = <String>[];
  for (final String candidate in candidates) {
    final String? prefix = _prefix24(candidate);
    (prefix != null && localPrefixes.contains(prefix) ? near : far).add(
      candidate,
    );
  }
  return <String>[...near, ...far];
}

/// Los tres primeros octetos de una IPv4, o `null` si no lo es. IPv6 no
/// participa del orden: se prueba igual, detras.
String? _prefix24(String address) {
  final List<String> parts = address.split('.');
  if (parts.length != 4) return null;
  for (final String part in parts) {
    if (part.isEmpty || int.tryParse(part) == null) return null;
  }
  return '${parts[0]}.${parts[1]}.${parts[2]}';
}
