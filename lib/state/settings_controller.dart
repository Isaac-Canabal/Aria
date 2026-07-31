/// El estado de Ajustes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/preferences.dart';
import '../core/transfer/discovery_service.dart';
import '../core/transfer/peer.dart';
import 'data_providers.dart';

class SettingsController extends AsyncNotifier<AriaSettings> {
  @override
  Future<AriaSettings> build() async =>
      (await ref.watch(settingsStoreProvider.future)).read();

  Future<void> setDeviceName(String name) {
    final String trimmed = name.trim();
    // Un nombre vacio dejaria el anuncio sin etiqueta y la fila sin titulo.
    if (trimmed.isEmpty) return Future<void>.value();
    return _update(state.requireValue.copyWith(deviceName: trimmed));
  }

  Future<void> setVisibility(PeerVisibility visibility) =>
      _update(state.requireValue.copyWith(visibility: visibility));

  Future<void> setSaveToGallery(bool value) =>
      _update(state.requireValue.copyWith(saveToGallery: value));

  Future<void> setSaveToDownloads(bool value) =>
      _update(state.requireValue.copyWith(saveToDownloads: value));

  Future<void> setNotifications(bool value) =>
      _update(state.requireValue.copyWith(notifications: value));

  Future<void> _update(AriaSettings next) async {
    final SettingsStore store = await ref.read(settingsStoreProvider.future);
    await store.write(next);
    state = AsyncData<AriaSettings>(next);
  }
}

final AsyncNotifierProvider<SettingsController, AriaSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AriaSettings>(
      SettingsController.new,
    );

/// La identidad con la que este dispositivo se anuncia: el identificador
/// estable de la instalacion, el nombre de Ajustes y la plataforma del
/// sistema.
final FutureProvider<DeviceIdentity> deviceIdentityProvider =
    FutureProvider<DeviceIdentity>((Ref ref) async {
      final AriaSettings settings = await ref.watch(settingsProvider.future);
      return DeviceIdentity(
        id: await ref.watch(installationIdProvider.future),
        name: settings.deviceName,
        platform: currentPlatform(),
      );
    });

/// Si el dispositivo debe anunciarse en la red. "Nadie" no es un filtro de
/// presentacion: se deja de publicar el servicio.
final Provider<bool> announcingProvider = Provider<bool>((Ref ref) {
  final AriaSettings? settings = ref.watch(settingsProvider).valueOrNull;
  return settings != null && settings.visibility != PeerVisibility.nobody;
});
