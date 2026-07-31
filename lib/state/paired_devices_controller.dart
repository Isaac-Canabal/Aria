/// El estado de los dispositivos emparejados.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/paired_device.dart';
import '../core/data/paired_devices_repository.dart';
import '../core/transfer/peer.dart';
import '../core/transfer/session_events.dart';
import 'data_providers.dart';

class PairedDevicesController extends AsyncNotifier<List<PairedDevice>> {
  @override
  Future<List<PairedDevice>> build() async {
    final PairedDevicesRepository repository = await ref.watch(
      pairedDevicesRepositoryProvider.future,
    );
    final StreamSubscription<void> subscription = repository.changes.listen(
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(subscription.cancel);
    return repository.all();
  }

  /// Se llama cuando una sesion queda autorizada: el codigo correcto es el
  /// emparejamiento. Un par renombrado actualiza su nombre, no se duplica.
  Future<void> rememberFrom(SessionAuthorized event) async {
    if (event.deviceId.isEmpty) return;
    final PairedDevicesRepository repository = await ref.read(
      pairedDevicesRepositoryProvider.future,
    );
    await repository.remember(
      PairedDevice(
        deviceId: event.deviceId,
        name: event.device,
        platform: event.platform,
        pairedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> forget(String deviceId) async {
    final PairedDevicesRepository repository = await ref.read(
      pairedDevicesRepositoryProvider.future,
    );
    await repository.forget(deviceId);
  }

  /// La accion destructiva de Ajustes.
  Future<void> forgetAll() async {
    final PairedDevicesRepository repository = await ref.read(
      pairedDevicesRepositoryProvider.future,
    );
    await repository.forgetAll();
  }
}

final AsyncNotifierProvider<PairedDevicesController, List<PairedDevice>>
pairedDevicesProvider =
    AsyncNotifierProvider<PairedDevicesController, List<PairedDevice>>(
      PairedDevicesController.new,
    );

/// Los identificadores emparejados, para consultarlos sin recorrer la lista.
final Provider<Set<String>> pairedIdsProvider = Provider<Set<String>>((
  Ref ref,
) {
  final List<PairedDevice>? devices = ref
      .watch(pairedDevicesProvider)
      .valueOrNull;
  return <String>{
    for (final PairedDevice device in devices ?? const <PairedDevice>[])
      device.deviceId,
  };
});

/// Si un par descubierto ya esta emparejado. Es lo que decide, con
/// `PeerVisibility.pairedOnly`, si se le acepta una sesion.
bool isPeerPaired(Set<String> paired, Peer peer) =>
    peer.deviceId.isNotEmpty && paired.contains(peer.deviceId);
