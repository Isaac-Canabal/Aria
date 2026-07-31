/// Anuncio y descubrimiento de pares por mDNS/DNS-SD.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import 'peer.dart';
import 'peer_table.dart';

/// El tipo de servicio de Syroda.
const String syrodaServiceType = '_syroda._tcp';

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

  /// El identificador de esta instalacion, para no listarse a si mismo.
  ///
  /// Se declara aparte de [announce] porque hace falta tambien cuando este
  /// dispositivo no se esta anunciando: en la red puede quedar un registro
  /// zombi de un arranque anterior de esta misma instalacion, y sin esto se
  /// mostraria como si fuera otro par.
  void excludeSelf(String deviceId);

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
  final PeerTable _table = PeerTable();

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  @override
  Stream<List<Peer>> get peers => _peers.stream;

  @override
  void excludeSelf(String deviceId) {
    if (_table.excludeSelf(deviceId)) _emit();
  }

  @override
  Future<void> announce({
    required DeviceIdentity identity,
    required int port,
  }) async {
    await stopAnnouncing();
    // Antes de registrar, no despues: el identificador ya se conoce y el
    // anuncio propio puede volver del descubrimiento en cuanto salga a la
    // red, sin esperar a que `register` termine.
    excludeSelf(identity.id);
    _registration = await nsd.register(
      nsd.Service(
        name: identity.name,
        type: syrodaServiceType,
        port: port,
        txt: <String, Uint8List?>{
          TxtKeys.name: _encode(identity.name),
          TxtKeys.platform: _encode(identity.platform.wire),
          TxtKeys.port: _encode('$port'),
          TxtKeys.deviceId: _encode(identity.id),
        },
      ),
    );
  }

  @override
  Future<void> stopAnnouncing() async {
    final nsd.Registration? registration = _registration;
    if (registration == null) return;
    _registration = null;
    // El identificador propio no se olvida al dejar de anunciar: el registro
    // puede tardar en caducar en la red y seguiria volviendo como par.
    await nsd.unregister(registration);
  }

  @override
  Future<void> startDiscovery() async {
    if (_discovery != null) return;
    final nsd.Discovery discovery = await nsd.startDiscovery(
      syrodaServiceType,
      ipLookupType: nsd.IpLookupType.any,
    );
    _discovery = discovery;
    discovery.addServiceListener(_onService);
  }

  void _onService(nsd.Service service, nsd.ServiceStatus status) {
    final String? serviceName = service.name;
    if (serviceName == null) return;

    final bool changed = switch (status) {
      nsd.ServiceStatus.found => switch (_toPeer(service)) {
        final Peer peer => _table.upsert(peer),
        null => false,
      },
      nsd.ServiceStatus.lost => _table.remove(serviceName),
    };
    if (changed) _emit();
  }

  void _emit() {
    if (!_peers.isClosed) _peers.add(_table.peers);
  }

  Peer? _toPeer(nsd.Service service) {
    // Todas, no la primera: un equipo con adaptadores virtuales resuelve a
    // varias y desde aqui no hay forma de saber cual es la alcanzable. La
    // eleccion es del que conecta.
    final List<String> addresses = <String>[
      for (final InternetAddress address in service.addresses ?? const [])
        address.address,
    ];
    if (addresses.isEmpty && service.host != null) addresses.add(service.host!);

    // El puerto del TXT manda sobre el del SRV: es el que el par acaba de
    // obtener de su bind(0).
    final int? port =
        int.tryParse(_decode(service.txt?[TxtKeys.port]) ?? '') ?? service.port;
    if (addresses.isEmpty || port == null || port <= 0) return null;

    return Peer(
      serviceName: service.name!,
      deviceId: _decode(service.txt?[TxtKeys.deviceId]) ?? '',
      name: _decode(service.txt?[TxtKeys.name]) ?? service.name!,
      platform: DevicePlatform.fromWire(
        _decode(service.txt?[TxtKeys.platform]),
      ),
      addresses: addresses,
      port: port,
    );
  }

  @override
  Future<void> stopDiscovery() async {
    final nsd.Discovery? discovery = _discovery;
    if (discovery == null) return;
    _discovery = null;
    discovery.removeServiceListener(_onService);
    _table.clear();
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

/// Todas las direcciones IPv4 de este equipo, sin loopback.
///
/// En un equipo con adaptadores virtuales son varias. Sirven para ordenar las
/// candidatas de un par por cercania (ver [orderCandidates]), no para
/// mostrarlas.
Future<List<String>> localAddresses() async {
  final List<NetworkInterface> interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  return <String>[
    for (final NetworkInterface interface in interfaces)
      for (final InternetAddress address in interface.addresses)
        if (!address.isLoopback) address.address,
  ];
}

/// La direccion IPv4 de este dispositivo en la red local, o `null` si no hay
/// ninguna. Es lo que se teclea cuando el descubrimiento no funciona.
Future<String?> localAddress() async {
  final List<String> all = await localAddresses();
  return all.isEmpty ? null : all.first;
}

DevicePlatform currentPlatform() => Platform.isAndroid
    ? DevicePlatform.android
    : Platform.isWindows
    ? DevicePlatform.windows
    : DevicePlatform.unknown;
