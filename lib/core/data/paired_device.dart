/// Un dispositivo con el que ya se completo un emparejamiento.
library;

import '../transfer/peer.dart';

class PairedDevice {
  const PairedDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.pairedAt,
  });

  /// El identificador estable del par. Ver `installation_id.dart`: no es el
  /// nombre, que cambia, ni la IP, que cambia sola.
  final String deviceId;

  /// El nombre que mostraba la ultima vez. Se actualiza en cada
  /// emparejamiento.
  final String name;

  final DevicePlatform platform;

  /// Ultimo emparejamiento exitoso, en UTC.
  final DateTime pairedAt;

  Map<String, Object?> toRow() => <String, Object?>{
    'device_id': deviceId,
    'name': name,
    'platform': platform.wire,
    'paired_at': pairedAt.toUtc().millisecondsSinceEpoch,
  };

  static PairedDevice fromRow(Map<String, Object?> row) => PairedDevice(
    deviceId: row['device_id']! as String,
    name: row['name']! as String,
    platform: DevicePlatform.fromWire(row['platform'] as String?),
    pairedAt: DateTime.fromMillisecondsSinceEpoch(
      row['paired_at']! as int,
      isUtc: true,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is PairedDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      other.pairedAt == pairedAt;

  @override
  int get hashCode => Object.hash(deviceId, name, platform, pairedAt);
}
