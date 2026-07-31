/// El estado del historial.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/history_repository.dart';
import '../core/data/transfer_record.dart';
import 'data_providers.dart';

class HistoryController extends AsyncNotifier<List<TransferRecord>> {
  @override
  Future<List<TransferRecord>> build() async {
    final HistoryRepository repository = await ref.watch(
      historyRepositoryProvider.future,
    );

    // `sqflite` no notifica cambios: el repositorio avisa y aqui se vuelve a
    // consultar. Es barato porque el historial se lee entero de una pagina.
    final StreamSubscription<void> subscription = repository.changes.listen(
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(subscription.cancel);

    return repository.recent();
  }

  Future<void> record(TransferRecord entry) async {
    final HistoryRepository repository = await ref.read(
      historyRepositoryProvider.future,
    );
    await repository.add(entry);
  }

  Future<void> remove(int id) async {
    final HistoryRepository repository = await ref.read(
      historyRepositoryProvider.future,
    );
    await repository.remove(id);
  }

  Future<void> clear() async {
    final HistoryRepository repository = await ref.read(
      historyRepositoryProvider.future,
    );
    await repository.clear();
  }
}

final AsyncNotifierProvider<HistoryController, List<TransferRecord>>
historyProvider =
    AsyncNotifierProvider<HistoryController, List<TransferRecord>>(
      HistoryController.new,
    );

/// El historial esta vacio: es lo que decide entre la lista y la pantalla
/// "Aun no hay envios" de los mockups.
final Provider<bool> historyIsEmptyProvider = Provider<bool>((Ref ref) {
  final List<TransferRecord>? entries = ref.watch(historyProvider).valueOrNull;
  return entries != null && entries.isEmpty;
});
