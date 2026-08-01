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

/// La coleccion de Android bajo la que cuelga la carpeta de recibidos.
///
/// En Android la app no puede escribir en una ruta cualquiera: el
/// almacenamiento por ambitos obliga a pasar por MediaStore, que acepta una
/// ruta **relativa** a una de sus colecciones. De ahi que aqui se elija
/// coleccion y nombre, y no una ruta como en escritorio.
enum DestinationCollection {
  /// `Download/`
  downloads('downloads'),

  /// `Documents/`
  documents('documents');

  const DestinationCollection(this.wire);

  final String wire;

  static DestinationCollection fromWire(String? value) {
    for (final DestinationCollection collection in values) {
      if (collection.wire == value) return collection;
    }
    return DestinationCollection.downloads;
  }
}

/// El nombre de carpeta por defecto, en las dos plataformas.
const String defaultDestinationFolder = 'Syroda';

class SyrodaSettings {
  const SyrodaSettings({
    required this.deviceName,
    this.visibility = PeerVisibility.everyone,
    this.destinationCollection = DestinationCollection.downloads,
    this.destinationFolder = defaultDestinationFolder,
    this.destinationPath,
    this.notifications = false,
  });

  /// El nombre con el que se anuncia. Editable en Ajustes.
  final String deviceName;

  final PeerVisibility visibility;

  /// Android: bajo que coleccion cuelga la carpeta.
  final DestinationCollection destinationCollection;

  /// Android: el nombre de la carpeta dentro de esa coleccion.
  final String destinationFolder;

  /// Escritorio: la carpeta elegida. `null` deja la de por defecto, que es
  /// `Descargas/Syroda`.
  ///
  /// Es una ruta y no coleccion + nombre porque en escritorio si se puede
  /// escribir donde sea, y limitar eso seria peor sin ganar nada.
  final String? destinationPath;

  final bool notifications;

  SyrodaSettings copyWith({
    String? deviceName,
    PeerVisibility? visibility,
    DestinationCollection? destinationCollection,
    String? destinationFolder,
    String? destinationPath,
    bool? notifications,
  }) => SyrodaSettings(
    deviceName: deviceName ?? this.deviceName,
    visibility: visibility ?? this.visibility,
    destinationCollection: destinationCollection ?? this.destinationCollection,
    destinationFolder: destinationFolder ?? this.destinationFolder,
    destinationPath: destinationPath ?? this.destinationPath,
    notifications: notifications ?? this.notifications,
  );

  @override
  bool operator ==(Object other) =>
      other is SyrodaSettings &&
      other.deviceName == deviceName &&
      other.visibility == visibility &&
      other.destinationCollection == destinationCollection &&
      other.destinationFolder == destinationFolder &&
      other.destinationPath == destinationPath &&
      other.notifications == notifications;

  @override
  int get hashCode => Object.hash(
    deviceName,
    visibility,
    destinationCollection,
    destinationFolder,
    destinationPath,
    notifications,
  );
}

/// Guarda y lee [SyrodaSettings]. Nada mas: la logica de cuando aplicarlas vive
/// en los controladores.
class SettingsStore {
  const SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyDeviceName = 'device_name';
  static const String _keyVisibility = 'visibility';
  static const String _keyDestinationCollection = 'destination_collection';
  static const String _keyDestinationFolder = 'destination_folder';
  static const String _keyDestinationPath = 'destination_path';
  static const String _keyNotifications = 'notifications';

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  SyrodaSettings read() => SyrodaSettings(
    // Sin nombre guardado, el del equipo: la persona lo cambia si quiere.
    deviceName: _prefs.getString(_keyDeviceName) ?? defaultDeviceName(),
    visibility: PeerVisibility.fromWire(_prefs.getString(_keyVisibility)),
    destinationCollection: DestinationCollection.fromWire(
      _prefs.getString(_keyDestinationCollection),
    ),
    destinationFolder:
        _prefs.getString(_keyDestinationFolder) ?? defaultDestinationFolder,
    destinationPath: _prefs.getString(_keyDestinationPath),
    notifications: _prefs.getBool(_keyNotifications) ?? false,
  );

  Future<void> write(SyrodaSettings settings) async {
    await _prefs.setString(_keyDeviceName, settings.deviceName);
    await _prefs.setString(_keyVisibility, settings.visibility.wire);
    await _prefs.setString(
      _keyDestinationCollection,
      settings.destinationCollection.wire,
    );
    await _prefs.setString(
      _keyDestinationFolder,
      settings.destinationFolder,
    );
    final String? path = settings.destinationPath;
    if (path == null) {
      await _prefs.remove(_keyDestinationPath);
    } else {
      await _prefs.setString(_keyDestinationPath, path);
    }
    await _prefs.setBool(_keyNotifications, settings.notifications);
  }
}
