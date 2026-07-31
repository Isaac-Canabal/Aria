/// Los permisos que Syroda necesita en Android.
library;

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Que le falta a la app para poder descubrir y transferir.
enum SyrodaPermission {
  /// API 33+: `NEARBY_WIFI_DEVICES`. En 24-32, `ACCESS_FINE_LOCATION`, que
  /// era lo que exigia el descubrimiento por Wi-Fi antes.
  nearbyDevices,

  /// API 33+: avisar del avance y del final de la transferencia.
  notifications,
}

/// Resultado de pedir un permiso. Se distingue el rechazo permanente porque
/// pedirlo otra vez ya no abre el dialogo: hay que mandar a Ajustes.
enum PermissionOutcome { granted, denied, permanentlyDenied, notApplicable }

abstract interface class PermissionService {
  Future<PermissionOutcome> status(SyrodaPermission permission);

  Future<PermissionOutcome> request(SyrodaPermission permission);

  /// Abre los ajustes del sistema, para el rechazo permanente.
  Future<void> openSettings();
}

class SystemPermissionService implements PermissionService {
  const SystemPermissionService();

  @override
  Future<PermissionOutcome> status(SyrodaPermission permission) async {
    final Permission? target = _resolve(permission);
    if (target == null) return PermissionOutcome.notApplicable;
    return _translate(await target.status);
  }

  @override
  Future<PermissionOutcome> request(SyrodaPermission permission) async {
    final Permission? target = _resolve(permission);
    if (target == null) return PermissionOutcome.notApplicable;
    return _translate(await target.request());
  }

  @override
  Future<void> openSettings() => openAppSettings();

  /// Fuera de Android no hay nada que pedir: en Windows el equivalente es la
  /// regla del firewall, que no es un permiso de la app.
  Permission? _resolve(SyrodaPermission permission) {
    if (!Platform.isAndroid) return null;
    return switch (permission) {
      // `permission_handler` mapea `nearbyWifiDevices` a NEARBY_WIFI_DEVICES
      // en API 33+ y a la ubicacion precisa por debajo.
      SyrodaPermission.nearbyDevices => Permission.nearbyWifiDevices,
      SyrodaPermission.notifications => Permission.notification,
    };
  }

  PermissionOutcome _translate(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => PermissionOutcome.granted,
    PermissionStatus.permanentlyDenied => PermissionOutcome.permanentlyDenied,
    PermissionStatus.restricted ||
    PermissionStatus.denied => PermissionOutcome.denied,
  };
}
