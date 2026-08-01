package com.isaaccanabal.syroda

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * El lado nativo del canal `syroda/platform`.
 *
 * Solo responde lo que Dart no puede averiguar por si mismo: el espacio libre,
 * que `dart:io` no expone, y la escritura en Descargas por MediaStore, que no
 * tiene ruta que abrir con `dart:io`.
 */
class MainActivity : FlutterActivity() {

    private val downloads by lazy { MediaStoreDownloads(applicationContext) }

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

                "destinationReady" -> result.success(downloads.ready())

                "destinationFreeBytes" -> withDownloads(result) {
                    downloads.freeBytes()
                }

                "createDownload" -> withDownloads(result) {
                    val name = call.argument<String>("name")
                        ?: throw IllegalArgumentException("falta el argumento name")
                    downloads.create(name)
                }

                "writeDownload" -> withDownloads(result) {
                    val uri = call.argument<String>("uri")
                        ?: throw IllegalArgumentException("falta el argumento uri")
                    val bytes = call.argument<ByteArray>("bytes")
                        ?: throw IllegalArgumentException("falta el argumento bytes")
                    downloads.write(uri, bytes)
                    null
                }

                "flushDownload" -> withDownloads(result) {
                    downloads.flush(requireUri(call.argument<String>("uri")))
                    null
                }

                "publishDownload" -> withDownloads(result) {
                    downloads.publish(requireUri(call.argument<String>("uri")))
                    null
                }

                "discardDownload" -> withDownloads(result) {
                    downloads.discard(requireUri(call.argument<String>("uri")))
                    null
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requireUri(uri: String?): String =
        uri ?: throw IllegalArgumentException("falta el argumento uri")

    /**
     * Traduce cualquier fallo a un error del canal. Dart lo convierte en
     * `FileSystemException`, que es lo que la sesion ya sabe tratar como
     * `FileFailure.ioError` sin matar el lote entero.
     */
    private fun withDownloads(result: MethodChannel.Result, body: () -> Any?) {
        try {
            result.success(body())
        } catch (e: Exception) {
            result.error("media_store", e.message, null)
        }
    }
}
