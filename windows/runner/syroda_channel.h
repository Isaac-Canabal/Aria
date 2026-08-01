#ifndef RUNNER_SYRODA_CHANNEL_H_
#define RUNNER_SYRODA_CHANNEL_H_

#include <flutter/flutter_engine.h>

// Registra el lado Windows del canal `syroda/platform`.
//
// Solo responde lo que Dart no puede hacer por si mismo: abrir un archivo con
// su aplicacion asociada y abrir la carpeta de destino seleccionandolo. El
// espacio libre y el destino en si van por `dart:io`, que en escritorio si
// tiene rutas de verdad.
void RegisterSyrodaChannel(flutter::FlutterEngine* engine);

#endif  // RUNNER_SYRODA_CHANNEL_H_
