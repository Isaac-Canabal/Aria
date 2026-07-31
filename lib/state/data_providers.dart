/// Los proveedores de la capa de datos. Todo lo que toca disco entra por
/// aqui, para que las pruebas puedan sustituirlo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/data/app_database.dart';
import '../core/data/history_repository.dart';
import '../core/data/installation_id.dart';
import '../core/data/paired_devices_repository.dart';
import '../core/data/preferences.dart';

/// La base de datos. Las pruebas la sobreescriben con una en memoria.
final FutureProvider<Database> databaseProvider = FutureProvider<Database>((
  Ref ref,
) async {
  final Database database = await openAppDatabase();
  ref.onDispose(database.close);
  return database;
});

final FutureProvider<HistoryRepository> historyRepositoryProvider =
    FutureProvider<HistoryRepository>((Ref ref) async {
      final HistoryRepository repository = HistoryRepository(
        await ref.watch(databaseProvider.future),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final FutureProvider<PairedDevicesRepository> pairedDevicesRepositoryProvider =
    FutureProvider<PairedDevicesRepository>((Ref ref) async {
      final PairedDevicesRepository repository = PairedDevicesRepository(
        await ref.watch(databaseProvider.future),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final FutureProvider<SettingsStore> settingsStoreProvider =
    FutureProvider<SettingsStore>((Ref ref) => SettingsStore.open());

/// El identificador estable de esta instalacion. Se crea la primera vez que
/// se lee y no cambia mas.
final FutureProvider<String> installationIdProvider = FutureProvider<String>(
  (Ref ref) async =>
      readOrCreateInstallationId(await SharedPreferences.getInstance()),
);
