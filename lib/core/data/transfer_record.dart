/// Una entrada del historial: lo que muestran la lista del movil y la tabla
/// del escritorio.
library;

import '../transfer/peer.dart';
import '../transfer/protocol/messages.dart';

/// "Enviado" / "Recibido" en la columna Direccion.
enum TransferDirection {
  sent('sent'),
  received('received');

  const TransferDirection(this.wire);

  final String wire;

  static TransferDirection fromWire(String value) =>
      values.firstWhere((TransferDirection d) => d.wire == value);
}

/// El historial solo guarda estados terminales: lo que esta en curso vive en
/// la cola, no aqui.
enum TransferStatus {
  completed('completed'),
  failed('failed');

  const TransferStatus(this.wire);

  final String wire;

  static TransferStatus fromWire(String value) =>
      values.firstWhere((TransferStatus s) => s.wire == value);
}

class TransferRecord {
  const TransferRecord({
    this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.direction,
    required this.peerName,
    required this.peerPlatform,
    required this.completedAt,
    required this.status,
    this.failure,
    this.localPath,
  });

  /// Nulo hasta que la base de datos lo asigna.
  final int? id;

  final String fileName;
  final int sizeBytes;
  final TransferDirection direction;
  final String peerName;
  final DevicePlatform peerPlatform;

  /// Siempre en UTC. La zona la aplica quien lo muestra.
  final DateTime completedAt;

  final TransferStatus status;

  /// Por que fallo, cuando [status] es [TransferStatus.failed].
  final FileFailure? failure;

  /// Donde quedo el archivo, solo para los recibidos que llegaron completos.
  final String? localPath;

  TransferRecord copyWith({int? id}) => TransferRecord(
    id: id ?? this.id,
    fileName: fileName,
    sizeBytes: sizeBytes,
    direction: direction,
    peerName: peerName,
    peerPlatform: peerPlatform,
    completedAt: completedAt,
    status: status,
    failure: failure,
    localPath: localPath,
  );

  Map<String, Object?> toRow() => <String, Object?>{
    if (id != null) 'id': id,
    'file_name': fileName,
    'size_bytes': sizeBytes,
    'direction': direction.wire,
    'peer_name': peerName,
    'peer_platform': peerPlatform.wire,
    'completed_at': completedAt.toUtc().millisecondsSinceEpoch,
    'status': status.wire,
    'failure': failure?.name,
    'local_path': localPath,
  };

  static TransferRecord fromRow(Map<String, Object?> row) => TransferRecord(
    id: row['id'] as int?,
    fileName: row['file_name']! as String,
    sizeBytes: row['size_bytes']! as int,
    direction: TransferDirection.fromWire(row['direction']! as String),
    peerName: row['peer_name']! as String,
    peerPlatform: DevicePlatform.fromWire(row['peer_platform'] as String?),
    completedAt: DateTime.fromMillisecondsSinceEpoch(
      row['completed_at']! as int,
      isUtc: true,
    ),
    status: TransferStatus.fromWire(row['status']! as String),
    failure: _failureFromWire(row['failure'] as String?),
    localPath: row['local_path'] as String?,
  );

  static FileFailure? _failureFromWire(String? value) {
    if (value == null) return null;
    for (final FileFailure failure in FileFailure.values) {
      if (failure.name == value) return failure;
    }
    return null;
  }
}
