/// El servicio en primer plano que sostiene una transferencia.
///
/// Android 10+ corta los sockets de una app en segundo plano, asi que toda
/// sesion — de envio o de recepcion — corre atada a este servicio. Android 14
/// exige ademas declarar el tipo `dataSync`, que esta en el manifiesto.
///
/// Lleva cuenta de las sesiones vivas: enviar y recibir a la vez no puede
/// hacer que la primera en terminar apague el servicio de la otra.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

abstract interface class TransferForegroundService {
  /// Entra una sesion. Arranca el servicio si era la primera.
  Future<void> begin({required String title, required String text});

  /// Sale una sesion. Detiene el servicio si era la ultima. Es idempotente:
  /// llamarlo de mas no apaga el servicio de otra sesion.
  Future<void> end();

  /// Cuantas sesiones lo sostienen ahora mismo.
  int get holders;
}

class AndroidTransferForegroundService implements TransferForegroundService {
  AndroidTransferForegroundService();

  int _holders = 0;
  bool _initialized = false;

  @override
  int get holders => _holders;

  @override
  Future<void> begin({required String title, required String text}) async {
    _holders++;
    if (!Platform.isAndroid || _holders > 1) return;

    if (!_initialized) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'syroda_transfer',
          channelName: 'Transferencias',
          // Baja: es un aviso de que algo esta en curso, no una alerta.
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          // Sin trabajo periodico: el servicio solo mantiene vivo el proceso
          // mientras el socket transfiere.
          eventAction: ForegroundTaskEventAction.nothing(),
        ),
      );
      _initialized = true;
    }

    await FlutterForegroundTask.startService(
      serviceTypes: <ForegroundServiceTypes>[ForegroundServiceTypes.dataSync],
      notificationTitle: title,
      notificationText: text,
    );
  }

  @override
  Future<void> end() async {
    if (_holders == 0) return;
    _holders--;
    if (!Platform.isAndroid || _holders > 0) return;

    try {
      await FlutterForegroundTask.stopService();
    } on Exception {
      // El servicio ya no estaba corriendo. Que no se pueda apagar lo que ya
      // esta apagado no puede tumbar la sesion que acaba de terminar.
    }
  }
}

/// Sin servicio: fuera de Android, y en las pruebas.
class NoTransferForegroundService implements TransferForegroundService {
  NoTransferForegroundService();

  int _holders = 0;

  @override
  int get holders => _holders;

  @override
  Future<void> begin({required String title, required String text}) async =>
      _holders++;

  @override
  Future<void> end() async {
    if (_holders > 0) _holders--;
  }
}
