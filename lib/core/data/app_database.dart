/// Apertura, esquema y migraciones de la base de datos local.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// `sqflite_common_ffi` reexporta la API de `sqflite`, asi que basta con este
// import para las dos plataformas.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Nombre del archivo dentro del directorio de soporte de la app.
const String databaseFileName = 'syroda.db';

/// La escalera de migraciones, una por version.
///
/// **Nunca se edita una migracion ya publicada**: la base de un usuario que
/// venga de esa version la ejecuto tal como estaba. Un cambio de esquema se
/// hace agregando una entrada al final. Borrar la base para "resolver" una
/// columna nueva pierde el historial de la persona, y eso no es una opcion.
const List<String Function()> _migrations = <String Function()>[
  _v1Transfers,
  _v2PairedDevices,
];

/// La version actual: la longitud de la escalera.
int get schemaVersion => _migrations.length;

String _v1Transfers() => '''
  CREATE TABLE transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    direction TEXT NOT NULL,
    peer_name TEXT NOT NULL,
    peer_platform TEXT NOT NULL,
    completed_at INTEGER NOT NULL,
    status TEXT NOT NULL,
    failure TEXT,
    local_path TEXT
  );
  CREATE INDEX idx_transfers_completed_at ON transfers (completed_at DESC);
''';

String _v2PairedDevices() => '''
  CREATE TABLE paired_devices (
    device_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    platform TEXT NOT NULL,
    paired_at INTEGER NOT NULL
  );
  CREATE INDEX idx_paired_devices_paired_at
    ON paired_devices (paired_at DESC);
''';

/// En escritorio no hay sqflite nativo: hay que enchufar la implementacion
/// sobre FFI antes de abrir nada. Se llama una sola vez.
void initDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

/// Abre la base de datos de la app y la deja en [schemaVersion].
///
/// [path] existe para las pruebas, que usan [inMemoryDatabasePath] o un
/// archivo temporal. En la app el archivo vive junto a los datos de soporte,
/// no en documentos: es estado interno, no algo que la persona deba ver.
///
/// [version] tambien es para las pruebas: permite abrir la base a una version
/// vieja para comprobar que la migracion la trae al dia sin perder nada.
Future<Database> openAppDatabase({String? path, int? version}) async {
  initDatabaseFactory();

  final String target;
  if (path != null) {
    target = path;
  } else {
    final Directory support = await getApplicationSupportDirectory();
    target = p.join(support.path, databaseFileName);
  }

  final int target_ = version ?? schemaVersion;
  return openDatabase(
    target,
    version: target_,
    onConfigure: (Database db) => db.execute('PRAGMA foreign_keys = ON'),
    // Una base nueva no es un caso aparte: se le corre la escalera entera.
    onCreate: (Database db, int version) =>
        _run(db, from: 0, to: version),
    onUpgrade: (Database db, int from, int to) => _run(db, from: from, to: to),
  );
}

Future<void> _run(Database db, {required int from, required int to}) async {
  for (int version = from + 1; version <= to; version++) {
    for (final String statement in _migrations[version - 1]().split(';')) {
      final String sql = statement.trim();
      if (sql.isNotEmpty) await db.execute(sql);
    }
  }
}
