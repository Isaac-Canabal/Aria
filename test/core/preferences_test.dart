import 'package:syroda/core/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sin nada guardado, los valores por defecto', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SettingsStore store = await SettingsStore.open();

    final SyrodaSettings settings = store.read();
    expect(settings.deviceName, isNotEmpty);
    expect(settings.visibility, PeerVisibility.everyone);
    expect(settings.destinationCollection, DestinationCollection.downloads);
    expect(settings.destinationFolder, 'Syroda');
    // Sin carpeta elegida en escritorio: la de por defecto.
    expect(settings.destinationPath, isNull);
    // Las notificaciones arrancan apagadas, como en los mockups.
    expect(settings.notifications, isFalse);
  });

  test('lo escrito sobrevive a una relectura', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SettingsStore store = await SettingsStore.open();

    const SyrodaSettings changed = SyrodaSettings(
      deviceName: 'PC de mí',
      visibility: PeerVisibility.pairedOnly,
      destinationCollection: DestinationCollection.documents,
      destinationFolder: 'Recibidos',
      destinationPath: r'D:\Archivos',
      notifications: true,
    );
    await store.write(changed);

    expect((await SettingsStore.open()).read(), changed);
  });

  test('volver a la carpeta por defecto borra la ruta guardada', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SettingsStore store = await SettingsStore.open();

    await store.write(
      const SyrodaSettings(deviceName: 'x', destinationPath: r'D:\Archivos'),
    );
    expect(store.read().destinationPath, r'D:\Archivos');

    // `null` tiene que borrar la clave, no dejarla con el valor anterior:
    // si no, no habria forma de volver al destino por defecto.
    await store.write(const SyrodaSettings(deviceName: 'x'));
    expect((await SettingsStore.open()).read().destinationPath, isNull);
  });

  test('una coleccion desconocida cae en Descargas', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.destination_collection': 'sd_card',
    });
    expect(
      (await SettingsStore.open()).read().destinationCollection,
      DestinationCollection.downloads,
    );
  });

  test('un valor de visibilidad desconocido cae en "todos"', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.visibility': 'contacts',
    });
    expect(
      (await SettingsStore.open()).read().visibility,
      PeerVisibility.everyone,
    );
  });

  test('los tres valores de visibilidad van y vuelven', () async {
    for (final PeerVisibility visibility in PeerVisibility.values) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SettingsStore store = await SettingsStore.open();
      await store.write(
        SyrodaSettings(deviceName: 'x', visibility: visibility),
      );
      expect(store.read().visibility, visibility);
    }
  });
}
