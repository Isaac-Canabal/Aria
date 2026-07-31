/// Las preferencias de Ajustes.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../transfer/discovery_service.dart';

/// Quien puede ver este dispositivo en la red local.
///
/// Los tres valores de los mockups. Sin cuentas no hay "contactos": las
/// etiquetas en espanol las pone la UI, aqui solo viaja el valor.
enum PeerVisibility {
  /// "Todos en la red local"
  everyone('everyone'),

  /// "Solo dispositivos emparejados"
  pairedOnly('paired_only'),

  /// "Nadie": ni se anuncia ni acepta conexiones.
  nobody('nobody');

  const PeerVisibility(this.wire);

  final String wire;

  static PeerVisibility fromWire(String? value) {
    for (final PeerVisibility visibility in values) {
      if (visibility.wire == value) return visibility;
    }
    return PeerVisibility.everyone;
  }
}

class AriaSettings {
  const AriaSettings({
    required this.deviceName,
    this.visibility = PeerVisibility.everyone,
    this.saveToGallery = true,
    this.saveToDownloads = true,
    this.notifications = false,
  });

  /// El nombre con el que se anuncia. Editable en Ajustes.
  final String deviceName;

  final PeerVisibility visibility;

  /// Android: copiar las imagenes recibidas a la galeria del sistema.
  final bool saveToGallery;

  /// Windows: dejar lo recibido en Descargas.
  final bool saveToDownloads;

  final bool notifications;

  AriaSettings copyWith({
    String? deviceName,
    PeerVisibility? visibility,
    bool? saveToGallery,
    bool? saveToDownloads,
    bool? notifications,
  }) => AriaSettings(
    deviceName: deviceName ?? this.deviceName,
    visibility: visibility ?? this.visibility,
    saveToGallery: saveToGallery ?? this.saveToGallery,
    saveToDownloads: saveToDownloads ?? this.saveToDownloads,
    notifications: notifications ?? this.notifications,
  );

  @override
  bool operator ==(Object other) =>
      other is AriaSettings &&
      other.deviceName == deviceName &&
      other.visibility == visibility &&
      other.saveToGallery == saveToGallery &&
      other.saveToDownloads == saveToDownloads &&
      other.notifications == notifications;

  @override
  int get hashCode => Object.hash(
    deviceName,
    visibility,
    saveToGallery,
    saveToDownloads,
    notifications,
  );
}

/// Guarda y lee [AriaSettings]. Nada mas: la logica de cuando aplicarlas vive
/// en los controladores.
class SettingsStore {
  const SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyDeviceName = 'device_name';
  static const String _keyVisibility = 'visibility';
  static const String _keySaveToGallery = 'save_to_gallery';
  static const String _keySaveToDownloads = 'save_to_downloads';
  static const String _keyNotifications = 'notifications';

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  AriaSettings read() => AriaSettings(
    // Sin nombre guardado, el del equipo: la persona lo cambia si quiere.
    deviceName: _prefs.getString(_keyDeviceName) ?? defaultDeviceName(),
    visibility: PeerVisibility.fromWire(_prefs.getString(_keyVisibility)),
    saveToGallery: _prefs.getBool(_keySaveToGallery) ?? true,
    saveToDownloads: _prefs.getBool(_keySaveToDownloads) ?? true,
    notifications: _prefs.getBool(_keyNotifications) ?? false,
  );

  Future<void> write(AriaSettings settings) async {
    await _prefs.setString(_keyDeviceName, settings.deviceName);
    await _prefs.setString(_keyVisibility, settings.visibility.wire);
    await _prefs.setBool(_keySaveToGallery, settings.saveToGallery);
    await _prefs.setBool(_keySaveToDownloads, settings.saveToDownloads);
    await _prefs.setBool(_keyNotifications, settings.notifications);
  }
}
