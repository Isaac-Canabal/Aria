import 'package:aria/core/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sin nada guardado, los valores por defecto', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SettingsStore store = await SettingsStore.open();

    final AriaSettings settings = store.read();
    expect(settings.deviceName, isNotEmpty);
    expect(settings.visibility, PeerVisibility.everyone);
    expect(settings.saveToGallery, isTrue);
    expect(settings.saveToDownloads, isTrue);
    // Las notificaciones arrancan apagadas, como en los mockups.
    expect(settings.notifications, isFalse);
  });

  test('lo escrito sobrevive a una relectura', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SettingsStore store = await SettingsStore.open();

    const AriaSettings changed = AriaSettings(
      deviceName: 'PC de mí',
      visibility: PeerVisibility.pairedOnly,
      saveToGallery: false,
      saveToDownloads: false,
      notifications: true,
    );
    await store.write(changed);

    expect((await SettingsStore.open()).read(), changed);
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
        AriaSettings(deviceName: 'x', visibility: visibility),
      );
      expect(store.read().visibility, visibility);
    }
  });
}
