package com.isaaccanabal.syroda

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * El lado nativo del canal `syroda/platform`.
 *
 * Solo responde lo que Dart no puede averiguar por si mismo. Hoy es el
 * espacio libre: `dart:io` no lo expone y agregar un paquete por una llamada
 * a `StatFs` no se justifica.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "syroda/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeSpace" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no_path", "falta el argumento path", null)
                    } else {
                        try {
                            result.success(StatFs(path).availableBytes)
                        } catch (e: IllegalArgumentException) {
                            // Ruta que no existe o no es un volumen montado.
                            result.error("bad_path", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
