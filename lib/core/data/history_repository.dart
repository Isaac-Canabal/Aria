/// Lectura y escritura del historial de transferencias.
library;

import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'transfer_record.dart';

/// Cuantas entradas se cargan de una: el historial no se pagina en v1, pero
/// tampoco se trae entero si crece.
const int historyPageSize = 200;

class HistoryRepository {
  HistoryRepository(this._db);

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Avisa que el historial cambio. `sqflite` no notifica por si solo, asi
  /// que quien escribe lo anuncia y quien lee vuelve a consultar.
  Stream<void> get changes => _changes.stream;

  Future<TransferRecord> add(TransferRecord record) async {
    final int id = await _db.insert('transfers', record.toRow());
    _notify();
    return record.copyWith(id: id);
  }

  Future<List<TransferRecord>> recent({int limit = historyPageSize}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'transfers',
      orderBy: 'completed_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransferRecord.fromRow).toList();
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM transfers'),
      ) ??
      0;

  Future<void> remove(int id) async {
    await _db.delete('transfers', where: 'id = ?', whereArgs: <Object>[id]);
    _notify();
  }

  Future<void> clear() async {
    await _db.delete('transfers');
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
