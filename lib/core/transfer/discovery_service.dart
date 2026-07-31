/// Anuncio y descubrimiento de pares por mDNS/DNS-SD.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import 'peer.dart';

/// El tipo de servicio de Aria.
const String ariaServiceType = '_aria._tcp';

/// Claves del registro TXT.
abstract final class TxtKeys {
  static const String name = 'name';
  static const String platform = 'platform';

  /// El puerto tambien viaja aqui, ademas de en el SRV: el receptor lo obtuvo
  /// de un `bind(0)` y nada puede asumir un numero fijo.
  static const String port = 'port';

  /// El identificador estable, para reconocer un par ya emparejado antes de
  /// conectarse a el.
  static const String deviceId = 'id';
}

abstract interface class DiscoveryService {
  /// Publica este dispositivo en la red local.
  Future<void> announce({required DeviceIdentity identity, required int port});

  Future<void> stopAnnouncing();

  Future<void> startDiscovery();

  Future<void> stopDiscovery();

  /// La lista completa de pares, cada vez que cambia.
  Stream<List<Peer>> get peers;

  Future<void> dispose();
}

/// Implementacion sobre `nsd`, que en Windows registra con
/// `DnsServiceRegister` (Windows 10 build 18362 en adelante) y en Android
/// sobre `NsdManager`.
class NsdDiscoveryService implements DiscoveryService {
  final StreamController<List<Peer>> _peers =
      StreamController<List<Peer>>.broadcast();
  final Map<String, Peer> _found = <String, Peer>{};

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  /// El nombre con el que quedo registrado este dispositivo. El sistema puede
  /// cambiarlo si ya existe ("Aria" -> "Aria (2)"), y hay que conocerlo para
  /// no listarse a si mismo.
  String? _ownServiceName;

  @override
  Stream<List<Peer>> get peers => _peers.stream;

  @override
  Future<void> announce({
    required DeviceIdentity identity,
    required int port,
  }) async {
    await stopAnnouncing();
    _registration = await nsd.register(
      nsd.Service(
        name: identity.name,
        type: ariaServiceType,
        port: port,
        txt: <String, Uint8List?>{
          TxtKeys.name: _encode(identity.name),
          TxtKeys.platform: _encode(identity.platform.wire),
          TxtKeys.port: _encode('$port'),
          TxtKeys.deviceId: _encode(identity.id),
        },
      ),
    );
    _ownServiceName = _registration?.service.name;
  }

  @override
  Future<void> stopAnnouncing() async {
    final nsd.Registration? registration = _registration;
    if (registration == null) return;
    _registration = null;
    _ownServiceName = null;
    await nsd.unregister(registration);
  }

  @override
  Future<void> startDiscovery() async {
    if (_discovery != null) return;
    final nsd.Discovery discovery = await nsd.startDiscovery(
      ariaServiceType,
      ipLookupType: nsd.IpLookupType.any,
    );
    _discovery = discovery;
    discovery.addServiceListener(_onService);
  }

  void _onService(nsd.Service service, nsd.ServiceStatus status) {
    final String? id = service.name;
    if (id == null || id == _ownServiceName) return;

    switch (status) {
      case nsd.ServiceStatus.found:
        final Peer? peer = _toPeer(service);
        if (peer != null) _found[id] = peer;
      case nsd.ServiceStatus.lost:
        _found.remove(id);
    }
    if (!_peers.isClosed) _peers.add(List<Peer>.unmodifiable(_found.values));
  }

  Peer? _toPeer(nsd.Service service) {
    final String? host = service.addresses?.isNotEmpty ?? false
        ? service.addresses!.first.address
        : service.host;
    // El puerto del TXT manda sobre el del SRV: es el que el par acaba de
    // obtener de su bind(0).
    final int? port =
        int.tryParse(_decode(service.txt?[TxtKeys.port]) ?? '') ?? service.port;
    if (host == null || port == null || port <= 0) return null;

    return Peer(
      serviceName: service.name!,
      deviceId: _decode(service.txt?[TxtKeys.deviceId]) ?? '',
      name: _decode(service.txt?[TxtKeys.name]) ?? service.name!,
      platform: DevicePlatform.fromWire(
        _decode(service.txt?[TxtKeys.platform]),
      ),
      host: host,
      port: port,
    );
  }

  @override
  Future<void> stopDiscovery() async {
    final nsd.Discovery? discovery = _discovery;
    if (discovery == null) return;
    _discovery = null;
    discovery.removeServiceListener(_onService);
    _found.clear();
    await nsd.stopDiscovery(discovery);
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await stopAnnouncing();
    await _peers.close();
  }

  static Uint8List _encode(String value) =>
      Uint8List.fromList(utf8.encode(value));

  static String? _decode(Uint8List? value) {
    if (value == null) return null;
    try {
      return utf8.decode(value);
    } on FormatException {
      return null;
    }
  }
}

/// El nombre por defecto con el que se anuncia el equipo, antes de que la
/// persona lo cambie en Ajustes.
String defaultDeviceName() => Platform.localHostname;

/// La direccion IPv4 de este dispositivo en la red local, o `null` si no hay
/// ninguna. Es lo que se teclea cuando el descubrimiento no funciona.
Future<String?> localAddress() async {
  final List<NetworkInterface> interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final NetworkInterface interface in interfaces) {
    for (final InternetAddress address in interface.addresses) {
      if (!address.isLoopback) return address.address;
    }
  }
  return null;
}

DevicePlatform currentPlatform() => Platform.isAndroid
    ? DevicePlatform.android
    : Platform.isWindows
    ? DevicePlatform.windows
    : DevicePlatform.unknown;
