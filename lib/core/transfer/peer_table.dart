/// La tabla de pares descubiertos.
///
/// Vive aparte de `NsdDiscoveryService` porque es la unica parte del
/// descubrimiento que se puede probar sin la red ni el plugin: recibe
/// altas y bajas y decide que se ve.
library;

import 'peer.dart';

/// Indexa por `device_id`, **no** por el nombre de instancia mDNS.
///
/// El nombre es efimero y el sistema lo renombra por conflicto ("Nombre" ->
/// "Nombre (2)") cuando un registro anterior no se dio de baja, asi que el
/// mismo dispositivo puede estar en la red bajo varios nombres a la vez.
/// Indexado por nombre salia repetido, una fila por registro; indexado por
/// `device_id` es un dispositivo, una fila.
class PeerTable {
  final Map<String, Peer> _byDevice = <String, Peer>{};

  /// Nombre de instancia -> clave del dispositivo. Las bajas llegan con el
  /// nombre, que es lo unico que trae el evento `lost`.
  final Map<String, String> _keyByService = <String, String>{};

  String? _ownDeviceId;

  List<Peer> get peers => List<Peer>.unmodifiable(_byDevice.values);

  /// El identificador de esta instalacion, para no listarse a si mismo.
  ///
  /// Se sabe **antes** de anunciar, a diferencia del nombre de instancia, que
  /// solo se conoce cuando el registro vuelve. Por eso el filtro por
  /// `device_id` no tiene la carrera que tenia el filtro por nombre.
  ///
  /// Expulsa lo que ya hubiera entrado: un anuncio propio puede haberse
  /// colado antes, y tambien puede quedar en la red un registro zombi de un
  /// arranque anterior de esta misma instalacion.
  bool excludeSelf(String deviceId) {
    if (deviceId.isEmpty) return false;
    _ownDeviceId = deviceId;
    _keyByService.removeWhere((_, String key) => key == deviceId);
    return _byDevice.remove(deviceId) != null;
  }

  /// Da de alta o actualiza. Devuelve si cambio algo de lo que se ve.
  bool upsert(Peer peer) {
    if (_ownDeviceId != null && peer.deviceId == _ownDeviceId) {
      // No basta con bloquear la insercion: si este anuncio propio entro
      // antes de saber cual era el identificador, hay que sacarlo.
      return _removeService(peer.serviceName);
    }

    final String key = _keyFor(peer);
    _keyByService[peer.serviceName] = key;
    final Peer? previous = _byDevice[key];
    _byDevice[key] = peer;
    return previous != peer;
  }

  /// Da de baja el registro con ese nombre de instancia.
  bool remove(String serviceName) => _removeService(serviceName);

  bool clear() {
    final bool had = _byDevice.isNotEmpty;
    _byDevice.clear();
    _keyByService.clear();
    return had;
  }

  bool _removeService(String serviceName) {
    final String? key = _keyByService.remove(serviceName);
    if (key == null) return false;
    // El mismo dispositivo puede seguir publicado bajo otro nombre: solo
    // desaparece de la lista cuando se va el ultimo de sus registros.
    if (_keyByService.containsValue(key)) return false;
    return _byDevice.remove(key) != null;
  }

  /// Un par que no publica identificador no se puede agrupar ni reconocer
  /// como propio: se le deja su nombre de instancia como clave para que al
  /// menos se vea. No cuenta como emparejado, que es lo que ya dice
  /// `isPeerPaired`.
  String _keyFor(Peer peer) =>
      peer.deviceId.isNotEmpty ? peer.deviceId : 'service:${peer.serviceName}';
}
