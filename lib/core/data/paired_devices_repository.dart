/// Los dispositivos ya emparejados.
///
/// Sin esto, "Solo dispositivos emparejados" no se puede cumplir y "Olvidar
/// dispositivos emparejados" no tiene sobre que operar.
library;

import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'paired_device.dart';

class PairedDevicesRepository {
  PairedDevicesRepository(this._db);

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Misma forma que el historial: avisa y quien lee vuelve a consultar.
  Stream<void> get changes => _changes.stream;

  /// Guarda el emparejamiento, o refresca el nombre y la fecha si el par ya
  /// estaba: un dispositivo renombrado sigue siendo el mismo.
  Future<PairedDevice> remember(PairedDevice device) async {
    await _db.insert(
      'paired_devices',
      device.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
    return device;
  }

  Future<List<PairedDevice>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'paired_devices',
      orderBy: 'paired_at DESC',
    );
    return rows.map(PairedDevice.fromRow).toList();
  }

  Future<PairedDevice?> find(String deviceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'paired_devices',
      where: 'device_id = ?',
      whereArgs: <Object>[deviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : PairedDevice.fromRow(rows.first);
  }

  Future<bool> isPaired(String deviceId) async =>
      deviceId.isNotEmpty && await find(deviceId) != null;

  Future<void> forget(String deviceId) async {
    await _db.delete(
      'paired_devices',
      where: 'device_id = ?',
      whereArgs: <Object>[deviceId],
    );
    _notify();
  }

  /// La accion de Ajustes: los borra todos.
  Future<void> forgetAll() async {
    await _db.delete('paired_devices');
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
